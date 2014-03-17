# -*- perl -*-

use strict;
use warnings;
use FindBin '$Bin';
use lib "$Bin/lib";

use Test::More;

use_ok('DBIx::Class::SchemaDiff');
use_ok('TestSchema::Sakila');
use_ok('TestSchema::Sakila2');
use_ok('TestSchema::Sakila3');

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
my $s1  = TestSchema::Sakila->connect(@connect);
my $s1b = TestSchema::Sakila->connect(@connect);
my $s3  = TestSchema::Sakila3->connect(@connect);

ok(
  NewD( old_schema => $s1, new_schema => $s1b ),
  'Instantiate DBIx::Class::SchemaDiff object using objects'
);

is(
  NewD( old_schema => $s1, new_schema => $s1b )->diff,
  undef,
  "Diffing identical schema objects shows no changes"
);

is(
  NewD( old_schema => $s1, new_schema => 'TestSchema::Sakila2' )->diff,
  undef,
  "Diffing identical schema object with class name shows no changes"
);


$s1b->source('Country')->add_columns( foo => {
  data_type => "varchar", is_nullable => 0, size => 50 
});

is_deeply(
  NewD( old_schema => $s1, new_schema => $s1b )->diff,
  { 'Country' => { 
    'columns' => {
      'foo' => { '_event' => 'added' }
    },
    '_event' => 'changed'
  }},
  "Saw added column 'foo'"
);




is_deeply(
  NewD( old_schema => $s1, new_schema => $s3 )->diff,
  {
    Address => {
      _event => "changed",
      relationships => {
        customers2 => {
          _event => "added"
        },
        staffs => {
          _event => "changed",
          diff => {
            attrs => {
              cascade_delete => 1
            }
          }
        }
      }
    },
    Film => {
      _event => "changed",
      columns => {
        rating => {
          _event => "changed",
          diff => {
            extra => {
              list => [
                "G",
                "PG",
                "PG-13",
                "R",
                "NC-17",
                "TV-MA"
              ]
            }
          }
        },
        rental_rate => {
          _event => "changed",
          diff => {
            size => [
              6,
              2
            ]
          }
        }
      }
    },
    FilmCategory => {
      _event => "changed",
      columns => {
        last_update => {
          _event => "changed",
          diff => {
            is_nullable => 1
          }
        }
      }
    },
    FooBar => {
      _event => "added"
    },
    Rental => {
      _event => "changed",
      relationships => {
        customer => {
          _event => "deleted"
        }
      }
    },
    SaleByStore => {
      _event => "deleted"
    }
  },
  "Saw expected changes between Sakila and Sakila3"
);


done_testing;