package DBIx::Class::SchemaDiff::InfoPacket;
use strict;
use warnings;

use Moo;
use MooX::Types::MooseLike::Base 0.25 qw(:all);

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
  
  my $diff = $self->_info_diff($o,$n) or return undef;

  return { changed => $diff };
  
}, init_arg => undef, isa => Maybe[HashRef];


sub _info_diff {
  my ($self, $old, $new) = @_;
  
  my %old_keys = map {$_=>1} keys %$old;

  my $nh = {};

  for my $k (keys %$new) {
    if (exists $old->{$k}) {
      delete $old_keys{$k};
      if(ref $new->{$k} eq 'HASH') {
        if(ref $old->{$k} eq 'HASH') {
          my $diff = $self->_info_diff($old->{$k},$new->{$k}) or next;
          $nh->{$k} = $diff;
        }
        else {
          $nh->{$k} = $new->{$k};
        }
      }
      else {
        # Test if the non hash values are determined to be "equal"
        $nh->{$k} = $new->{$k} unless ($self->_is_eq($old->{$k},$new->{$k}));
      }
    }
    else {
      $nh->{$k} = $new->{$k};
    }
  }
  
  # fill back in any left over, old keys (i.e. weren't in $new):
  $nh->{$_} = $old->{$_} for (keys %old_keys);

  return undef unless (keys %$nh > 0);
  return $nh;
}

# test non-hash
sub _is_eq {
  my ($self, $old, $new) = @_;
  
  # if both undef, they are equal:
  return 1 if(!defined $old && !defined $new);
  
  my ($o_ref,$n_ref) = (ref $old,ref $new);
  
  # one is a ref and the other isn't, obviously not equal:
  return 0 if ($n_ref && !$o_ref || $o_ref && !$n_ref);
  
  # both refs:
  if($o_ref && $n_ref) {
    # If they are not the same kind of ref, they obviously aren't equal:
    return 0 unless ($o_ref eq $n_ref);
    
    if($n_ref eq 'CODE') {
      # We can't tell the difference between CodeRefs, but we don't want
      # those cases to show up as changed, so we call them equal:
      return 1;
    }
    elsif($n_ref eq 'SCALAR' || $n_ref eq 'REF') {
      # For ScalarRefs, compare their referants:
      return $self->_is_eq($$old,$$new);
    }
    elsif($n_ref eq 'ARRAY') {
      # If they don't have the same number of elements, they aren't equal:
      return 0 unless (scalar @$new == scalar @$old);
      
      # If they are both empty, they are equal:
      return 1 if (scalar @$new == 0 && scalar @$old == 0);
      
      # iterate both sides:
      my $i = 0;
      for my $n_el (@$new) {
        my $o_el = $old->[$i++];
        # Return 0 as soon as the first element is not equal:
        return 0 unless ($self->_is_eq($o_el,$n_el));
      }
      
      # If we made it here, then all the elements were equal above:
      return 1;
    }
    elsif($n_ref eq 'HASH') {
      # This case will only be called by us for HashRef elements of ArrayRef
      # (case above). The main _info_diff() function handles HashRef's itself.
      # Also note that from this point it is a true/false equality -- there
      # is no more selective merging of hashes, showing only different keys
      #
      # If the hashes are equal, the diff should be undef:
      return $self->_info_diff($old,$new) ? 0 : 1;
    }
    else {
      die "Unexpected ref type '$n_ref'";
    }
  }

  # simple scalar value comparison:
  return (defined $old && defined $new && "$old" eq "$new");
}



1;