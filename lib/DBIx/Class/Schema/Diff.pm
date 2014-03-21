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
  my %opt = (ref($args[0]) eq 'HASH') ? %{ $args[0] } : @args; # <-- arg as hash or hashref
  
  my $Filter = DBIx::Class::Schema::Diff::Filter->new(\%opt);
  
  return __PACKAGE__->new({
    _schema_diff => $self->_schema_diff,
    diff         => $Filter->filter( $self->diff )
  });
}

sub filter_out {
  my ($self,@args) = @_;
  my %opt = (ref($args[0]) eq 'HASH') ? %{ $args[0] } : @args; # <-- arg as hash or hashref
  return $self->filter( %opt, mode => 'ignore' );
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
