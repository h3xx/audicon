package Audicon::Feature::KeyAmplitudes;

use strict;
use warnings;

our $VERSION = '0.02';

use Math::GSL::Matrix	qw/ :all /;
use Math::GSL::BLAS	qw/ :all /;
use Math::GSL::CBLAS	qw/ :all /;

# default values
use constant KEYS		=> [
	261.626, # C
	277.183, # C# / Db
	293.665, # D
	311.127, # D# / Eb
	329.628, # E
	349.228, # F
	369.994, # F# / Gb
	391.995, # G
	415.305, # G# / Ab
	440.000, # A
	466.164, # A# / Bb
	493.883, # B
];
use constant KEYS_FULL		=> 1;

use constant OCTAVE_LOW		=> -3;
use constant OCTAVE_HIGH	=> 4;
use constant NOTE_LOW		=> 0.5;
use constant NOTE_HIGH		=> 0.5;
use constant CURVE_HEIGHT	=> 1;
use constant CURVE_WIDTH	=> 1;
use constant CURVE_EXPONENT	=> 2;

=head1 NAME

Audicon::Feature::KeyAmplitudes - calculates the amplitudes of each key in a span of octaves, as they occur in the Fourier signal deconstruction.

=head1 DESCRIPTION

Because music is based on a fairly standard set of notes,

FIXME

=head1 SYNOPSIS

	use Audicon::Feature::KeyAmplitudes;
	use Audicon::Tools	qw/ fft_unweighted associated_frequencies /;

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

	# the list of Hz values for each note in our base octave. The default
	# value, shown here, is a widely-accepted set representing the middle C
	# octave of a standard 88-key piano, courtesy of Wikipedia (12-10-2006)
	my @base_octave_hz = (
		261.626, # C
		277.183, # C# / Db
		293.665, # D
		311.127, # D# / Eb
		329.628, # E
		349.228, # F
		369.994, # F# / Gb
		391.995, # G
		415.305, # G# / Ab
		440.000, # A
		466.164, # A# / Bb
		493.883, # B
	);

	# whether the octave we're specifying is a full octave; i.e. whether
	# the peripheral notes in the octave are considered to be one `step'
	# away from the most adjacent notes in the adjacent octaves (has an
	# effect on curve generation, specifically in determining curve width)
	my $keys_full = 1;

	# setup our piano to use a set of keys in octaves spanning 3 left
	# through 4 right of the base octave, inclusive (this is the default
	# value)
	my ($octave_low, $octave_high) = (-3, 4);

	# this is used for scaling each note's gaussian normal curve (the
	# `bell' curve) along the x axis. Though the curve is symmetric, these
	# values apply to weighting the Hz-distance between higher and lower
	# adjacent notes, respectively. Long story short, it's a measure of
	# curve falloff as a fraction of the distance to adjacent notes.
	my ($note_low, $note_high) = (0.5, 0.5);

	# provide parameters to the curve-generation function:
	# $y = $height * exp( -abs( ( ( $x - $center ) / $scale ) ^ $exponent / $width ) )
	# note: 'center' and 'scale' are replaced inside the function every time a
	# new curve is generated, so those parameters are ignored.
	# Default values are as shown.
	my $curve_height = 1;
	my $curve_width = 1;
	my $curve_exponent = 2;

	# all of the parameters except `freqs' are optional
	my $keycalc = Audicon::Feature::KeyAmplitudes->new(
		'freqs'		=> $freqs,
		'keys'		=> \@base_octave_hz,
		'keys_full'	=> $keys_full,
		'octave_low'	=> $octave_low,
		'octave_high'	=> $octave_high,
		'note_low'	=> $note_low,
		'note_high'	=> $note_high,
		'curve_height'	=> $curve_height,
		'curve_width'	=> $curve_width,
		'curve_exponent'=> $curve_exponent,
	);

FIXME

	# most of the calculations occur at the first instantiation. subsequent
	# calls should be fairly quick
	my @keyamps = @{$keycalc->key_amplitudes(
		'amps'	=> $amps_real,
	)};

	# ...
	# get a new set of samples in @audio_samples
	# $keycalc assumes same length in samples
	my $next_amps = &fft_unweighted(\@audio_samples);
	my @next_keyamps = @{$keycalc->key_amplitudes(
		'amps'	=> $next_amps,
	)};

=head1 EXPORT

Exports no functions, as this is used as an object.

=head1 SUBROUTINES

=cut

