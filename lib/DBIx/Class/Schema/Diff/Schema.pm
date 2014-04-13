package DBIx::Class::Schema::Diff::Schema;
use strict;
use warnings;

# ABSTRACT: Simple Diffing of DBIC Schemas

our $VERSION = 0.01;

use Moo;
with 'DBIx::Class::Schema::Diff::Role::Common';

use Types::Standard qw(:all);
use Module::Runtime;
use Try::Tiny;

use DBIx::Class::Schema::Diff::Source;
use DBIx::Class::Schema::Diff::SchemaData;

has 'old_schema', required => 1, is => 'ro', isa => InstanceOf[
  'DBIx::Class::Schema::Diff::SchemaData'
], coerce => \&_coerce_schema_data;

has 'new_schema', required => 1, is => 'ro', isa => InstanceOf[
  'DBIx::Class::Schema::Diff::SchemaData'
], coerce => \&_coerce_schema_data;


sub all_source_names {
  my $self = shift;
  
  my ($o,$n) = ($self->old_schema,$self->new_schema);
  
  # List of all sources in old, new, or both:
  return uniq($o->sources,$n->sources);
}

has 'sources', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  
  return { map {
    $_ => DBIx::Class::Schema::Diff::Source->new(
      name         => $_,
      old_source   => scalar try{$self->old_schema->source($_)},
      new_source   => scalar try{$self->new_schema->source($_)},
      _schema_diff => $self,
    )
  } $self->all_source_names };
  
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

sub _schema_diff { (shift) }


1;


__END__

=head1 NAME

DBIx::Class::Schema::Diff - Simple Diffing of DBIC Schemas

=head1 SYNOPSIS

 use DBIx::Class::Schema::Diff;

 my $Diff = DBIx::Class::Schema::Diff->new(
   old_schema => 'My::Schema1',
   new_schema => 'My::Schema2'
 );
 
 my $hash = $Diff->diff;

=head1 DESCRIPTION



=cut
