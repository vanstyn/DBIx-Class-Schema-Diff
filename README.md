## NAME

DBIx::Class::Schema::Diff - Identify differences between two DBIx::Class schemas

## SYNOPSIS

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

## DESCRIPTION

General-purpose schema differ for [DBIx::Class](https://metacpan.org/pod/DBIx::Class). Currently tracks changes in 5 kinds of data
within the Result Classes/Sources of the Schemas:

- columns
- relationships
- constraints
- table\_name
- isa

...

## METHODS

### new

Create a new DBIx::Class::Schema::Diff instance. The following build options are supported:

- old\_schema

    The "old" (or left-side) schema to be compared. Can be either a [DBIx::Class::Schema](https://metacpan.org/pod/DBIx::Class::Schema) class name or
    connected object instance.

- new\_schema

    The "new" (or right-side) schema to be compared. Can be either a [DBIx::Class::Schema](https://metacpan.org/pod/DBIx::Class::Schema) class name or
    connected object instance.

### diff

Returns the differences between the the schemas as a hash structure.

### filter

Accepts filter argument(s) to restrict the differences to consider and returns a new `Schema::Diff` 
instance, making it chainable (much like [ResultSets](https://metacpan.org/pod/DBIx::Class::ResultSet#search_rs)).

See [FILTERING](https://metacpan.org/pod/DBIx::Class::Schema::Diff#FILTERING) for filter argument syntax.

### filter\_out

Works like `filter()` but the arguments exclude differences rather than restrict/limit to them.

See [FILTERING](https://metacpan.org/pod/DBIx::Class::Schema::Diff#FILTERING) for filter argument syntax.

## FILTERING

...

## EXAMPLES

...

For more examples, see the following:

- The SYNOPSIS
- The unit tests in `t/`

## SEE ALSO

- [DBIx::Class](https://metacpan.org/pod/DBIx::Class)

## AUTHOR

Henry Van Styn <vanstyn@cpan.org>

## COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by IntelliTree Solutions llc.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
