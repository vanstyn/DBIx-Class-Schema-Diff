# -*- perl -*-

use strict;
use warnings;
use FindBin '$Bin';
use lib "$Bin/lib";

use Test::More;
use Test::Exception;

use DBIx::Class::Schema::Diff;

my $Diff =  DBIx::Class::Schema::Diff->new(
  old_schema => 'TestSchema::Sakila',
  new_schema => 'TestSchema::Sakila3'
);


my $added_sources_expected_diff = { FooBar => { _event => "added" } };
is_deeply(
  $Diff->filter( source_events => 'added' )->diff,
  $added_sources_expected_diff,
  'filter "added" source_events'
);
is_deeply(
  $Diff->filter_out( source_events => [qw(deleted changed)] )->diff,
  $added_sources_expected_diff,
  'filter_out "deleted" and "changed" source_events'
);
is_deeply(
  $Diff->filter_out( source_events => 'deleted' )
       ->filter_out( source_events => { changed => 1 } )
       ->diff,
  $added_sources_expected_diff,
  'filter_out "deleted" and "changed" source_events via chaining'
);


is_deeply(
  $Diff->diff,
  $Diff->filter()->diff,
  'Empty filter matches diff'
);



done_testing;



# -- for debugging:
#
#use Data::Dumper::Concise;
#print STDERR "\n\n" . Dumper(
#  $Diff->filter_out( 
#    source_events => [qw(deleted changed)] 
#  )->diff
#) . "\n\n";
