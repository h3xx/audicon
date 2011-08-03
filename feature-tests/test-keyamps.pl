#!/usr/bin/perl -w
use strict;

use Audicon::Feature::KeyAmplitudes;
use Audicon::Tools::UnweightedFFT;
use Audicon::Tools::AssociatedFreqs;
use constant HZ => 60;
use constant PI	=> 3.141592653589793238462643383279502884197;


sub ka_of_hz {
	my ($sampling_rate, $seconds) = @_;

	my @samples = map { sin $_ * HZ * 2 * PI / $sampling_rate } 0 .. ($sampling_rate * $seconds - 1);

	printf STDERR "created %d samples (%d seconds at %d per second)\n", scalar @samples, $seconds, $sampling_rate;

	my $amps = &fft_unweighted(\@samples);

	my $freqs = &associated_frequencies(scalar @{$amps->[0]}, $sampling_rate);

	my $kc = Audicon::Feature::KeyAmplitudes->new({
			'freqs'	=> $freqs,
		});
	print STDERR "initialized\nexpanding octave... ";
	$kc->_probe_keyset;
	printf STDERR "done (%d keys)\ngenerating matrix... ", scalar @{$kc->{'keyset'}};
	$kc->_probe_match_matrix;
	printf STDERR "done (%d, %d)\n", $kc->{'match_matrix'}->dim;
}

&ka_of_hz(44100, 0.5);
