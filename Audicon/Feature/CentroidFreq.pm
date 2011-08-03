package Audicon::Feature::CentroidFreq;

use strict;
use warnings;

our $VERSION = '0.02';

require Exporter;

our @ISA = qw/ Exporter /;

our %EXPORT_TAGS = ( 'all' => [ qw/
	centroid_frequency 
/ ] );

our @EXPORT_OK = qw//;
our @EXPORT = ( @{ $EXPORT_TAGS{'all'} } );

=head1 NAME

Audicon::Feature::CentroidFreq - computes the centroid (spectral center of gravity) frequency of a given set of FFT bins.

=head1 DESCRIPTION

Finds the center of spectral `gravity' of an audio sample.

The centroid frequency is a measure of spectral brightness of a given set of unweighted FFT bin amplitudes. It is characterized by the following function:

   F
  ---
  \
   \ f * N[f]
   /
  /
  ---
   f
 -------------
     F
    ---
    \
     \ N[f]
     /
    /
    ---
     f

where B<F> is the highest frequency bin, B<f> is the frequency and B<N[f]> is the unweighted amplitude of the frequency bin representing frequency I<f> as an output of the Fourier transform.

=head1 SYNOPSIS

	use Audicon::Tools
		qw/ fft_unweighted fft_weighted associated_frequencies /;
	use Audicon::Feature::CentroidFreq	qw/ centroid_frequency /;

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

	# calculate the centroid frequency based on only the REAL number
	# portion of the Fourier transform
	my $centroid_real = &centroid_frequency(
		'amps'	=> $amps->[0],
		'mags'	=> $mags->[0],
	);

	# -- OR --

	# calculate the centroid frequencies based on both the REAL and the
	# IMAGINARY number portions of the Fourier transform
	my ($centroid_real, $centroid_imag) =
		&centroid_frequency(
			'amps'	=> $amps,
			'mags'	=> $mags,
		);

=head1 EXPORT

Exports the function L</centroid_frequency>.

=head1 SUBROUTINES

=head2 centroid_frequency

Returns the centroid frequency of an audio sample from a set of its weighted and unweighted FFT bins.

	my $centroid_real = &centroid_frequency(
		'amps'	=> $amps->[0],
		'mags'	=> $mags->[0],
	);

	my $centroid_imag = &centroid_frequency(
		'amps'	=> $amps->[1],
		'mags'	=> $mags->[1],
	);

	# -- OR --

	# both $mags and $amps contains the arrays of both real (index 0) and
	# imaginary (index 1) Fourier transform bin values

	my ($centroid_real, $centroid_imag) =
		&centroid_frequency(
			'amps'	=> $amps,
			'mags'	=> $mags,
		);

=cut

sub centroid_frequency {
	my ($amps, $mags) = @{{@_}}{qw/ amps mags /};

	# pre-format arrays (makes iteration easier)
	$amps = [ $amps ] unless ref $amps->[0] eq 'ARRAY';
	$mags = [ $mags ] unless ref $mags->[0] eq 'ARRAY';

	# initialize return buffer
	my @centroids;

	foreach my $binset_index (0 .. (sort $#{$amps}, $#{$mags})[0]) {
		my ($sum_mags, $sum_amps) = (0, 0);

		# sum bin values, making sure we don't get an index out of
		# bounds error
		map {
			$sum_amps += $amps->[$binset_index]->[$_];
			$sum_mags += $mags->[$binset_index]->[$_];
		} 0 .. (sort $#{$amps->[$binset_index]}, $#{$mags->[$binset_index]})[0];

		# divide the sums
		push @centroids, $sum_amps ? $sum_mags / $sum_amps : 0;
	}

	@centroids
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
