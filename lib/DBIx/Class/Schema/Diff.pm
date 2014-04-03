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
use Hash::Layout;

use DBIx::Class::Schema::Diff::Schema;
use DBIx::Class::Schema::Diff::Filter;

has '_schema_diff', required => 1, is => 'ro', isa => InstanceOf[
  'DBIx::Class::Schema::Diff::Schema'
], coerce => \&_coerce_schema_diff;

has 'diff', is => 'ro', lazy => 1, default => sub {
  (shift)->_schema_diff->diff
}, isa => Maybe[HashRef];

has 'MatchLayout', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  
  Hash::Layout->new({
    default_key   => '*',
    default_value => 1,
    levels => [
      { 
        name => 'source', 
        delimiter => ':',
        registered_keys => [$self->_schema_diff->all_source_names]
      },{ 
        name => 'type', 
        delimiter => '/',
        registered_keys => [&_types_list]
      },{ 
        name => 'id', 
      }
    ]
  });

}, init_arg => undef, isa => InstanceOf['Hash::Layout'];


around BUILDARGS => sub {
  my ($orig, $self, @args) = @_;
  my %opt = (ref($args[0]) eq 'HASH') ? %{ $args[0] } : @args; # <-- arg as hash or hashref
  
  return $opt{_schema_diff} ? $self->$orig(%opt) : $self->$orig( _schema_diff => \%opt );
};


sub filter {
  my ($self,@args) = @_;
  my $params = $self->_coerce_filter_args(@args);
  
  my $Filter = DBIx::Class::Schema::Diff::Filter->new( $params ) ;
  my $diff   = $self->diff;
  
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
  
  my $params = (
    scalar(@args) > 1
    || ! ref($args[0])
    || ref($args[0]) ne 'HASH'
  ) ? { match => \@args } : $args[0];
  
  return { 
    %$params,
    match => $self->MatchLayout->coerce($params->{match})
  };
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
