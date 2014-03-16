# -*- perl -*-

use strict;
use warnings;
use FindBin '$Bin';
use lib "$Bin/lib";

use Test::More;

use_ok('DBIx::Class::SchemaDiff');
use_ok('TestSchema::Sakila');
use_ok('TestSchema::Sakila2');

sub NewD { DBIx::Class::SchemaDiff->new(@_) } 

ok(
  NewD(
    old_schema => 'TestSchema::Sakila',
    new_schema => 'TestSchema::Sakila2'
  ),
  'Instantiate DBIx::Class::SchemaDiff object using class names'
);

is(
  NewD(
    old_schema => 'TestSchema::Sakila',
    new_schema => 'TestSchema::Sakila'
  )->diff,
  undef,
  "Diffing the same schema class shows no changes"
);

is(
  NewD(
    old_schema => 'TestSchema::Sakila',
    new_schema => 'TestSchema::Sakila2'
  )->diff,
  undef,
  "Diffing identical schema classes shows no changes"
);

my @connect = ('dbi:SQLite::memory:', '', '');
my $s1 = TestSchema::Sakila->connect(@connect);
my $s2 = TestSchema::Sakila->connect(@connect);

ok(
  NewD( old_schema => $s1, new_schema => $s2 ),
  'Instantiate DBIx::Class::SchemaDiff object using objects'
);

is(
  NewD( old_schema => $s1, new_schema => $s2 )->diff,
  undef,
  "Diffing identical schema objects shows no changes"
);


$s2->source('Country')->add_columns( foo => {
  data_type => "varchar", is_nullable => 0, size => 50 
});

is_deeply(
  NewD( old_schema => $s1, new_schema => $s2 )->diff,
  { 'Country' => { 'columns' => {
    'foo' => { 'added' => {
      'data_type' => 'varchar',
      'is_nullable' => 0,
      'size' => 50
    }}
  }}},
  "Expected added column 'foo'"
);


done_testing;