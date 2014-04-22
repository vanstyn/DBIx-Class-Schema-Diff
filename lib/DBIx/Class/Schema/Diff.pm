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
use Array::Diff;

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
 
 # Dump current schema data to a json file for later use:
 $D->old_schema->dump_json_file('/tmp/my_schema1_data.json');
 
 # Or
 DBIx::Class::Schema::Diff::SchemaData->new(
   schema => 'My::Schema1'
 )->dump_json_file('/tmp/my_schema1_data.json');
 
 # Create new diff object using previously saved 
 # schema data + current schema class:
 $D = DBIx::Class::Schema::Diff->new(
   old_schema => '/tmp/my_schema1_data.json',
   new_schema => 'My::Schema1'
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

=head1 METHODS

=head2 new

Create a new DBIx::Class::Schema::Diff instance. The following build options are supported:

=over 4

=item old_schema

The "old" (or left-side) schema to be compared. 

Can be supplied as a L<DBIx::Class::Schema> class name, connected schema object instance, 
or previously saved L<SchemaData|DBIx::Class::Schema::Diff::SchemaData> which can be 
supplied as an object, HashRef, or a path to a file containing serialized JSON data (as 
produced by L<DBIx::Class::Schema::Diff::SchemaData#dump_json_file>)

See the SYNOPSIS and L<DBIx::Class::Schema::Diff::SchemaData> for more info.

=item new_schema

The "new" (or right-side) schema to be compared. Accepts the same dynamic type options 
as C<old_schema>.

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

The L<filter|DBIx::Class::Schema::Diff#filter> (and inverse L<filter_out|DBIx::Class::Schema::Diff#filter_out>) 
method is analogous to ResultSet's L<search_rs|DBIx::Class::ResultSet#search_rs> in that it is chainable 
(i.e. returns a new object instance) and each call further restricts the data considered. But, instead of 
building up an SQL query, it filters the data in the HashRef returned by C<diff()>. The filter 
argument(s) define an expression which matches specific parts of the C<diff> packet. In the case of 
C<filter()>, all data that B<does not> match the expression is removed from the HashRef (of the returned,
new object), while in the case of C<filter_out()>, all data that B<does> match the expression is removed.

The filter expression is designed to be simple and declarative. It can be supplied as a list of strings
which match schema data either broadly or narrowly. A filter string argument follows this general pattern:

 '<source>:<type>/<id>'

Where C<source> is the name of a specific source in the schema (either side), C<type> is the I<type> of data, which is currently 
one of five (5) supported, predefined types: I<'columns'>, I<'relationships'>, I<'constraints'>, I<'isa'> and I<'table_name'>,
and C<id> is the name of an item, specific to that type, if applicable. 

For instance, this expression would match only the I<column> named 'timestamp' in the source named 'Artist':

 'Artist:column/timestamp'

Not all types have sub-items (only I<columns>, I<relationships> and I<constraints>). The I<isa> and I<table_name>
types are source-global. So, for example, to see changes to I<isa> (i.e. differences in inheritance and/or
loaded components in the result class) you could use the following:

 'Artist:isa'

I<columns> and I<relationships>, on the other hand, can have changes to their attributes (column_info/relationship_info) 
which can also be targeted selectively. For instance, to match only changes in C<size> of a specific column:

 'Artist:column/timestamp.size'

Attributes with sub hashes can be matched as well. For example, to match only changes in C<list> I<within>
C<extra> (which is where DBIC puts the list of possible values for enum columns):

 'Artist:column/my_enum.extra.list'

The structure is specific to the type. The dot-separated path applies to the data returned by L<column_info|DBIx::Class::ResultSource#column_info> for columns and
L<relationship_info|DBIx::Class::ResultSource#relationship_info> for relationships. For instance, 
the following matches changes to C<cascade_delete> of a specific relationship named 'some_rel' in the 'Artist'
source:

 'Artist:relationship/some_rel.attrs.cascade_delete'

Filter arguments can also match I<broadly> using the wildcard asterisk character (C<*>). For instance, to match
I<'isa'> changes in any source:

 '*:isa'

The system also accepts ambiguous/partial match strings and tries to "DWIM". So, the above can also 
be written simply as:

 'isa'

This is possible because 'isa' is understood/known as a I<type> keyword. Additionally, the system knows the names
of all the sources in advance, so the following filter string argument would match everything in the 'Artist'
source:

 'Artist'

Sub-item names are automatically resolved, too. The following would match any column, relationship, or
constraint named C<'code'> in any source:

 'code'

When you have schemas with overlapping names, such as a column named 'isa', you simply need to supply more
specific match strings, as ambiguous names are resolved with left-precedence. So, to match any
column, relationship, or constraint named 'isa', you could use the following:

 # Matches column, relationship, or constraints named 'isa':
 '*:*/isa'

Different delimiter characters are used for the source level (C<':'>) and the type level (C<'/'>) so you
can do things like match any column/relationship/constraint of a specific source, such as:

 Artist:code

The above is equivalent to:

 Artist:*/code

You can also supply a delimiter character to match a specific level explicitly. So, if you wanted to
match all changes to a I<source> named 'isa':

 # Matches a source (poorly) named 'isa'
 'isa:'

The same works at the type level. The following are all equivalent

 # Each of the following 3 filter strings are equivalent:
 'columns/'
 '*:columns/*'
 'columns'

Internally, L<Hash::Layout> is used to process the filter arguments.

=head2 event filtering

Besides matching specific parts of the schema, you can also filter by I<event>, which are I<'added'>, 
I<'deleted'> or I<'changed'>.

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
