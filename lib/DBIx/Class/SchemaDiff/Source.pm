package DBIx::Class::SchemaDiff::Source;
use strict;
use warnings;

use Moo;
use MooX::Types::MooseLike::Base 0.25 qw(:all);
use Hash::Diff;

use DBIx::Class::SchemaDiff::InfoPacket;

has 'old_source', required => 1, is => 'ro', isa => Maybe[InstanceOf[
  'DBIx::Class::ResultSource'
]];

has 'new_source', required => 1, is => 'ro', isa => Maybe[InstanceOf[
  'DBIx::Class::ResultSource'
]];

has 'name', is => 'ro', lazy => 1, default => sub { 
  my $self = shift;
  # TODO: handle new_source/old_source with different names
  # (shouldn't need to worry about it currently)
  $self->new_source ? 
    $self->new_source->source_name : $self->old_source->source_name
}, init_arg => undef, isa => Str;


has 'added', is => 'ro', lazy => 1, default => sub { 
  my $self = shift;
  defined $self->new_source && ! defined $self->old_source
}, init_arg => undef, isa => Bool;

has 'deleted', is => 'ro', lazy => 1, default => sub { 
  my $self = shift;
  defined $self->old_source && ! defined $self->new_source
}, init_arg => undef, isa => Bool;


has 'columns', is => 'ro', lazy => 1, default => sub { 
  my $self = shift;
  
  my ($o,$n) = ($self->old_source,$self->new_source);
  
  # List of all columns in old, new, or both:
  my %seen = ();
  my @columns = grep {!$seen{$_}++} ($o->columns, $n->columns);
  
  return {
    map { $_ => DBIx::Class::SchemaDiff::InfoPacket->new(
      name => $_,
      old_info  => $o && $o->has_column($_) ? $o->column_info($_) : undef,
      new_info  => $n && $n->has_column($_) ? $n->column_info($_) : undef,
    ) } @columns 
  };

}, init_arg => undef, isa => HashRef;


has 'relationships', is => 'ro', lazy => 1, default => sub { 
  my $self = shift;
  
  my ($o,$n) = ($self->old_source,$self->new_source);
  
  # List of all relationships in old, new, or both:
  my %seen = ();
  my @rels = grep {!$seen{$_}++} ($o->relationships,$n->relationships);
  
  return {
    map { $_ => DBIx::Class::SchemaDiff::InfoPacket->new(
      name => $_,
      old_info  => $o && $o->has_relationship($_) ? $o->relationship_info($_) : undef,
      new_info  => $n && $n->has_relationship($_) ? $n->relationship_info($_) : undef,
    ) } @rels
  };
  
}, init_arg => undef, isa => HashRef;



has 'diff', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  
  my $diff = {};
  
  $diff->{columns} = { map {
    $_->diff ? ($_->name => $_->diff) : ()
  } values %{$self->columns} };
  delete $diff->{columns} unless (keys %{$diff->{columns}} > 0);
  
  $diff->{relationships} = { map {
    $_->diff ? ($_->name => $_->diff) : ()
  } values %{$self->relationships} };
  delete $diff->{relationships} unless (keys %{$diff->{relationships}} > 0);
  
  # TODO: other data points TDB (indexes, etc)
  # ...
  
  
  return undef unless (keys %$diff > 0); 
  return $diff;
  
}, init_arg => undef, isa => Maybe[HashRef];





1;