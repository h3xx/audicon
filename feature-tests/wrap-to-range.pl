#!/usr/bin/perl -w
use strict;

sub wrap_to_range {
	my $i = shift;

	(my $mx = shift)++; ($i % $mx + $mx) % $mx
}

printf "%d: %d\n", $_, &wrap_to_range($_, 5) for -20..20
