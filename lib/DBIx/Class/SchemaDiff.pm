package DBIx::Class::SchemaDiff;
use strict;
use warnings;

# ABSTRACT: Simple Diffing of DBIC Schemas

our $VERSION = 0.01;

use Moo;
use MooX::Types::MooseLike::Base 0.25 qw(:all);
use Scalar::Util qw(blessed);
use Module::Runtime;
use Try::Tiny;

use DBIx::Class::SchemaDiff::Source;

has 'old_schema', required => 1, is => 'ro', isa => InstanceOf[
  'DBIx::Class::Schema'
];

has 'new_schema', required => 1, is => 'ro', isa => InstanceOf[
  'DBIx::Class::Schema'
];

has 'old_schemaclass', is => 'ro', lazy => 1, default => sub { 
  blessed((shift)->old_schema)
}, init_arg => undef, isa => Str;

has 'new_schemaclass', is => 'ro', lazy => 1, default => sub { 
  blessed((shift)->new_schema)
}, init_arg => undef, isa => Str;


around BUILDARGS => sub {
  my ($orig, $self, @args) = @_;
  my %opt = (ref($args[0]) eq 'HASH') ? %{ $args[0] } : @args; # <-- arg as hash or hashref
  
  # Allow old/new schema to be supplied as either connected instances
  # or class names. If class names, we'll automatically connect them
  # to an SQLite::memory instance.
  $opt{old_schema} = $self->_auto_connect_schema($opt{old_schema});
  $opt{new_schema} = $self->_auto_connect_schema($opt{new_schema});

  return $self->$orig(%opt);
};

sub _auto_connect_schema {
  my ($self,$class) = @_;
  return $class unless (defined $class && ! ref($class));
  Module::Runtime::require_module($class);
  return $class unless ($class->can('connect'));
  return $class->connect('dbi:SQLite::memory:','','');
}



has 'sources', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  
  my ($o,$n) = ($self->old_schema,$self->new_schema);
  
  # List of all sources in old, new, or both:
  my %seen = ();
  my @sources = grep { !$seen{$_}++ } ($o->sources,$n->sources);
  
  return {
    map { $_ => DBIx::Class::SchemaDiff::Source->new(
      old_source  => scalar try{$o->source($_)},
      new_source  => scalar try{$n->source($_)},
      schema_diff => $self
    ) } @sources 
  };

}, init_arg => undef, isa => HashRef;


has 'diff', is => 'ro', lazy => 1, default => sub { 
  my $self = shift;
  
  # TODO: handle added/deleted/changed at this level, too...
  my $diff = { map {
    $_->diff ? ($_->name => $_->diff) : ()
  } values %{$self->sources} };
  
  return undef unless (keys %$diff > 0); 
  return $diff;
  
}, init_arg => undef, isa => Maybe[HashRef];


# Adapted from Hash::Diff, but heavily modified and specific to
# the unique needs of this module...
sub _info_diff {
  my ($self, $old, $new) = @_;
  
  my %old_keys = map {$_=>1} keys %$old;

  my $nh = {};

  for my $k (keys %$new) {
    if (exists $old->{$k}) {
      delete $old_keys{$k};
      if(ref $new->{$k} eq 'HASH') {
        if(ref $old->{$k} eq 'HASH') {
          my $diff = $self->_info_diff($old->{$k},$new->{$k}) or next;
          $nh->{$k} = $diff;
        }
        else {
          $nh->{$k} = $new->{$k};
        }
      }
      else {
        # Test if the non hash values are determined to be "equal"
        $nh->{$k} = $new->{$k} unless ($self->_is_eq($old->{$k},$new->{$k}));
      }
    }
    else {
      $nh->{$k} = $new->{$k};
    }
  }
  
  # fill back in any left over, old keys (i.e. weren't in $new):
  # TODO: track these separately
  $nh->{$_} = $old->{$_} for (keys %old_keys);

  return undef unless (keys %$nh > 0);
  return $nh;
}

# test non-hash
sub _is_eq {
  my ($self, $old, $new) = @_;
  
  # if both undef, they are equal:
  return 1 if(!defined $old && !defined $new);
  
  my ($o_ref,$n_ref) = (ref $old,ref $new);
  
  # one is a ref and the other isn't, obviously not equal:
  return 0 if ($n_ref && !$o_ref || $o_ref && !$n_ref);
  
  # both refs:
  if($o_ref && $n_ref) {
    # If they are not the same kind of ref, they obviously aren't equal:
    return 0 unless ($o_ref eq $n_ref);
    
    if($n_ref eq 'CODE') {
      # We can't tell the difference between CodeRefs, but we don't want
      # those cases to show up as changed, so we call them equal:
      return 1;
    }
    elsif($n_ref eq 'SCALAR' || $n_ref eq 'REF') {
      # For ScalarRefs, compare their referants:
      return $self->_is_eq($$old,$$new);
    }
    elsif($n_ref eq 'ARRAY') {
      # If they don't have the same number of elements, they aren't equal:
      return 0 unless (scalar @$new == scalar @$old);
      
      # If they are both empty, they are equal:
      return 1 if (scalar @$new == 0 && scalar @$old == 0);
      
      # iterate both sides:
      my $i = 0;
      for my $n_el (@$new) {
        my $o_el = $old->[$i++];
        # Return 0 as soon as the first element is not equal:
        return 0 unless ($self->_is_eq($o_el,$n_el));
      }
      
      # If we made it here, then all the elements were equal above:
      return 1;
    }
    elsif($n_ref eq 'HASH') {
      # This case will only be called by us for HashRef elements of ArrayRef
      # (case above). The main _info_diff() function handles HashRef's itself.
      # Also note that from this point it is a true/false equality -- there
      # is no more selective merging of hashes, showing only different keys
      #
      # If the hashes are equal, the diff should be undef:
      return $self->_info_diff($old,$new) ? 0 : 1;
    }
    elsif(blessed $new) {
      # If this is an object reference, just compare the classes, since we don't
      # know how to compare object data and won't try:
      return $self->_is_eq(blessed($old),blessed($new));
    }
    else {
      die "Unexpected ref type '$n_ref'";
    }
  }
  
  my $o_class = $self->old_schemaclass;
  my $n_class = $self->new_schemaclass;
  
  # Special check/test: string values that start with the schema
  # class name need to have it stripped before comparing, because we
  # expect different schema class names. This handles cases like
  # relationships which reference other schema classes via their
  # "absolute" class/path. This operation essentially makes the
  # check "relative" like we need it to be.
  if($new =~ /^${n_class}/) {
    $new =~ s/^${n_class}//;
    $old =~ s/^${o_class}//;
  }

  # simple scalar value comparison:
  return (defined $old && defined $new && "$old" eq "$new");
}


1;


__END__

=head1 NAME

DBIx::Class::SchemaDiff - Simple Diffing of DBIC Schemas

=head1 SYNOPSIS

 use DBIx::Class::SchemaDiff;

 my $Diff = DBIx::Class::SchemaDiff->new(
   old_schema => 'My::Schema1',
   new_schema => 'My::Schema2'
 );
 
 my $hash = $Diff->diff;

=head1 DESCRIPTION



=cut
