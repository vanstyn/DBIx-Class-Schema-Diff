# -*- perl -*-

use strict;
use warnings;
use FindBin '$Bin';
use lib "$Bin/lib";

use Test::More;

use_ok('DBIx::Class::SchemaDiff');
use_ok('TestSchema::Sakila');
use_ok('TestSchema::Sakila2');

my $Diff;

my @connect = ('dbi:SQLite::memory:', '', '', {
  AutoCommit			=> 1,
  on_connect_call	=> 'use_foreign_keys'
});

ok(
  $Diff = DBIx::Class::SchemaDiff->new(
    old_schema => TestSchema::Sakila->connect(@connect),
    new_schema => TestSchema::Sakila2->connect(@connect)
  ),
  'Instantiate DBIx::Class::SchemaDiff object'
);

ok(
  $Diff = DBIx::Class::SchemaDiff->new(
    old_schema => 'TestSchema::Sakila',
    new_schema => 'TestSchema::Sakila2'
  ),
  'Instantiate DBIx::Class::SchemaDiff object using class names'
);

use RapidApp::Include qw(sugar perlutil);

#scream_color(BLUE.BOLD,$Diff->old_data->{Country});
#scream_color(GREEN.BOLD,$Diff->new_data->{Country});

scream(
  $Diff->diff
  
);


done_testing;