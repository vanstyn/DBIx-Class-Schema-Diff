package DBIx::Class::Schema::Diff::Source;
use strict;
use warnings;

use Moo;
with 'DBIx::Class::Schema::Diff::Role::Common';

use Types::Standard qw(:all);
use Try::Tiny;
use List::MoreUtils qw(uniq);

use DBIx::Class::Schema::Diff::InfoPacket;

has 'old_source', required => 1, is => 'ro', isa => Maybe[InstanceOf[
  'DBIx::Class::ResultSource'
]];

has 'new_source', required => 1, is => 'ro', isa => Maybe[InstanceOf[
  'DBIx::Class::ResultSource'
]];

has '_schema_diff', required => 1, is => 'ro', isa => InstanceOf[
  'DBIx::Class::Schema::Diff'
];

has 'ignore', is => 'ro', isa => Maybe[Map[Enum[qw(
 columns relationships unique_constraints table_name isa
)],Bool]], coerce => \&_coerce_list_hash;

has 'limit', is => 'ro', isa => Maybe[Map[Enum[qw(
 columns relationships unique_constraints table_name isa
)],Bool]], coerce => \&_coerce_list_hash;


my @_ignore_limit_attrs = qw(
  limit_columns       ignore_columns
  limit_relationships ignore_relationships
  limit_constraints   ignore_constraints
);
has $_ => (is => 'ro', isa => Maybe[ArrayRef]) for (@_ignore_limit_attrs);


has 'old_class', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  return undef unless ($self->old_source);
  $self->old_source->schema->class( $self->old_source->source_name );
}, init_arg => undef, isa => Maybe[Str];

has 'new_class', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  return undef unless ($self->new_source);
  $self->new_source->schema->class( $self->new_source->source_name );
}, init_arg => undef, isa => Maybe[Str];

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
  my @columns = uniq(try{$o->columns}, try{$n->columns});
  
  return {
    map { $_ => DBIx::Class::Schema::Diff::InfoPacket->new(
      name        => $_,
      old_info    => $o && $o->has_column($_) ? $o->column_info($_) : undef,
      new_info    => $n && $n->has_column($_) ? $n->column_info($_) : undef,
      _source_diff => $self,
      limit       => $self->limit_columns,
      ignore      => $self->ignore_columns
    ) } @columns 
  };

}, init_arg => undef, isa => HashRef;


has 'relationships', is => 'ro', lazy => 1, default => sub { 
  my $self = shift;
  
  my ($o,$n) = ($self->old_source,$self->new_source);
  
  # List of all relationships in old, new, or both:
  my @rels = uniq(try{$o->relationships},try{$n->relationships});
  
  return {
    map { $_ => DBIx::Class::Schema::Diff::InfoPacket->new(
      name        => $_,
      old_info    => $o && $o->has_relationship($_) ? $o->relationship_info($_) : undef,
      new_info    => $n && $n->has_relationship($_) ? $n->relationship_info($_) : undef,
      _source_diff => $self,
      limit       => $self->limit_relationships,
      ignore      => $self->ignore_relationships
    ) } @rels
  };
  
}, init_arg => undef, isa => HashRef;


has 'unique_constraints', is => 'ro', lazy => 1, default => sub { 
  my $self = shift;
  
  my ($o,$n) = ($self->old_source,$self->new_source);
  
  # List of all unique_constraint_names in old, new, or both:
  my @consts = uniq(
    try{$o->unique_constraint_names},
    try{$n->unique_constraint_names}
  );
  
  return {
    map { 
      my @o_uc_cols = try{$o->unique_constraint_columns($_)};
      my @n_uc_cols = try{$n->unique_constraint_columns($_)};
      $_ => DBIx::Class::Schema::Diff::InfoPacket->new(
        name        => $_,
        old_info    => scalar(@o_uc_cols) > 0 ? { columns => \@o_uc_cols } : undef,
        new_info    => scalar(@n_uc_cols) > 0 ? { columns => \@n_uc_cols } : undef,
        _source_diff => $self,
        limit       => $self->limit_constraints,
        ignore      => $self->ignore_constraints
      ) 
    } @consts
  };
  
}, init_arg => undef, isa => HashRef;


has 'isa_diff', is => 'ro', lazy => 1, default => sub {
  my $self = shift;

  my ($o,$n) = ($self->old_class,$self->new_class);
  my $o_isa = $o ? mro::get_linear_isa($o) : [];
  my $n_isa = $n ? mro::get_linear_isa($n) : [];

  # Normalize namespaces which match the old/new schema class
  my $o_class = $self->_schema_diff->old_schemaclass;
  my $n_class = $self->_schema_diff->new_schemaclass;
  $_ =~ s/^${n_class}/\*/ for (@$n_isa);
  $_ =~ s/^${o_class}/\*/ for (@$o_isa);

  my $AD = Array::Diff->diff($o_isa,$n_isa);
  my $diff = [
    (map {'-'.$_} @{$AD->deleted}),
    (map {'+'.$_} @{$AD->added})
  ];

  return scalar(@$diff) > 0 ? $diff : undef;

}, init_arg => undef, isa => Maybe[ArrayRef];



has 'diff', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  
  # There is no reason to diff in the case of added/deleted:
  return { _event => 'added'   } if ($self->added);
  return { _event => 'deleted' } if ($self->deleted);
  
  my $diff = {};
  
  $diff->{columns} = { map {
    $_->diff ? ($_->name => $_->diff) : ()
  } values %{$self->columns} };
  delete $diff->{columns} unless (keys %{$diff->{columns}} > 0);
  
  $diff->{relationships} = { map {
    $_->diff ? ($_->name => $_->diff) : ()
  } values %{$self->relationships} };
  delete $diff->{relationships} unless (keys %{$diff->{relationships}} > 0);
  
  $diff->{unique_constraints} = { map {
    $_->diff ? ($_->name => $_->diff) : ()
  } values %{$self->unique_constraints} };
  delete $diff->{unique_constraints} unless (keys %{$diff->{unique_constraints}} > 0);
  
  my $o_tbl = try{$self->old_source->from};
  my $n_tbl = try{$self->new_source->from};
  $diff->{table_name} = $n_tbl unless ($self->_is_eq($o_tbl,$n_tbl));
  
  $diff->{isa} = $self->isa_diff if ($self->isa_diff);
  
  # TODO: other data points TDB 
  # ...
  
  # Remove items specified in ignore:
  $self->_is_ignore($_) and delete $diff->{$_} for (keys %$diff);
  
  # No changes:
  return undef unless (keys %$diff > 0);
  
  $diff->{_event} = 'changed';
  return $diff;
  
}, init_arg => undef, isa => Maybe[HashRef];




1;