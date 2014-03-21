package DBIx::Class::Schema::Diff;
use strict;
use warnings;

# ABSTRACT: Simple Diffing of DBIC Schemas

our $VERSION = 0.01;

use Moo;
with 'DBIx::Class::Schema::Diff::Role::Common';

use Types::Standard qw(:all);
use Module::Runtime;
use Try::Tiny;
use List::Util;

use DBIx::Class::Schema::Diff::Schema;
use DBIx::Class::Schema::Diff::Filter;

has '_schema_diff', required => 1, is => 'ro', isa => Maybe[InstanceOf[
  'DBIx::Class::Schema::Diff::Schema'
]], coerce => \&_coerce_schema_diff;

has 'diff', is => 'ro', lazy => 1, default => sub {
  (shift)->_schema_diff->diff
}, isa => Maybe[HashRef];


around BUILDARGS => sub {
  my ($orig, $self, @args) = @_;
  my %opt = (ref($args[0]) eq 'HASH') ? %{ $args[0] } : @args; # <-- arg as hash or hashref
  
  return $opt{_schema_diff} ? $self->$orig(%opt) : $self->$orig( _schema_diff => \%opt );
};

sub filter {
  my ($self,@args) = @_;
  my $p = $self->_coerce_filter_args(@args);
  
  my $diff = $self->diff;
  
  # Apply options that are implied by other options:
  
  # -- Allow bool types to be used to specify names
  $p->{types} = &_coerce_to_deep_hash_bool($p->{types}) || {};
  if (ref $p->{types}{columns}) {
    $p->{column_names} //= $p->{types}{columns};
    $p->{types}{columns} = 1;
  }
  if (ref $p->{types}{relationships}) {
    $p->{relationship_names} //= $p->{types}{relationships};
    $p->{types}{relationships} = 1;
  }
  if (ref $p->{types}{constraints}){
    $p->{constraint_names} //= $p->{types}{constraints};
    $p->{types}{constraints} = 1;
  }
  # --
  
  unless ($p->{mode} && $p->{mode} eq 'ignore') { # <-- i.e. 'limit'
  
    $p->{types}{columns}       = 1 if ($p->{column_names});
    $p->{types}{relationships} = 1 if ($p->{relationship_names});
    $p->{types}{constraints}   = 1 if ($p->{constraint_names});
    delete $p->{types} unless (keys %{$p->{types}} > 0);
  
    # -- The true value of any of limit mode param except these
    # automatically implies limiting to source 'changed' events:
    my @special = qw(mode diff _schema_diff source_events);
    my %sp = map {$_=>1} @special;
    my $imp_s_ch_only = List::Util::first { $p->{$_} && !$sp{$_} } keys %$p;
    if($imp_s_ch_only) {
      # If the user is excluding 'change' source_events 
      # everything will be filtered out:
      my $cur = &_coerce_list_hash($p->{source_events});
      $diff = undef if ($cur && !$cur->{changed});
      $p->{source_events} = { changed => 1 };
    }
    # --
  }
  
  my $Filter = DBIx::Class::Schema::Diff::Filter->new( $p ) ;
  
  return __PACKAGE__->new({
    _schema_diff => $self->_schema_diff,
    diff         => $Filter->filter( $diff )
  });
}

sub filter_out {
  my ($self,@args) = @_;
  my $params = $self->_coerce_filter_args(@args);
  $params->{mode} = 'ignore';
  return $self->filter( $params );
}

sub _coerce_filter_args {
  my ($self,@args) = @_;
  my $params = $args[0];
  unless (ref($args[0]) eq 'HASH') {
    # Easy "types" as string args:
    my %t = map {$_=>1} &_types_list;
    @args = map { $t{$_} ? "types.$_" : $_ } @args;
    $params = &_coerce_to_deep_hash_bool(\@args);
  }
  return $params;
}


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
