package Audicon::Feature::MagnitudeRatio;

use strict;
use warnings;

our $VERSION = '0.02';

require Exporter;

our @ISA = qw/ Exporter /;

our %EXPORT_TAGS = ( 'all' => [ qw/
	magnitude_ratio
/ ] );

our @EXPORT_OK = qw//;
our @EXPORT = ( @{ $EXPORT_TAGS{'all'} } );

=head1 NAME

Audicon::Feature::MagnitudeRatio - calculates the ratio of magnitudes (absolute amplitude * frequency) between a `clip' of audio and the `texture frame' in which it occurs.

=head1 DESCRIPTION

Finds the ratio of total magnitude contained in a given audio clip out of the total magnitude of the [presumably larger] texture frame in which it occurs.

The magnitude ratio is a measure of how `loud' a set of audio samples is, when compared to the audio samples surrounding it. It is characterized by the following function:

       Fc
      ---
      \
       \ fc * C[fc]
       /
      /
      ---
       fc
 M = -------------
       Ft
      ---
      \
       \ ft * T[ft]
       /
      /
      ---
       ft

where B<Fc>, B<Ft> are the highest frequency bins for the clip and texture frame, B<fc> and B<ft> are their respective bins' frequencies and B<C[fc]> and B<T[ft]> are the respective unweighted amplitudes of the frequency bins representing frequencies I<fc> and I<ft> as an output of the Fourier transform.

=head1 SYNOPSIS

	use Audicon::Tools
		qw/ fft_unweighted fft_weighted associated_frequencies /;
	use Audicon::Feature::MagnitudeRatio	qw/ magnitude_ratio /;

	# people don't usually type their own audio data,
	# but this is just an example
	my @clip_samples = (....);
	my @tex_samples = (.........);

	# 44.1 kHz (standard CD audio)
	my $sampling_rate = 44_100;

	# get the unweighted Fourier transform bins
	# (returns array ref: [real, imaginary])
	my $amps_clip = &fft_unweighted(\@clip_samples, $sampling_rate);
	my $amps_tex = &fft_unweighted(\@tex_samples, $sampling_rate);

	# get the list of frequencies (in Hz) associated with each bin
	my $freqs_clip = &associated_frequencies(scalar @{$amps_clip->[0]},
		$sampling_rate);
	my $freqs_tex = &associated_frequencies(scalar @{$amps_tex->[0]},
		$sampling_rate);

	# get the weighted Fourier transform bins
	# (returns array ref: [real, imaginary])
	my $clip_mags = &fft_weighted($amps_clip, $freqs_clip);
	my $tex_mags = &fft_weighted($amps_tex, $freqs_tex);

	# calculate the magnitude ratio based on only the REAL number portion
	# of the Fourier transform
	my $magratio_real = &magnitude_ratio(
		'mags'	=> $clip_mags->[0],
		't_mags'=> $tex_mags->[0],
	);

	# -- OR --

	# calculate the magnitude ratio based on both the REAL and the
	# IMAGINARY number portions of the Fourier transform
	my ($magratio_real, $magratio_imag) =
		&magnitude_ratio(
			'mags'	=> $clip_mags,
			't_mags'=> $tex_mags,
		);

=head1 EXPORT

Exports the function L</magnitude_ratio>.

=head1 SUBROUTINES

=head2 magnitude_ratio

Calculates the ratio of total magnitude of the audio clip relative to the total magnitude of the texture clip in which the prior occurs.

	my $magratio = &magnitude_ratio(
		'mags'	=> $clip_mags,
		't_mags'=> $tex_mags,
	);

=cut

sub magnitude_ratio {
	my ($clip_mags, $tex_mags) = @{{@_}}{qw/ mags t_mags /};

	# pre-format arrays (makes iteration easier)
	$clip_mags = [ $clip_mags ] unless ref $clip_mags->[0] eq 'ARRAY';
	$tex_mags = [ $tex_mags ] unless ref $tex_mags->[0] eq 'ARRAY';

	# initialize return buffer
	my @magratios;

	foreach my $binset_index (0 .. (sort $#{$clip_mags}, $#{$tex_mags})[0]) {
		my ($sum_clip, $sum_tex) = (0, 0);

		$sum_clip += $_ foreach @{$clip_mags->[$binset_index]};
		$sum_tex += $_ foreach @{$tex_mags->[$binset_index]};

		push @magratios, $sum_tex ? $sum_clip / $sum_tex : 0;
	}

	@magratios
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
