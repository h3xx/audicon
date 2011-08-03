#!/usr/bin/perl -w
use strict;

open SQLITE, '|sqlite3 data.db';

foreach (@ARGV) {
	s/'/''/g;
	print SQLITE "insert into instrument (instrument_description) values ('$_');";
}
