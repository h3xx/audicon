package Audicon::Tools;

use strict;
use warnings;

our $VERSION = '0.02';

use Exporter;

our @ISA = qw/ Exporter /;

our %EXPORT_TAGS = ( 'default' => [ qw/
	fft_all
/ ],

'all' => [ qw/
	fft_all
	fft_unweighted
	fft_weighted
	associated_frequencies
/ ] );

our @EXPORT = ( @{ $EXPORT_TAGS{'default'} } );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

use Math::FFTW;

# for &fft_all
use constant MODE	=> 'dist';

# for speeding up calculations in &associated_frequencies
our $precalc = {};

=head1 NAME

Audicon::Tools - a collection of simple functions to aid in the interpretation of FFT bin data.

=head1 DESCRIPTION

Many of the calculations performed by L<Audicon> on a particular set of audio data require the deconstruction of the waveform of the audio into frequency/amplitude pairs. This module was created in order to deal with the deconstruction of the audio data in this fashion.

=head2 Preamble

First of all, audio is a sequence of micro-changes air pressure which are transmitted over distances and perceived by the human ear as sound. These air pressure variations can be expressed as a positive or negative value, depending on what increase or decrease beyond "neutral" air pressure is created:

 ^ | __        __        __
 + |/  \      /  \      /  \
  0|----\----/----\----/----\----
 - |     \  /      \  /      \  /
 v |      --        --        --
   time ->

Digital audio waveforms are merely a collection of values, in essence, between C<-1> and C<1>, inclusive, which are called B<samples>. Samples represent what the air pressure will be at the point in time where the sample occurs. The rate at which the samples are converted to air pressure variations ("playing" the digital audio) is described as the B<sampling rate>. The sampling rate is expressed in the number samples that represent one second of digital audio.

Through the graphing of the audio samples' values by time, we can see how they represent the original waveform:

 +1| ..        ..        ..
   |-  -      -  -      -  -
  0|----*----*----*----*----*----
   |     -  -      -  -      -  -
 -1|      --        --        --
   time ->

Because digital audio uses computerized values for the representation of these samples, the maximum height of a waveform is limited to C<+/-1>.

=head2 Language

Regarding the deconstruction of audio data, there are certain terms used in this document that require explanation:

=over

=item amplitude

In sound, B<amplitude> refers to the loudness of the waveform, also described as the amount of air pressure change that the waveform produces. In physical sound, it is measures in pascals. In digital sound, however it becomes a measure of its height within the limit of the samples' maximum value:

 +1| __        __        __.........._
   |/  \      /  \      /  \         |--- amplitude
  0|----\----/----\----/----\----....-
   |     \  /      \  /      \  /
 -1|      --        --        --
   time ->

=item frequency

A B<frequency>, or pitch is an expression of how many times per second a given waveform completes its cycle, or B<period>. It is expressed in B<Hz>, or cycles per second.

      +---------+---------+------ peaks
      |         |         |
      v         v         v
 +1| __        __        __
   |/  \      /  \      /  \
  0|----\----/----\----/----\----.
   |     \  /      \  /      \  /.
 -1|      --        --        -- .
   time ->                       .
   .                             .
   |----------1 second-----------|

   3 peaks in 1 second => frequency: 3 Hz

=item bin

A B<frequency bin>, or B<bin>, means a summation of the amplitudes of all frequencies associated with that bin as they occur in the deconstructed waveform.

Frequency bins are an effective representation of the loudness, or B<amplitude> of the musical notes, or B<tones> present in a waveform.

=item magnitude

Because higher-frequency waveforms carry more energy than lower-frequency ones, it becomes necessary to think of a waveform in terms of the total energy carried by it. The B<magnitude> of a waveform is an expression of this. It is the amplitude of the waveform weighted by its frequency, and is found by multiplying its amplitude by its frequency.

The energy said to be carried by a given waveform is expressed as the total change in air displacement incurred by the transmission of that waveform. This can be found by finding the absolute derivative of the waveform.

=item phase

The B<phase> of a given waveform refers to the point in its cycle at which it is first observed. It is typically measured in radians from 0 the value of theta would be in the waveform's sine function.

A simpler way of defining it would be to think of it in terms of how far the beginning of the period of the waveform is from the origin:

   +------ first period starts at the origin; no phasing
   |
   v
 +1| __        __        __
   |/  \      /  \      /  \
  0|----\----/----\----/----\----
   |     \  /      \  /      \  /
 -1|      --        --        --
   time ->

      +--- first period begins here
      |
   +------ began observing here (3/4 through last period)
   |  |        => phasing of +1/4 of a period = +pi/2
   v  v
 +1|    __        __        __
   |   /  \      /  \      /  \
  0|--/----\----/----\----/----\-
   | /      \  /      \  /      \
 -1|-        --        --
   time ->

=back

=head2 The Fourier Transform

