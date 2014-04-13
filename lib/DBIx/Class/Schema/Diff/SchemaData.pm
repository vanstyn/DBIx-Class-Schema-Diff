package DBIx::Class::Schema::Diff::SchemaData;
use strict;
use warnings;

# ABSTRACT: Data representation of schema for diffing

our $VERSION = 0.01;

use Moo;
with 'DBIx::Class::Schema::Diff::Role::Common';

use Types::Standard qw(:all);
use Module::Runtime;
use Scalar::Util qw(blessed);

has 'schema', is => 'ro', isa => Maybe[InstanceOf[
  'DBIx::Class::Schema'
]], coerce => \&_coerce_schema, default => sub {undef};

has 'data', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  
  die "You must supply a schema or an existing data packet"
    unless ($self->schema);
  
  return $self->_gen_data( $self->schema );

}, isa => HashRef;



sub _gen_data {
  my ($self, $schema) = @_;
  
  {
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
  }
}


sub _coerce_schema {
  my ($v) = @_;
  return $v if (!$v || ref $v);
  
  # Its a class name:
  Module::Runtime::require_module($v);
  return $v->can('connect') ? $v->connect('dbi:SQLite::memory:','','') : $v;
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
