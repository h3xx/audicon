#!/usr/bin/perl -w
use strict;

use constant PI			=> 3.141592653589793238462643383279502884197;
use constant HZ			=> 60;
use constant HZZ		=> 120;
use constant SECONDS		=> 1;
use constant SAMPLING_RATE	=> 44100;

sub samps {
	my $hz = shift;
	[ map { sin $_ * $hz * 2 * PI / SAMPLING_RATE } 0 .. (SAMPLING_RATE * SECONDS - 1) ]
}

sub integ {
	my $samps = shift;

	my $integ = 0;
	$integ += abs $_ foreach @{$samps};

	$integ
}

printf STDERR "%-3d: %f\n" x 2, map {($_, &integ(&samps($_)))} (HZ, HZZ);
