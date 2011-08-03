#!/usr/bin/perl -w
use strict;

use Audicon::Tools::UnweightedFFT;
use Audicon::Tools::AssociatedFreqs;
use Audicon::Feature::CentroidFreq;

use constant PI			=> 3.141592653589793238462643383279502884197;
use constant HZ			=> 60;

sub c_of_hz {
	my ($sampling_rate, $seconds) = @_;

	my @samples = map { sin $_ * HZ * 2 * PI / $sampling_rate } 0 .. ($sampling_rate * $seconds - 1);

	printf STDERR "created %d samples (%d seconds at %d per second)\n", scalar @samples, $seconds, $sampling_rate;

	my $amps = &fft_unweighted(\@samples, $sampling_rate);

	my $freqs = &associated_frequencies(scalar @{$amps->[0]}, $sampling_rate);

	my $centroid_real = &centroid_frequency($amps->[0], $freqs);
	my $centroid_imag = &centroid_frequency($amps->[1], $freqs);

	#print STDERR join (':', @{$amps->[0]}), "\n";
	print "real centroid: $centroid_real\nimaginary centroid: $centroid_imag\n\n";
}

for (1 .. 8) {
	&c_of_hz(22_050, $_);
	&c_of_hz(44_100, $_);
}
