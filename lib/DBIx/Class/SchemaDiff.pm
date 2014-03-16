package DBIx::Class::SchemaDiff;
use strict;
use warnings;

# ABSTRACT: Simple Diffing of DBIC Schemas

our $VERSION = 0.01;

use Moo;
use MooX::Types::MooseLike::Base 0.25 qw(:all);
use Hash::Diff;

has 'old_schema', required => 1, is => 'ro', isa => InstanceOf[
  'DBIx::Class::Schema'
];

has 'new_schema', required => 1, is => 'ro', isa => InstanceOf[
  'DBIx::Class::Schema'
];


###################################################################

has 'old_data', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  return $self->_schema_data( $self->old_schema );
}, init_arg => undef, isa => HashRef;

has 'new_data', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  return $self->_schema_data( $self->new_schema );
}, init_arg => undef, isa => HashRef;

has 'diff_data', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  return Hash::Diff::diff(
    $self->old_data,
    $self->new_data
  );
}, init_arg => undef, isa => HashRef;


sub _schema_data {
  my ($self, $schema) = @_;
  
  return {
    map {
      my $source = $_;
      $source => {
        columns => {
          map {
            $_ => $schema->source($source)->column_info($_)
          } $schema->source($source)->columns 
        },
        relationships => {
          map {
            $_ => $schema->source($source)->relationship_info($_)
          } $schema->source($source)->relationships
        }
      }
    } $schema->sources 
  };
}



1;


__END__

=head1 NAME

DBIx::Class::SchemaDiff - Simple Diffing of DBIC Schemas

=head1 SYNOPSIS

 my $schema1 = My::Schema1->connect(@connect1);
 my $schema2 = My::Schema1->connect(@connect1);

 use DBIx::Class::SchemaDiff;

 my $Diff = DBIx::Class::SchemaDiff->new(
   old_schema => $schema1,
   new_schema => $schema2
 );
 
 my $hash = $Diff->diff_data;

=head1 DESCRIPTION



=cut