sub new {
	my $class = shift;

	my $self = bless {
		'keys'		=> KEYS,
		'keys_full'	=> KEYS_FULL,
		'octave_low'	=> OCTAVE_LOW,
		'octave_high'	=> OCTAVE_HIGH,
		'note_low'	=> NOTE_LOW,
		'note_high'	=> NOTE_HIGH,
		'curve_height'	=> CURVE_HEIGHT,
		'curve_width'	=> CURVE_WIDTH,
		'curve_exponent'=> CURVE_EXPONENT,
		@_,
	}, $class;

	# perform some initialization (weakens code hardiness, but simplifies
	# it and eliminates redundant checks)

	$self->generate_keyset; # also calls &generate_match_matrix

	$self
}

=head2 key_amplitudes

Returns a list of the amplitudes summed for each key in the octave span. Expects a ref to a list of FFT values.

	my $ka = $key_calc->key_amplitudes(
		'amps'	=> $amps,
	);

Provided you instantiated the module correctly, there is no reason to call any other subroutine than this one.

=cut

sub key_amplitudes {
	my $self = shift,
	my $amps = {@_}->{'amps'};

	# create the amplitudes matrix
	my $amps_m = Math::GSL::Matrix->new(1, scalar @{$amps});
	$amps_m->set_row(0, $amps);

	# create a matrix to hold the results
	# (remember that our keyset's [0] and [-1] indexes contain the two
	# adjacent key frequencies, just below and just above, respectively,
	# the core set of keys we will be testing for; therefore, the size of
	# the matrix will be two less the size of the keyset)
	my $r = Math::GSL::Matrix->new(1, scalar @{$self->{'keyset'}} - 2);

	# multiply the matrices
	&gsl_blas_dgemm($CblasNoTrans, $CblasNoTrans, 1, $amps_m->raw, $self->{'match_matrix'}->raw, 1, $r->raw);

	# get first (and hopefully only) row of result
	my $retval = [ $r->row(0)->as_list ];

	# free up the memory used by the matrices
	&gsl_matrix_free($amps_m->raw);
	&gsl_matrix_free($r->raw);

	$retval
}

=head2 generate_keyset

Generates the internal data structure containing the full octave range of keys from the keys and octave ranges passed in upon instantiation.

Optionally takes arguments to replace said values.

	# re-generate the default keyset
	$keycalc->generate_keyset;

	# change the layout of the keyboard (all arguments are optional)
	$keycalc->generate_keyset(
		'keys'		=> [ $hz_1, $hz_2, ... ],
		'keys_full'	=> 0,
		'octave_low'	=> -2,
		'octave_high'	=> 1,
	);

This function will also re-generate the frequency matching matrix for the new set of keys.

Note: You should never have to call this subroutine, as the instantiation code should take care of this.

=cut

sub generate_keyset {
	my $self = shift;

	# quickly replace any options passed in
	%{$self} = (
		%{$self},
		@_,
	);

	# extract low and high parameters
	my ($low, $high) = sort {$a <=> $b}
		@{$self}{ qw/ octave_low octave_high / };

	$self->{'keyset'} = [];

	foreach my $octave ($low .. $high) {
		push @{$self->{'keyset'}}, map {
			$_ * 2 ** $octave
		} @{$self->{'keys'}};
	}

	# insert peripheral keys for curve generation
	if ($self->{'keys_full'}) {
		# we're using a full octave, so in order to get the peripheral
		# keys, merely multiply or divide by two

		# first, the highest note of the octave before the lowest
		unshift @{$self->{'keyset'}},
			$self->{'keys'}->[-1] * 2 ** ($low - 1);
		# second, the lowest note of the octave above the highest
		push @{$self->{'keyset'}},
			$self->{'keys'}->[0] * 2 ** ($high + 1);
	} else {
		# we're not using a full octave, so get the peripheral keys by
		# way of distance between keys
		unshift @{$self->{'keyset'}},
			$self->{'keyset'}->[0] - abs $self->{'keyset'}->[1] -
			$self->{'keyset'}->[0];
		# second, the lowest note of the octave above the highest
		push @{$self->{'keyset'}},
			$self->{'keyset'}->[-1] + abs $self->{'keyset'}->[-1] -
			$self->{'keyset'}->[-2];
	}

	# since the keyset has changed, the match matrix should change as well
	unless ($self->{'freqs'}) {
		warn 'Unable to re-generate match matrix from new set of keys. Frequency list not found';
	} else {
		$self->generate_match_matrix;
	}
}

=head2 generate_match_matrix

