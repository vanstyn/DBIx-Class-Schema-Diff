package DBIx::Class::SchemaDiff::InfoPacket;
use strict;
use warnings;

use Moo;
use MooX::Types::MooseLike::Base 0.25 qw(:all);
use Hash::Diff;

has 'name', required => 1, is => 'ro', isa => Str;
has 'old_info', required => 1, is => 'ro', isa => Maybe[HashRef];
has 'new_info', required => 1, is => 'ro', isa => Maybe[HashRef];

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
  
  my ($o,$n) = ($self->old_info,$self->new_info);
  
  return { added   => $n } if ($self->added);
  return { deleted => $o } if ($self->deleted);
  
  my $diff = Hash::Diff::diff($o,$n) or return undef;
  
  # Do some cleanup of keys leftover by Hash::Diff:
  for my $k (keys %$diff) {
    my $v = $diff->{$k};
    if(ref $v eq 'HASH') {
      # Delete empty HashRefs (unless they were empty on new or old side)
      delete $diff->{$k} if (
        keys %$v == 0 && ! (
          keys %{$n->{$k}} == 0 ||
          keys %{$o->{$k}} == 0
        )
      );
      
      # And, if both old and new were empty hashrefs, there is no change
      delete $diff->{$k} if (
        exists $diff->{$k} &&
        keys %{$n->{$k}} == 0 &&
        keys %{$o->{$k}} == 0
      );
    }
    elsif(ref $v eq 'CODE') {
      # We can't tell the difference between CodeRefs:
      delete $diff->{$k} if (
        ref $o->{$k} eq 'CODE' and
        ref $n->{$k} eq 'CODE'
      );
    }
    
    # TODO: handle more cases...
  
  }

  # If there are no changes left, return undef to signify no changes
  return undef unless (keys %$diff > 0); 

  return { changed => $diff };
  
}, init_arg => undef, isa => Maybe[HashRef];



1;