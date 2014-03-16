# -*- perl -*-

use strict;
use warnings;
use FindBin '$Bin';
use lib "$Bin/lib";

use Test::More;

use_ok('DBIx::Class::SchemaDiff');
use_ok('TestSchema::Sakila');
use_ok('TestSchema::Sakila2');

my @connect = ('dbi:SQLite::memory:', '', '', {
  AutoCommit			=> 1,
  on_connect_call	=> 'use_foreign_keys'
});

my $schema1 = TestSchema::Sakila->connect(@connect);
my $schema2 = TestSchema::Sakila2->connect(@connect);

my $Diff;

ok(
  $Diff = DBIx::Class::SchemaDiff->new(
    old_schema => $schema1,
    new_schema => $schema2
  ),
  'Instantiate DBIx::Class::SchemaDiff object'
);

use RapidApp::Include qw(sugar perlutil);

scream_color(BLUE.ON_WHITE,$Diff->old_data->{Country});
scream_color(GREEN.ON_WHITE,$Diff->new_data->{Country});

scream(
  $Diff->diff_data->{Country}
  
  #$schema->sources
);


done_testing;