Joseph Fourier discovered that within complex waveforms exist many simpler waveforms with their own individual pitches. The Fourier transform was built as a way to decompose these complex waveforms into the simpler ones.

By design, the computerized Fourier transform gives a deconstruction of a waveform as a set of complex values, whose real and imaginary portions relate to one another in a way that it is possible to reconstruct the original waveform, complete with phased and non-phased waveforms.

For the purposes of the audio analysis performed by L<Audicon>, the deconstuction is a one-way process. Therefore it becomes necessary to simplify the Fourier transform deconstruction's data in such a way that it is able to be processed in an ad hoc manner. That is what this module's purpose is.

=head1 SYNOPSIS

	use Audicon::Tools
		qw/ fft_unweighted fft_weighted associated_frequencies /;

	# most people don't type their own audio data,
	# but this is just an example
	my @audio_samples = (....);

	# 44.1 kHz (standard CD audio)
	my $sampling_rate = 44_100;

	# calculate unweighted bin values
	# (returns multi-dimensional array ref whose two main indices (0, 1)
	# are references to the arrays of values representing the respective
	# REAL and IMAGINARY portions of the Fourier transform.)
	my $amps = &fft_unweighted(\@audio_samples, $sampling_rate);

	# get the list of frequencies (in Hz) associated with each bin
	my $freqs = &associated_frequencies(scalar @{$amps->[0]}, $sampling_rate);

	# get the weighted (amplitude * freqency) bin values
	# (like fft_unweighted, returns a multi-dimensional array)
	my $mags = &fft_weighted($amps, $freqs);

Alternatively, one may use the shortcut function L</fft_all> to obtain all three (unweighted, weighted and associated frequencies) and in a single hash with three keys, respectively B<'amps'>, B<'mags'> and B<'freqs'>.

This function also provides a method of combining both the real and imaginary portions of the Fourier transform into a dataset that represents the waveform in a standardized fashion, returning the same bin value for a particular frequency/amplitude combination regardless of whether it was phase-shifted when it occurred in the waveform.

	use Audicon::Tools	qw/ fft_all /;

	my $fft_data = &fft_all(
		'samples'	=> \@audio_samples,
		'sampling_rate'	=> $sampling_rate,
		'mode'		=> 'dist', # default
	);

	# parse the different parts
	my ($amps, $mags, $freqs) = @{$fft_data}{qw/ amps mags freqs /};

=head1 EXPORT

Exports the function L</fft_all> by default.

Functions L</fft_unweighted>, L</fft_weighted> and L</associated_frequencies> may be exported by request, either individually, or with the C<:all> tag.

=head1 SUBROUTINES

=head2 fft_unweighted

Performs the fast Fourier transform on the sample array reference you pass it, then returns a multi-dimenstional array with both the unweighted real and imaginary portions.

	# calculate both real and imaginary portions at the same time
	my $amps = &fft_unweighted(\@audio_samples, $sampling_rate);

	# interpret them separately
	my ($amps_real, $amps_imag) = @{$amps};

=cut

sub fft_unweighted {
	my ($samples, $sampling_rate) = @_;

	# produce an error message if we can't make sense of the sampling rate
	die 'received a sampling rate of 0 (this is just silly)'
		unless $sampling_rate;

	# get the comples FFT bins from FFTW
	# format: [real0, imag0, real1, imag1, ...]
	my $bins = &Math::FFTW::fftw_dft_real2complex_1d($samples);

	#my @amps;
	#
	# this is not exact; the amplitude of a 0-Hz wave *should* be 0
	# ... but it's not
	#for (my $x = 1; $x < @{$bins}; $x += 2) {
	#	push @amps, - $bins->[$x] / $sampling_rate * 2
	#}
	#
	#\@amps

	# this does the same thing in less lines
	#[ map {
	#	$_ % 2 ? - $bins->[$_] / $sampling_rate * 2 : ()
	#} 0 .. $#{$bins} ]

	# this does it just as efficiently, plus it doesn't discard the
	# imaginary portion
	my @amps;

	# separate real (index 0) and imaginary (index 1) portions and modify
	# the values to be between 0 and 1
	# note: i can't remember why this calculation works; it just does!
	push @{$amps[$_ % 2]}, abs $bins->[$_] / $sampling_rate * 2
		for 0 .. $#{$bins};

	\@amps
}

=head2 fft_weighted

A weighted Fourier transform bin is equal to the value of the absolute amplitude of the waveform that bin represents, multiplied with the frequency associated to that bin. The result is a set of bins that are often referred to as representative of the magnitude of each component wave, as higher-frequency waves carry more energy than lower-frequency ones.

The returned array ref will be of similar complexity to the array of amplitudes passed in, which, as stated above, may contain one or both REAL or IMAGINARY bin vectors.

