package DBIx::Class::Schema::Diff::SchemaData;
use strict;
use warnings;

# ABSTRACT: Data representation of schema for diffing
# VERSION

use Moo;
with 'DBIx::Class::Schema::Diff::Role::Common';

use Types::Standard qw(:all);
use Module::Runtime;
use Scalar::Util qw(blessed);
use Data::Dumper::Concise;
use Path::Class qw(file);
use JSON qw(to_json);

has 'schema', is => 'ro', isa => Maybe[InstanceOf[
  'DBIx::Class::Schema'
]], coerce => \&_coerce_schema, default => sub {undef};

has 'data', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  
  die "You must supply a schema or an existing data packet"
    unless ($self->schema);
  
  return $self->_gen_data( $self->schema );

}, isa => HashRef, coerce => \&_coerce_deep_unsafe_refs;


sub BUILD {
  my $self = shift;

  # initialize:
  $self->data;
}

sub sources {
  my $self = shift;
  return sort keys %{ $self->data->{sources} || {} };
}

sub source {
  my ($self, $name) = @_;
  return $self->data->{sources}{$name};
}

sub dump_json {
  my $self = shift;
  to_json( $self->data => { pretty => 1 });
}

sub dump_json_file {
  my ($self, $path) = @_;
  die "Filename required" unless ($path);
  my $file = file($path)->absolute;
  
  die "Target file '$file' already exists." if (-e $file);
  
  $file->spew( $self->dump_json );
  return -f $file ? 1 : 0;
}


sub _gen_data {
  my ($self, $schema) = @_;
  
  my $data = {
    schema_class => (blessed $schema),
    sources => {
      map {
        my $Source = $schema->source($_);
        $_ => {
        
          columns => {
            map {
              $_ => $Source->column_info($_)
            } $Source->columns
          },
          
          relationships => {
            map {
              $_ => $Source->relationship_info($_)
            } $Source->relationships
          },
          
          constraints => {
            map {
              $_ => { columns => [$Source->unique_constraint_columns($_)] }
            } $Source->unique_constraint_names
          },
          
          table_name => $Source->from,
          
          isa => mro::get_linear_isa( $schema->class( $Source->source_name ) ),

        }
      } $schema->sources 
    }
  };
  
  return $self->_localize_deep_namespace_strings($data,$data->{schema_class});
}


sub _coerce_schema {
  my ($v) = @_;
  return $v if (!$v || ref $v);
  
  # Its a class name:
  Module::Runtime::require_module($v);
  return $v->can('connect') ? $v->connect('dbi:SQLite::memory:','','') : $v;
}


sub _coerce_deep_unsafe_refs {
  my ($v) = @_;
  my $rt = ref($v) or return $v;
  
  if($rt eq 'HASH') {
    return { map { $_ => &_coerce_deep_unsafe_refs($v->{$_}) } keys %$v };
  }
  elsif($rt eq 'ARRAY') {
    return [ map { &_coerce_deep_unsafe_refs($_) } @$v ];
  }
  elsif($rt eq 'CODE') {
    # TODO: we don't have to do this, we could let it through
    # to be stringified, but for now, we're not trying to compare
    # CodeRef contents
    return 'sub { "DUMMY" }';
  }
  else {
    # For all other refs, stringify them with Dumper. These will still
    # be just as useful for diff/compare. This makes them safe for JSON, etc
    my $str = Dumper($v);
    # strip newlines:
    $str =~ s/\r?\n//g;
    # normalize whitespace:
    $str =~ s/\s+/ /g;
    return $str;
  }
}

sub _localize_deep_namespace_strings {
  my ($self, $v, $ns) = @_;
  my $rt = ref($v);
  if($rt) {
    if($rt eq 'HASH') {
      return { map {
        $_ => $self->_localize_deep_namespace_strings($v->{$_},$ns)
      } keys %$v };
    }
    elsif($rt eq 'ARRAY') {
      return [ map {
        $self->_localize_deep_namespace_strings($_,$ns)
      } @$v ];
    }
    else {
      return $v;
    }
  }
  else {
    # swap the namespace prefix string for literal '{schema_class}':
    $v =~ s/^${ns}/\{schema_class\}/ if($v && $ns && $v ne $ns);
    return $v;
  }
}

1;


__END__

=head1 NAME

DBIx::Class::Schema::Diff::SchemaDiff - Data representation of schema for diffing

=head1 SYNOPSIS

 use DBIx::Class::Schema::Diff::SchemaData;
 
 
=head1 DESCRIPTION

...

=cut
