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
  my $diff   = $Filter->filter( $self->diff );
  
  # Make a second pass, using the actual matched paths to filter out
  # the intermediate paths that didn't actually match anything:
  #  (update: unless this is an empty match, in which case we will just
  #  return the whole diff as-is)
  if($Filter->mode eq 'limit' && ! $Filter->empty_match) {
    if(scalar(@{$Filter->matched_paths}) > 0) {
      $params->{match} = $Filter->match->clone->reset->load( map {
        $Filter->match->path_to_composite_key(@$_)
      } @{$Filter->matched_paths} );
      $Filter = DBIx::Class::Schema::Diff::Filter->new( $params ) ;
      $diff   = $Filter->filter( $diff );
    }
    else {
      # If nothing was matched, in limit mode, the diff is undef:
      $diff = undef;
    }
  }
  
  return __PACKAGE__->new({
    _schema_diff => $self->_schema_diff,
    diff         => $diff
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
  
  unless (exists $params->{match}) {
    my $n = { match => $params };
    my @othr = qw(events source_events);
    exists $n->{match}{$_} and $n->{$_} = delete $n->{match}{$_} for (@othr);
    $params = $n;
  }

  return { 
    %$params,
    match => $self->MatchLayout->coerce($params->{match})
  };
}


1;


__END__

=head1 NAME

DBIx::Class::Schema::Diff - Identify differences between two DBIx::Class schemas

=head1 SYNOPSIS

 use DBIx::Class::Schema::Diff;

 # Create new diff object using schema class names:
 my $D = DBIx::Class::Schema::Diff->new(
   old_schema => 'My::Schema1',
   new_schema => 'My::Schema2'
 );
 
 # Create new diff object using schema objects:
 $D = DBIx::Class::Schema::Diff->new(
   old_schema => $schema1,
   new_schema => $schema2
 );
 
 # Get all differences (hash structure):
 my $hash = $D->diff;
 
 # Only column differences:
 $hash = $D->filter('columns')->diff;
 
 # Only things named 'Artist' or 'CD':
 $hash = $D->filter(qw/Artist CD/)->diff;
 
 # Things named 'Artist', *columns* named 'CD' and *relationships* named 'columns':
 $hash = $D->filter(qw(Artist columns/CD relationships/columns))->diff;
 
 # Sources named 'Artist', excluding column changes:
 $hash = $D->filter('Artist:')->filter_out('columns')->diff;
 
 if( $D->filter('Artist:columns/name.size')->diff ) {
  # Do something only if there has been a change in 'size' (i.e. in column_info)
  # to the 'name' column in the 'Artist' source
  # ...
 }
 
 # Names of all sources which exist in new_schema but not in old_schema:
 my @sources = keys %{ 
   $D->filter({ source_events => 'added' })->diff || {}
 };
 
 # All changes to existing unique_constraints (ignoring added or deleted)
 # excluding those named or within sources named Album or Genre:
 $hash = $D->filter_out({ events => [qw(added deleted)] })
           ->filter_out('Album','Genre')
           ->filter('constraints')
           ->diff;
 
 # All changes to relationship attrs except for 'cascade_delete' in 
 # relationships named 'artists':
 $hash = $D->filter_out('relationships/artists.attrs.cascade_delete')
           ->filter('relationships/*.attrs')
           ->diff;


=head1 DESCRIPTION

General-purpose schema differ for L<DBIx::Class>. Currently tracks changes in 5 kinds of data
within the Result Classes/Sources of the Schemas:

=over

=item *

columns

=item *

relationships

=item *

constraints

=item *

table_name

=item *

isa

=back

...

=head1 METHODS

=head2 new

Create a new DBIx::Class::Schema::Diff instance. The following build options are supported:

=over 4

=item old_schema

The "old" (or left-side) schema to be compared. Can be either a L<DBIx::Class::Schema> class name or
connected object instance.

=item new_schema

The "new" (or right-side) schema to be compared. Can be either a L<DBIx::Class::Schema> class name or
connected object instance.

=back

=head2 diff

Returns the differences between the the schemas as a hash structure, or C<undef> if there are none.

=head2 filter

Accepts filter argument(s) to restrict the differences to consider and returns a new C<Schema::Diff> 
instance, making it chainable (much like L<ResultSets|DBIx::Class::ResultSet#search_rs>).

See L<FILTERING|DBIx::Class::Schema::Diff#FILTERING> for filter argument syntax.

=head2 filter_out

Works like C<filter()> but the arguments exclude differences rather than restrict/limit to them.

See L<FILTERING|DBIx::Class::Schema::Diff#FILTERING> for filter argument syntax.

=head1 FILTERING

...

=head1 EXAMPLES

...

For more examples, see the following:

=over

=item *

The SYNOPSIS

=item *

The unit tests in C<t/>

=back

=head1 SEE ALSO

=over

=item *

L<DBIx::Class>

=item * 

L<SQL::Translator::Diff>

=back

=head1 AUTHOR

Henry Van Styn <vanstyn@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by IntelliTree Solutions llc.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
