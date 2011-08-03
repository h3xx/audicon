#!/usr/bin/perl -w
use strict;

use Audio::Wav;
use Audicon::Tools::UnweightedFFT;
use Audicon::Tools::AssociatedFreqs;
use Audicon::Feature::CentroidFreq;
use Data::Dumper;


&do_bla;

sub do_bla {
	my $wav = new Audio::Wav;
	my $self = {
		'reader'	=> $wav->read($ARGV[0]),
		'norm_coeff'	=> 1,
	};

	my $sampling_rate = $self->{'reader'}->{'data'}->{'sample_rate'};

	# read the wav file's merged channels into one long array
	my $samples = &_read_mono_norm($self, 0, 10_000);
	printf STDERR "read %d samples\n", scalar @{$samples};

	my $amps = &fft_unweighted($samples);
	printf STDERR "got (%d, %d) FFT bins (fft_unweighted)\n",
		scalar @{$amps->[0]}, scalar @{$amps->[1]};

	my $freqs = &associated_frequencies(scalar @{$amps->[0]},
		$sampling_rate);
	printf STDERR "got %d associated frequencies\n", scalar @{$freqs};

	my $centroid_real = &centroid_frequency($amps->[0], $freqs);
	my $centroid_imag = &centroid_frequency($amps->[1], $freqs);

	print "real centroid: $centroid_real\nimaginary centroid: $centroid_imag\n";
}

# reads a bunch of samples, merges the channels, normalizes and returns an
# array ref to the floating-point samples

sub _read_mono_norm {
	my $self = shift;
	my $from = shift;
	my $length = shift;

	my $num_samples = $self->{'reader'}->{'data'}->{'length'} *
		$self->{'reader'}->{'data'}->{'sample_rate'};

	# specifying $length = -1 means read to the end of the file
	# (you probably don't ever want to do this, but why the hell not
	# support it)
	$length = ($length == -1 ? $num_samples : abs $length);

	# wrap the position to fall within data bounds (weird but works)
	my $pos = ($from % ++$num_samples + $num_samples) % $num_samples--;

	my $sample_buffer = [];

	$self->{'reader'}->move_to_sample($pos);

	# fill samples until we complete the length requirement
	while (@$sample_buffer < $length) {
		unless (++$pos < $num_samples) {
			# reached the end -- wrap!
			$self->{'reader'}->move_to_sample($pos = 0);
		}

		my $sample = 0;
		my @chans = $self->{'reader'}->read;
		$sample += $_ foreach @chans;
		push @$sample_buffer, $sample * $self->{'norm_coeff'} / @chans;
	}

	$sample_buffer
}

