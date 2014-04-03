package DBIx::Class::Schema::Diff::Filter;
use strict;
use warnings;

# Further filters diff data produced by DBIx::Class::Schema::Diff

use Moo;
with 'DBIx::Class::Schema::Diff::Role::Common';

use Types::Standard qw(:all);

has 'mode',  is => 'ro', isa => Enum[qw(limit ignore)], default => sub{'limit'};
has 'match', is => 'ro', isa => Maybe[InstanceOf['Hash::Layout']], default => sub{undef};

has 'events', is => 'ro', coerce => \&_coerce_list_hash,
  isa => Maybe[Map[Enum[qw(added changed deleted)],Bool]];

has 'source_events', is => 'ro', coerce => \&_coerce_list_hash,
  isa => Maybe[Map[Enum[qw(added changed deleted)],Bool]];

has 'empty_match', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  return (scalar(keys %{$self->match->Data}) > 0) ? 0 : 1;
}, init_arg => undef, isa => Bool;


sub filter {
  my ($self, $diff) = @_;
  return undef unless ($diff);
  
  my $newd = {};
  for my $s_name (keys %$diff) {
    my $h = $diff->{$s_name};
    next if (
      $self->skip_source($s_name)
      || $self->_is_skip( source_events => $h->{_event})
    );
    
    $newd->{$s_name} = $self->source_filter( $s_name => $h );
    delete $newd->{$s_name} unless (defined $newd->{$s_name});
    
    # Strip if the event is 'changed' but the diff data has been stripped
    delete $newd->{$s_name} if (
      $newd->{$s_name} && 
      $newd->{$s_name}{_event} &&
      $newd->{$s_name}{_event} eq 'changed' &&
      keys (%{$newd->{$s_name}}) == 1
    );
  }
  
  return (keys %$newd > 0) ? $newd : undef;
}


sub source_filter {
  my ($self, $s_name, $diff) = @_;
  return undef unless ($diff);
  
  my $newd = {};
  for my $type (keys %$diff) {
    next if ($type ne '_event' && $self->skip_type($s_name => $type));
    my $val = $diff->{$type};
    if($type eq 'columns' || $type eq 'relationships' || $type eq 'constraints') {
      $newd->{$type} = $self->_info_filter( $type, $s_name => $val );
      delete $newd->{$type} unless (defined $newd->{$type});
    }
    else {
      $newd->{$type} = $val
    }
  }
  
  return (keys %$newd > 0) ? $newd : undef;
}

sub _info_filter {
  my ($self, $type, $s_name, $items) = @_;
  return undef unless ($items);

  my $new_items = {};

  for my $name (keys %$items) {
    next if (
      $self->_is_skip( 'events' => $items->{$name}{_event}) ||
      $self->skip_type_id($s_name, $type => $name )
    );

    if($items->{$name}{_event} eq 'changed') {
    
      my $check = $self->match->lookup_path($s_name, $type, $name);
      
      if($check) {
        my $new_diff = $check ? $self->_deep_hash_filter(
          $check, $items->{$name}{diff}
        ) : undef;
        next unless ($new_diff);
        $new_items->{$name} = {
          _event => 'changed',
          diff   => $new_diff
        };
      }
      else {
        # Allow through as-is:
        $new_items->{$name} = $items->{$name};
      }
    }
    else {
      # Allow through as-is:
      $new_items->{$name} = $items->{$name};
    }
  }

  return (keys %$new_items > 0) ? $new_items : undef;
}

sub _deep_hash_filter {
  my ($self, $check, $hash) = @_;
  
  my $new_hash = {};
  for my $k (keys %$hash) {
    my ($val,$ch_val) = ($hash->{$k},$check->{$k});
    if($ch_val) {
      if(ref($val) eq 'HASH' && ref($ch_val) eq 'HASH' && keys %$ch_val > 0) {
        $new_hash->{$k} = $self->_deep_hash_filter($ch_val,$val);
        delete $new_hash->{$k} unless (defined $new_hash->{$k});
      }
      else {
        next if ($self->mode eq 'ignore');
        $new_hash->{$k} = $val;
      }
    }
    else {
      next if ($self->mode eq 'limit');
      $new_hash->{$k} = $val;
    }
  }
  
  return (keys %$new_hash > 0) ? $new_hash : undef;
}



sub _is_skip {
  my ($self, $meth, $key) = @_;
  my $h = $self->$meth;
  $self->mode eq 'limit' ? $h && ! $h->{$key} : $h && $h->{$key};
}


sub skip_source {
  my ($self, $s_name) = @_;
  my $HL = $self->match or return 0;
  my $set = $HL->lookup_path($s_name) || 0;
  
  if($self->mode eq 'limit') {
    return 0 if ($self->empty_match);
    return $set ? 0 : 1;
  }
  else {
    return $set && ! ref($set) ? 1 : 0;
  }
}

sub skip_type {
  my ($self, $s_name, $type) = @_;
  my $HL = $self->match or return 0;
  my $set = $HL->lookup_path($s_name,$type);
  
  if($self->mode eq 'limit') {
    return 0 if ($self->empty_match);
    # If this source/type is set, OR if the entire source is included:
    return $set || 1 == $HL->lookup_path($s_name) ? 0 : 1;
  }
  else {
    return $set && ! ref($set) ? 1 : 0;
  }
}

sub skip_type_id {
  my ($self, $s_name, $type, $id) = @_;
  my $HL = $self->match or return 0;
  my $set = $HL->lookup_path($s_name,$type,$id);
  
  if($self->mode eq 'limit') {
    return 0 if ($self->empty_match);
    # If this source/type is set, OR if the entire source or source/type is included:
    return $set
      || 1 == $HL->lookup_path($s_name)
      || 1 == $HL->lookup_path($s_name,$type) ? 0 : 1;
  }
  else {
    return $set && ! ref($set) ? 1 : 0;
  }
}

1;