This function is designed to be used in conjunction with L</fft_unweighted> and L</associated_frequencies>.

	# calculate both real and imaginary portions at the same time
	# (@amps contains both REAL and IMAGINARY bin sets)
	my $mags = &fft_weighted(\@amps, \@freqs);
	my ($mags_real, $mags_imag) = @{$mags};

	# calculate real and imaginary portions separately
	my $mags_real = &fft_weighted(\@amps_real, \@freqs);
	my $mags_imag = &fft_weighted(\@amps_imag, \@freqs);

=cut

sub fft_weighted {
	my ($amps, $freqs) = @_;

	# initialize return array
	my @mags;

	# figure out how complex the `$amps' array is and iterate over each bin
	# array found
	foreach my $bins (ref $amps->[0] eq 'ARRAY' ? @{$amps} : $amps) {
		push @mags, [
			map {
				$bins->[$_] * $freqs->[$_]
			} 0 .. (sort $#{$bins}, $#{$freqs})[0]
		];
	}

	\@mags
}

=head2 associated_frequencies

Gets [a reference to] the array of frequencies associated with a set of unweighted FFT bins.

	my $num_bins = scalar @amps_real;

	my $freqs = &associated_frequencies($num_bins, $sampling_rate);

=cut

sub associated_frequencies {
	my ($num_bins, $sampling_rate) = @_;

	# generate the hash key in $precalc that will be used for retrieving
	# and/or storing the frequency set for this particular input
	my $precalc_index = "$sampling_rate $num_bins";

	# if precalculated, short-circuit and return it, otherwise calculate,
	# store it in the precalc hash, and return it
	$precalc->{$precalc_index} ||
		($precalc->{$precalc_index} =
	# I can't remember why this works, but it does
	[ map { $sampling_rate * $_ / $num_bins / 2 } 0 .. ($num_bins - 1) ])
}

=head2 fft_all

Calculates all three (unweighted, weighted and associated frequencies) and returns a single hash with three keys, respectively B<'amps'>, B<'mags'> and B<'freqs'>.

Optionally, a third option, B<'mode'>, may be specified. This controls which set of data will be returned. Valid modes include B<'real'>, B<'imag'>, B<'both'> for returning respectively the real, imaginary or both portions of the FFT bin values.

An alternative value for B<'mode'> is B<'dist'> which computes the distance from the origin of the point (REAL, IMAG). This is known as the Euclidian norm of the vector, which is characterized by the following function:
	      __________________
	     /                  ^
	/\  /  (r) ^ 2 + (i) ^ 2
	  \/

where B<r> is the real portion and B<i> is the imaginary portion.

The default value is B<'dist'>. This mode is recommended, as it has been tested to give the same resulting bin value for both phased and non-phased waveforms.

	my $fft_data = &fft_all(
		'samples'	=> \@audio_samples,
		'sampling_rate'	=> $sampling_rate,
		'mode'		=> 'dist', # default
	);

	# parse the different parts
	my ($amps, $mags, $freqs) = @{$fft_data}{qw/ amps mags freqs /};

=cut

sub fft_all {
	my ($samples, $sampling_rate, $mode) =
		@{{@_}}{qw/ samples sampling_rate mode /};

	# use the default mode 'dist' if none was defined
	$mode = MODE unless $mode;

	my $amps = &fft_unweighted($samples, $sampling_rate);

	# get this out of the way
	my $num_bins = @{$amps->[0]};

	# re-defining the original (unweighted) bin values to be unidimensional
	# here will affect the return values of subsequent calls to the other
	# functions

	if ($mode eq 'real') {
		$amps = $amps->[0];
	} elsif ($mode eq 'imag') {
		$amps = $amps->[1];
	} elsif ($mode eq 'dist') {
		# replace $amps with each complex bin's Euclidian norm value
		$amps = [ map {
			sqrt $amps->[0]->[$_] ** 2 + $amps->[1]->[$_] ** 2
		} 0 .. $#{$amps->[0]} ];
	}

	# otherwise, leave the $amps array as it is ('both' mode)

	# find the frequencies associated to this bin set
	my $freqs = &associated_frequencies($num_bins, $sampling_rate);

	# weight the bins
	my $mags = &fft_weighted($amps, $freqs);

	# return a reference to a hash containing all parts
	{
		'amps'	=> $amps,
		'mags'	=> $mags,
		'freqs'	=> $freqs,
	}
}

=head1 NOTES

This module can be used directly, but is meant for use in L<Audicon::Feature>.

These subroutines, when used as part of the Audicon project, will be called with basically the same input arguments as a whole slew of others. This said, most of the calculations have been engineered to occur as far up the call stack as possible. As a result, these subroutines expect to have their data pretty well pre-processed. I apologize for any inconvenience.

=head1 SEE ALSO

L<Audicon>
L<Audicon::Feature>

=head1 AUTHOR

	Part of project Audicon by Dan Church <daniel.church@uwrf.edu>

=cut

1
