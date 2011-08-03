#!/usr/bin/perl -w
use strict;

use Audicon::Tools::WeightedFFT;
use Audicon::Tools::UnweightedFFT;
use Audicon::Tools::AssociatedFreqs;
use Audicon::Feature::SpectralRolloff;

use constant PI			=> 3.141592653589793238462643383279502884197;
use constant HZ			=> 60;

sub r_of_hz {
	my ($sampling_rate, $seconds) = @_;

	my @samples = map { sin $_ * HZ * 2 * PI / $sampling_rate } 0 .. ($sampling_rate * $seconds - 1);

	printf STDERR "created %d samples (%d seconds at %d per second)\n", scalar @samples, $seconds, $sampling_rate;

	my $amps = &fft_unweighted(\@samples, $sampling_rate);
	my $freqs = &associated_frequencies(@samples / 2 + 1, $sampling_rate);
	my $mags = &fft_weighted($amps, $freqs);

	print join ("\n", @{$mags}[ 55 .. 65 ]), "\n";
#	my $rolloff_real = &spectral_rolloff($mags->[0], $sampling_rate);
#	my $rolloff_imag = &spectral_rolloff($mags->[1], $sampling_rate);

	#print STDERR join (':', @{$amps->[0]}), "\n";
#	print "real rolloff: $rolloff_real\nimaginary rolloff: $rolloff_imag\n\n";
}



#for (1 .. 8) {
	&r_of_hz(22_050, 0.5);
	&r_of_hz(44_100, 1);
#}
