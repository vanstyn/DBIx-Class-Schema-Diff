package DBIx::Class::Schema::Diff::State;
use strict;
use warnings;

# ABSTRACT: Diff object of a single schema

use Moo;
extends 'DBIx::Class::Schema::Diff';
#with 'DBIx::Class::Schema::Diff::Role::Common';

use RapidApp::Util ':all';

require DBIx::Class::Schema::Diff::Schema;

use Types::Standard qw(:all);

has 'schema', is => 'ro', isa => Maybe[Str], default => sub { undef };

has '_schema_diff', required => 1, is => 'ro', isa => InstanceOf['DBIx::Class::Schema::Diff::Schema'];

around BUILDARGS => sub {
  my ($orig, $self, @args) = @_;
  my %opt = (ref($args[0]) eq 'HASH') ? %{ $args[0] } : @args; # <-- arg as hash or hashref
  
  die "Must supply single 'schema' not old_schema and new_schema" if ($opt{new_schema} || $opt{old_schema});
  
  unless($opt{_schema_diff}) {
    my $schema = $opt{schema} or die "schema argument required";
    $opt{_schema_diff} = DBIx::Class::Schema::Diff::Schema->new( 
      new_schema => $schema, 
      old_schema => $schema, 
      new_schema_only => 1 
    )
  }
  
  return  $self->$orig(%opt) 
};



1;


__END__

=head1 NAME

DBIx::Class::Schema::Diff::State - Diff object of a single schema

=head1 SYNOPSIS

 use DBIx::Class::Schema::Diff::SchemaState;
 
 

=head1 DESCRIPTION



=head1 METHODS


=head1 SEE ALSO

=over

=item *

L<DBIx::Class::Schema::Diff>

=back

=head1 AUTHOR

Henry Van Styn <vanstyn@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2020 by IntelliTree Solutions llc.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
