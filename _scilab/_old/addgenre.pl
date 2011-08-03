#!/usr/bin/perl -w
use strict;

open SQLITE, '|sqlite3 data.db';

foreach (@ARGV) {
	s/'/''/g;
	print SQLITE "insert into genre (genre_description) values ('$_');";
}
