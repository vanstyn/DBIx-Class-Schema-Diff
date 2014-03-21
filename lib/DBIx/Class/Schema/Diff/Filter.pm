package DBIx::Class::Schema::Diff::Filter;
use strict;
use warnings;

# Further filters diff data produced by DBIx::Class::Schema::Diff

use Moo;
with 'DBIx::Class::Schema::Diff::Role::Common';

use Types::Standard qw(:all);

has 'mode', is => 'ro', isa => Enum[qw(limit ignore)], default => sub{'limit'};

my @types = qw(
 columns
 relationships
 constraints
 table_name
 isa
);

has 'types', is => 'ro', isa => Maybe[Map[Enum[@types],Bool]], 
  coerce => \&_coerce_list_hash;

my @attrs = ('sources',@types);
for my $attr (@attrs) {
  has $attr => ( 
    is => 'ro', isa => Maybe[Map[Str,Bool]],
    coerce => \&_coerce_list_hash
  );
  # event attr:
  $attr =~ s/s$//; #<-- make singular
  has $attr . '_events' => ( 
    is => 'ro', isa => Maybe[Map[Enum[qw(added changed deleted)],Bool]],
    coerce => \&_coerce_list_hash
  );
}

has 'column_names', is => 'ro', isa => Maybe[HashRef], 
  coerce => \&_coerce_list_hash;

has 'relationship_names', is => 'ro', isa => Maybe[HashRef], 
  coerce => \&_coerce_list_hash;
  
has 'constraint_names', is => 'ro', isa => Maybe[HashRef], 
  coerce => \&_coerce_list_hash;

has 'column_info', is => 'ro', isa => Maybe[Map[Str,Bool]], 
  coerce => \&_coerce_to_deep_hash;

has 'relationship_info', is => 'ro', isa => Maybe[Map[Str,Bool]], 
  coerce => \&_coerce_to_deep_hash;

# Plural form method aliases:
sub columns_events       { (shift)->column_events }
sub relationships_events { (shift)->relationship_events }
sub constraints_events   { (shift)->constraint_events }
sub columns_names        { (shift)->column_names }
sub relationships_names  { (shift)->relationship_names }
sub constraints_names    { (shift)->constraint_names }
sub columns_info         { (shift)->column_info }
sub relationships_info   { (shift)->relationship_info }


sub filter {
  my ($self, $diff) = @_;
  return undef unless ($diff);
  
  my $newd = {};
  for my $s_name (keys %$diff) {
    my $h = $diff->{$s_name};
    next if (
      $self->_is_skip( sources => $s_name ) ||
      $self->_is_skip( source_events => $h->{_event})
    );
    $newd->{$s_name} = $self->source_filter( $s_name => $h );
  }
  
  return (keys %$newd > 0) ? $newd : undef;
}


sub source_filter {
  my ($self, $s_name, $diff) = @_;
  return undef unless ($diff);
  
  my $newd = {};
  for my $type (keys %$diff) {
    next if ($self->_is_skip( types => $type ));
    my $val = $diff->{$type};
    if($type eq 'columns' || $type eq 'relationships' || $type eq 'constraints') {
      $newd->{$type} = $self->_info_filter( $type, $s_name => $val );
      delete $newd->{$type} unless (defined $newd->{$type});
    }
    else {
      $newd->{$type} = $val
    }
  }
  
  return (keys %$newd > 0) ? $newd : undef;
}

sub _info_filter {
  my ($self, $type, $s_name, $items) = @_;
  return undef unless ($items);

  my $new_items = {};

  for my $name (keys %$items) {
    next if ($self->_is_skip( $type.'_events' => $items->{$name}{_event}));
    next if ($self->_is_skip( $type.'_names'  => $name ));
    if($items->{$name}{_event} eq 'changed') {
      my $meth = $type.'_info';
      my $check = $self->can($meth) ? $self->$meth : undef;
      
      if($check) {
        my $new_diff = $check ? $self->_deep_hash_filter(
          $check, $items->{$name}{diff}
        ) : undef;
        next unless ($new_diff);
        $new_items->{$name} = {
          _event => 'changed',
          diff   => $new_diff
        };
      }
      else {
        # Allow through as-is:
        $new_items->{$name} = $items->{$name};
      }
    }
    else {
      # Allow through as-is:
      $new_items->{$name} = $items->{$name};
    }
  }

  return (keys %$new_items > 0) ? $new_items : undef;
}

sub _deep_hash_filter {
  my ($self, $check, $hash) = @_;
  
  my $new_hash = {};
  for my $k (keys %$hash) {
    my ($val,$ch_val) = ($hash->{$k},$check->{$k});
    if($ch_val) {
      if(ref($val) eq 'HASH' && ref($ch_val) eq 'HASH' && keys %$ch_val > 0) {
        $new_hash->{$k} = $self->_deep_hash_filter($ch_val,$val);
        delete $new_hash->{$k} unless (defined $new_hash->{$k});
      }
      else {
        next if ($self->mode eq 'ignore');
        $new_hash->{$k} = $val;
      }
    }
    else {
      next if ($self->mode eq 'limit');
      $new_hash->{$k} = $val;
    }
  }
  
  return (keys %$new_hash > 0) ? $new_hash : undef;
}



sub _is_skip {
  my ($self, $meth, $key) = @_;
  my $h = $self->$meth;
  $self->mode eq 'limit' ? $h && ! $h->{$key} : $h && $h->{$key};
}


1;