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

    The "old" (or left-side) schema to be compared. 

    Can be supplied as a [DBIx::Class::Schema](https://metacpan.org/pod/DBIx::Class::Schema) class name, connected schema object instance, 
    or previously saved [SchemaData](https://metacpan.org/pod/DBIx::Class::Schema::Diff::SchemaData) which can be 
    supplied as an object, HashRef, or a path to a file containing serialized JSON data (as 
    produced by [DBIx::Class::Schema::Diff::SchemaData#dump\_json\_file](https://metacpan.org/pod/DBIx::Class::Schema::Diff::SchemaData#dump_json_file))

    See the SYNOPSIS and [DBIx::Class::Schema::Diff::SchemaData](https://metacpan.org/pod/DBIx::Class::Schema::Diff::SchemaData) for more info.

- new\_schema

    The "new" (or right-side) schema to be compared. Accepts the same dynamic type options 
    as `old_schema`.

### diff

Returns the differences between the the schemas as a hash structure, or `undef` if there are none.

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
- [SQL::Translator::Diff](https://metacpan.org/pod/SQL::Translator::Diff)

## AUTHOR

Henry Van Styn <vanstyn@cpan.org>

## COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by IntelliTree Solutions llc.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
