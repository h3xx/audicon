package Audicon::Feature::SpectralFlux;

use strict;
use warnings;

our $VERSION = '0.02';

require Exporter;

our @ISA = qw/ Exporter /;

our %EXPORT_TAGS = ( 'all' => [ qw/
	spectral_flux
/ ] );

our @EXPORT_OK = qw//;
our @EXPORT = ( @{ $EXPORT_TAGS{'all'} } );

=head1 NAME

Audicon::Feature::SpectralFlux - calculates the spectral flux between two given subsequent sets of FFT bins.

=head1 DESCRIPTION

Finds the rates of total amplitude change between two consecutive audio clips.

Spectral flux is defined as the squared difference between the unweighted amplitudes of successive spectral distributions. It is characterized by the following function:

    F
   ---
   \
    \  (N(t)[f] - N(t-1)[f])^2
    /
   /
   ---
    f
  
where B<F> is the highest frequency bin, B<N(t)[f]> and B<N(t-1)[f]> are the unweighted amplitude of the Fourier transform bin representing frequency B<f> at the current frame B<t>, and previous frame # B<t-1>, respectively.

=head1 SYNOPSIS

	use Audicon::Tools	qw/ fft_unweighted /;
	use Audicon::Feature::SpectralFlux	qw/ spectral_flux /;

	# people don't usually type their own audio data,
	# but this is just an example
	my @audio_samples = (....);
	my @prev_samples = (....);

	# 44.1 kHz (standard CD audio)
	my $sampling_rate = 44_100;

	# get the unweighted Fourier transform bins
	# (returns array ref: [real, imaginary])
	my $curr_amps = &fft_unweighted(\@audio_samples, $sampling_rate);
	my $prev_amps = &fft_unweighted(\@prev_samples, $sampling_rate);

	# calculate the spectral flux based on only the REAL number portion of
	# the Fourier transform
	my $flux_real = &spectral_flux(
		'amps'	=> $curr_amps->[0],
		'amps_p'=> $prev_amps->[0],
	);

	# -- OR --

	# calculate the spectral flux based on both the REAL and the IMAGINARY
	# number portions of the Fourier transform
	my ($flux_real, $flux_imag) = &spectral_flux(
		'amps'	=> $curr_amps,
		'amps_p'=> $prev_amps,
	);

=head1 EXPORT

Exports the function L</spectral_flux>.

=head1 SUBROUTINES

=head2 spectral_flux

Returns the spectral flux of a set of sequential audio samples' unweighted FFT bins.

	my $flux_real = &spectral_flux(
		'amps'	=> $curr_amps->[0],
		'amps_p'=> $prev_amps->[0],
	);

	my $flux_imag = &spectral_flux(
		'amps'	=> $curr_amps->[1],
		'amps_p'=> $prev_amps->[1],
	);

	# -- OR --

	# both $curr_amps and $prev_amps contains the arrays of both real
	# (index 0) and imaginary (index 1) Fourier transform bin values

	my ($flux_real, $flux_imag) = &spectral_flux(
		'amps'	=> $curr_amps,
		'amps_p'=> $prev_amps,
	);

=cut

sub spectral_flux {
	my ($curr_amps, $prev_amps) = @{{@_}}{qw/ amps amps_p /};

	# pre-format arrays (makes iteration easier)
	$curr_amps = [ $curr_amps ] unless ref $curr_amps->[0] eq 'ARRAY';
	$prev_amps = [ $prev_amps ] unless ref $prev_amps->[0] eq 'ARRAY';

	# initialize return buffer
	my @fluxes;

	foreach my $binset_index (0 .. (sort $#{$curr_amps}, $#{$prev_amps})[0]) {
		my $flux = 0;
		$flux += ($curr_amps->[$binset_index]->[$_] - $prev_amps->[$binset_index]->[$_]) ** 2
		for 0 .. (sort $#{$curr_amps->[$binset_index]}, $#{$prev_amps->[$binset_index]})[0];

		push @fluxes, $flux;
	}

	@fluxes
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
