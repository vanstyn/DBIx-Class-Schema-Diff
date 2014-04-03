# -*- perl -*-

use strict;
use warnings;
use FindBin '$Bin';
use lib "$Bin/lib";

use Test::More;
use Test::Exception;

use DBIx::Class::Schema::Diff;

ok(
  my $Diff =  DBIx::Class::Schema::Diff->new(
    old_schema => 'TestSchema::Sakila',
    new_schema => 'TestSchema::Sakila3'
  ),
  "Initialize new DBIx::Class::Schema::Diff object"
);

is_deeply(
  $Diff->filter()->diff,
  $Diff->diff,
  'Empty filter matches diff'
);
is_deeply(
  $Diff->filter_out()->diff,
  $Diff->diff,
  'Empty filter_out matches diff'
);
is_deeply(
  $Diff->filter->filter->filter_out->filter->filter_out->diff,
  $Diff->diff,
  'Chained empty filters matches diff'
);



#my $added_sources_expected_diff = { FooBar => { _event => "added" } };
#is_deeply(
#  $Diff->filter({ source_events => 'added' })->diff,
#  $added_sources_expected_diff,
#  'filter "added" source_events'
#);
#is_deeply(
#  $Diff->filter_out({ source_events => [qw(deleted changed)] })->diff,
#  $added_sources_expected_diff,
#  'filter_out "deleted" and "changed" source_events'
#);
#is_deeply(
#  $Diff->filter_out({ source_events => 'deleted' })
#       ->filter_out({ source_events => { changed => 1 } })
#       ->diff,
#  $added_sources_expected_diff,
#  'filter_out "deleted" and "changed" source_events via chaining'
#);
#
#
#my $only_isa_expected_diff = {
#  Address => {
#    _event => "changed",
#    isa => [
#      "+Test::DummyClass"
#    ]
#  }
#};
#is_deeply(
#  $Diff->filter({ types => 'isa' })->diff,
#  $only_isa_expected_diff,
#  'filter all but "isa"'
#);
#is_deeply(
#  $Diff->filter('isa')->diff,
#  $only_isa_expected_diff,
#  'filter all but "isa" with string arg'
#);
#is_deeply(
#  $Diff->filter_out(qw(columns relationships constraints table_name))
#    ->filter('source_events.changed')
#    ->diff,
#  $only_isa_expected_diff,
#  'filter_out all but "isa" changes with string args'
#);
#

done_testing;

#### -------------
###  API idea: make any of the following str filter args match *at least*
###  a change to the value 'unsigned' within the key 'extra' within the 
###  column_info of 'rental_rate' with the 'Film' source
##
##                      'column_info'
##                      'column_info.extra'
##                      'column_info.extra.unsigned'
##          'rental_rate/column_info'
##          'rental_rate/column_info.extra'
##          'rental_rate/column_info.extra.unsigned'
##     'Film:rental_rate/column_info'
##     'Film:rental_rate/column_info.extra'
##     'Film:rental_rate/column_info.extra.unsigned'
##                 'Film:column_info'
##                 'Film:column_info.extra'
##                 'Film:column_info.extra.unsigned'
##     
##  OR:
##
##     'Film:columns/rental_rate'
##     'Film:columns/rental_rate.extra'
##     'Film:columns/rental_rate.extra.unsigned'
##          'columns/rental_rate'
##          'columns/rental_rate.extra'
##          'columns/rental_rate.extra.unsigned'
##                  'rental_rate'
##                  'rental_rate.extra'
##                  'rental_rate.extra.unsigned'
##                            '*.extra'
##                            '*.extra.unsigned'
##             'Film:rental_rate'
##             'Film:rental_rate.extra'
##             'Film:rental_rate.extra.unsigned'
### -------------



# -- for debugging:
#
#use Data::Dumper::Concise;
#print STDERR "\n\n" . Dumper(
#  #$Diff->filter->diff,
#  #$Diff->filter(
#  #  'Address'
#  #)->diff
#) . "\n\n";
