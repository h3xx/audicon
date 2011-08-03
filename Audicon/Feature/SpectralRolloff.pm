package Audicon::Feature::SpectralRolloff;

use strict;
use warnings;

our $VERSION = '0.02';

require Exporter;

our @ISA = qw/ Exporter /;

our %EXPORT_TAGS = ( 'all' => [ qw/
	spectral_rolloff
/ ] );

our @EXPORT_OK = qw//;
our @EXPORT = ( @{ $EXPORT_TAGS{'all'} } );

=head1 NAME

Audicon::Feature::SpectralRolloff - computes the spectral rolloff of a given set of FFT bins.

=head1 DESCRIPTION

Finds the point in the frequency spectrum where the `rolloff' point occurs.

The spectral rolloff is based on the weighted (amplitude * frequency) output of the fast Fourier transform (FFT) and is defined as the minimum frequency B<R>, such that the following equasion is true:

  R              N
 ---            ---
 \              \
  \ M[f] >= c *  \ M[f]
  /              /
 /              /
 ---            ---
 f=1            f=1

where B<M[f]> is the weighted amplitude of the FFT frequency bin corresponding to frequency B<f>, B<N> is equal to the total number of frequency bins and B<c> is a value from 0 to 1, representing the target concentration for the rolloff point. A traditional value for I<c> is 0.85.

=head1 SYNOPSIS

	use Audicon::Tools
		qw/ fft_unweighted fft_weighted associated_frequencies /;
	use Audicon::Feature::SpectralRolloff	qw/ spectral_rolloff /;

	# people don't usually type their own audio data,
	# but this is just an example
	my @audio_samples = (....);

	# 44.1 kHz (standard CD audio)
	my $sampling_rate = 44_100;

	# get the unweighted Fourier transform bins
	# (returns array ref: [real, imaginary])
	my $amps = &fft_unweighted(\@audio_samples, $sampling_rate);

	# get the list of frequencies (in Hz) associated with each bin
	my $freqs = &associated_frequencies(scalar @{$amps->[0]},
		$sampling_rate);

	# get the weighted Fourier transform bins
	# (returns array ref: [real, imaginary])
	my $mags = &fft_weighted($amps, $freqs);

	# set the target concentration threshold for the rolloff
	# (0.85 is the default if not specified)
	my $concentration = 0.85;

	# calculate the spectral rolloff based on only the REAL number portion
	# of the Fourier transform
	my $rolloff_real = &spectral_rolloff(
		'mags'		=> $mags->[0],
		'sampling_rate'	=> $sampling_rate,
		'concentration'	=> $concentration,
	);

	# -- OR --

	# calculate the spectral rolloffs based on both the REAL and the
	# IMAGINARY number portions of the Fourier transform
	my ($rolloff_real, $rolloff_imag) = &spectral_rolloff(
		'mags'		=> $mags,
		'sampling_rate'	=> $sampling_rate,
		'concentration'	=> $concentration,
	);

=head1 EXPORT

Exports the function L</spectral_rolloff>.

=head1 SUBROUTINES

=head2 spectral_rolloff

Gets the spectral rolloff (in frequency) from a set of weighted FFT bins.

	my $concentration = 0.85; # default value

	my $rolloff_real = &spectral_rolloff(
		'mags'		=> $mags->[0],
		'sampling_rate'	=> $sampling_rate,
		'concentration'	=> $concentration,
	);

	my $rolloff_imag = &spectral_rolloff(
		'mags'		=> $mags->[1],
		'sampling_rate'	=> $sampling_rate,
		'concentration'	=> $concentration,
	);

	# -- OR --

	# $mags contains the arrays of both real (index 0) and imaginary (index
	# 1) weighted Fourier transform bin values

	my ($rolloff_real, $rolloff_imag) = &spectral_rolloff(
		'mags'		=> $mags,
		'sampling_rate'	=> $sampling_rate,
	);


Note: if a value 1 or greater is given as the concentration parameter, the returned frequency will always be the highest available in the bin sample.

=cut

sub spectral_rolloff {
	my ($mags, $sampling_rate, $concentration) =
		@{{@_}}{qw/ mags sampling_rate concentration /};

	$concentration = 0.85 unless $concentration;

	# (No, I won't warn, nor will I short-circuit the function if
	# $concentration >= 1. People can waste their own damn CPU cycles.)

	# initialize return buffer
	my @rolloffs;

	# figure out how complex the `$mags' array is and iterate over each bin
	# array found
	foreach my $wbins (ref $mags->[0] eq 'ARRAY' ? @{$mags} : $mags) {
		# find the total magnitude of this bin series
		my $target = 0;
		$target += $_ foreach @{$wbins};

		# adjust for the given target concentration
		$target *= $concentration;

		# loop until we reach the target magnitude sum
		my ($ro_sum, $bin_index) = (0, 0);
		$ro_sum += $wbins->[$bin_index++]
			while $ro_sum < $target && $bin_index < @{$wbins};

		# find the frequency associated with the bin we found to be the
		# rolloff point in the same manner that &associated_frequencies
		# would use (see Audicon::Tools). $bin_index here would equal
		# the index of the bin AFTER which the target concentration had
		# been reached
		push @rolloffs, ($bin_index - 1) * $sampling_rate / @{$wbins} / 2;
	}

	@rolloffs
}

=head1 NOTES

This module can be used directly, but is meant for use in L<Audicon::Feature>.

=head1 AUTHOR

Dan Church S<E<lt>amphetamachine@gmail.comE<gt>>

=head1 SEE ALSO

=over

=item L<Audicon::Feature>

=item L<Audicon::Tools>

=back

=head1 COPYRIGHT

Copyright 2008 Dan Church.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the LICENSE file included with this module.

=cut

1
