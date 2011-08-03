#!/usr/bin/perl -w
use strict;

use DBI;

use constant DB => 'samples.db';

my $db = DBI -> connect ('dbi:SQLite:dbname='.DB,'','');

foreach my $query (@ARGV) {
	my $transaction = $db -> prepare ($query);
	$transaction -> execute();

	for (my $row = $transaction -> fetch;
		$row;
		$row = $transaction -> fetch) {
		#my @cols = $row;
		print join "\t", @$row, "\n";
	}
}
