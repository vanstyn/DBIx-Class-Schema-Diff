package DBIx::Class::Schema::Diff::InfoPacket;
use strict;
use warnings;

use Moo;
with 'DBIx::Class::Schema::Diff::Role::Common';

use Types::Standard qw(:all);

has 'name', required => 1, is => 'ro', isa => Str;
has 'old_info', required => 1, is => 'ro', isa => Maybe[HashRef];
has 'new_info', required => 1, is => 'ro', isa => Maybe[HashRef];

has 'source_diff', required => 1, is => 'ro', isa => InstanceOf[
  'DBIx::Class::Schema::Diff::Source'
];

has 'ignore', is => 'ro', isa => Maybe[Map[Str,Bool]], coerce => \&_coerce_list_hash;
has 'limit',  is => 'ro', isa => Maybe[Map[Str,Bool]], coerce => \&_coerce_list_hash;

has 'added', is => 'ro', lazy => 1, default => sub { 
  my $self = shift;
  defined $self->new_info && ! defined $self->old_info
}, init_arg => undef, isa => Bool;

has 'deleted', is => 'ro', lazy => 1, default => sub { 
  my $self = shift;
  defined $self->old_info && ! defined $self->new_info
}, init_arg => undef, isa => Bool;


has 'diff', is => 'ro', lazy => 1, default => sub { 
  my $self = shift;
  
  return undef if ($self->_is_ignore($self->name));
  
  # There is no reason to diff in the case of added/deleted:
  return { _event => 'added'   } if ($self->added);
  return { _event => 'deleted' } if ($self->deleted);
  
  my ($o,$n) = ($self->old_info,$self->new_info);
  my $diff = $self->_info_diff($o,$n) or return undef;
  
  return { _event => 'changed', diff => $diff };
  
}, init_arg => undef, isa => Maybe[HashRef];


sub _coerce_list_hash {
  ref($_[0]) eq 'ARRAY' ? { map {$_=>1} @{$_[0]} } : $_[0];
}

sub schema_diff { (shift)->source_diff->schema_diff }

1;