Generates the internal data structure containing the matrix of gaussian normal curves whereby the dot product of a matrix containing the unweighted FFT bin values of the audio sample, and the proscribed matrix will produce a row-matrix of the summed key matches.

The match matrix should have (C<@{$freqs}>) columns and (C<@{$keyset}>) rows.

Optionally takes arguments to replace said values.

	# generate the match matrix from stored values
	$keycalc->generate_match_matrix;

	# generate from replaced values (note: 'keyset' != 'keys')
	$keycalc->generate_match_matrix(
		'keyset'	=> [ $hz1_octave1, $hz2_octave1, ... ],
		'freqs'		=> [ $bin1_freq, $bin2_freq, ... ],
		'note_low'	=> 0.8,
		'note_high'	=> 0.2,
	);

When generating the curves (see L</gauss_norm>) for each note, the curve scaling parameter is determined by averaging the distances between adjacent notes after multiplying them by C<'note_low'> and C<'note_high'>, respectively. The outcome is a symmetric curve.

Note: You should never have to call this subroutine, as the instantiation code should take care of this.

=cut

sub generate_match_matrix {
	my $self = shift;

	%{$self} = (
		%{$self},
		@_,
	);

	unless ($self->{'freqs'}) {
		warn 'Unable to generate match matrix. Please set internal parameter "freqs" before continuing';
	} else {

		# hidden progress meter code
		$self->{'meter'}->update_meter(
			'name'	=> $self->{'meter_name'},
			'val'	=> 0,
			'max'	=> @{$self->{'keyset'}} - 2,
		) if $self->{'meter'} && $self->{'meter_name'};

		$self->{'match_matrix'} = Math::GSL::Matrix->new(
			# rows
			scalar @{$self->{'freqs'}},
			# cols
			scalar @{$self->{'keyset'}} - 2
		);

		# note: this span cuts out the keys at the beginning and the
		# end (this is intentional -- see &generate_keyset)
		foreach my $keynum (1 .. ($#{$self->{'keyset'}} - 1)) {
			# hidden progress meter code
			$self->{'meter'}->update_meter(
				'name'	=> $self->{'meter_name'},
				'val'	=> $keynum,
			) if $self->{'meter'} && $self->{'meter_name'};

			$self->{'match_matrix'}->set_col($keynum - 1,

# calculate needed curve generation parameters
$self->gauss_norm(
	# center is at the current note
	$self->{'keyset'}->[$keynum],
	# scale based on curve scaling parameters
	(
# left span = difference between this and the previous note
($self->{'keyset'}->[$keynum] - $self->{'keyset'}->[$keynum - 1]) * $self->{'note_low'} +
# right span = difference between this and the next note
($self->{'keyset'}->[$keynum + 1] - $self->{'keyset'}->[$keynum]) * $self->{'note_high'}
	# average (/2) and divide by norm (/2) = (/4)
	) / 4
)
			);
		}
	}
}

=head2 gauss_norm

	my $curve_values = $ka->gauss_norm($curve_center, $curve_scale);

Generates the author's take on a bell curve with the following characteristic function:

	$y = $he * exp( -abs( ( ( $x - $cn ) / $sc ) ^ $xp / $wd ) )

Because I don't know or care how close this is to the actual Gaussian normal function, I'll recommend that it not be used outside of this module.

Some notes about this particular bell curve:

=over

* for all values of $xp, $wd, $cn, $sc, and $he,  will contain the points { ($cn - $sc, $he / e ^ (1 / $wd)), ($cn + $sc, $he / e ^ (1 / $wd)) }. (e, here, is that mathematical constant 2.71828...)

* try graphing it for a bunch of random values of `$xp'; you'll see what I mean -- they all meet at the same two points.

=back

This code was originally written in Scilab, but has been modified for simplicity and use in L</generate_match_matrix>. It depends on the internal parameters C<'curve_height'>, C<'curve_exponent'>, C<'curve_width'> and the list of frequencies, C<'freqs'>.


=cut

sub gauss_norm {
	my ($self, $curve_center, $curve_scale) = @_;

	[ map {
		$self->{'curve_height'} *
		exp -abs (($_ - $curve_center) / $curve_scale) **
			$self->{'curve_exponent'} /
		$self->{'curve_width'}
	} @{$self->{'freqs'}} ]
}

# Tasks: free up the memory used by the match matrix
sub DESTROY {
	my $self = shift;
	&gsl_matrix_free($self->{'match_matrix'}->raw)
		if $self and $self->{'match_matrix'};
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
