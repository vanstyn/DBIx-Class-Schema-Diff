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
