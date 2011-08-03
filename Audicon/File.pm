package Audicon::File;

use strict;
use warnings;

our $VERSION = '0.03';

# default values
use constant CLIP_SIZE		=> 0.5;
use constant CLIP_STEP		=> 0.5;
use constant TEX_SPAN_L		=> 1;
use constant TEX_SPAN_R		=> 1;

# explanation: find that normalization takes too long and is generally
# unnecessary; plus, it can have the nasty effect of creating samples whose
# value isn't quite accurate
use constant NORMALIZE		=> 0;		# normalize input?
use constant NORM_BUFFSIZE	=> 0x100_00;	# sixty-four kilo-samples

# this is very important - EVERYTHING ABOUT THE PROGRAM CHANGES IF THIS IS
# ALTERED FROM 'dist'
use constant FFT_MODE		=> 'dist';

use Audio::Wav;
use Audicon::Tools	qw/ fft_all /;

=head1 NAME

Audicon::File - aids in the reading and dividing of WAV files.

=head1 DESCRIPTION

When processing audio data using L<Audicon>, it becomes necessary to break it up into smaller sections that relate to one another in very specific ways. This module facilitates that process by attaching to a file and reading it chunk by chunk.

Audio data is broken down in the following ways:

=over

=item Clip Samples

The clip of audio data to which all subsequent calculations pertain.

=item Texture Samples

The larger section of audio data inside of which the current clip of audio appears.

=back

Because clips of audio data are also passed through functions that require data relevant to the adjacent audio clips, the audio buffering system is broken down into three parts named B<prev>, B<curr> and B<next>, pertaining to the previous, current and subsequent sets of clip/textrue audio data.

See L</advance_buffers> for the format of the hash of audio sample buffers.

=head2 Normalization

Because L<Audicon> is designed to process arbitrary audio data, there is also a process of normalizing (i.e. applying a calculation on the value of each sample so that the maximum peak is at exactly 1) that is done on all audio data that is read.

Steps have been taken in order to minimize the memory consumption of this process by using buffering techniques.

=head1 SYNOPSIS

	use Audicon::File;

	# (all values shown here are default)

	# what size audio clips should be (in seconds)
	my $clip_size = 0.5;

	# how far between the starts of adjacent clips (in seconds)
	my $clip_step = 0.5;

	# how far (`left' and `right') should texture frame data be counted
	# from and to, respectively (in seconds)
	my ($tex_span_l, $tex_span_r) = (1, 1);

	# whether or not the audio data should be normalized when it is read in
	my $normalize = 0;

	# how big a slice of audio data should be taken at a time when figuring
	# out the normalization coefficient (in samples)
	# note: this can greatly affect initialization performance
	my $norm_buffsize = 0x100_00;

	# where to read audio from
	my $wavfile = 'foo.wav';

	# set the fft bins returned
	# 'real' => real portion
	# 'imag' => imaginary portion
	# 'both' => both in a multimensional array
	# 'dist' => distance of the point (real, imag) from the origin
	#	(sqrt(r^2+i^2)); also known as the Euclidian norm
	my $fft_mode = 'dist';

	# initialize file reader (all of these except 'file' are optional)
	my $file = Audicon::File->new(
		'clip_size'	=> $clip_size,
		'clip_step'	=> $clip_step,
		'tex_span_l'	=> $tex_span_l,
		'tex_span_r'	=> $tex_span_r,
		'normalize'	=> $normalize,
		'norm_buffsize'	=> $norm_buffsize,
		'file'		=> $wavfile,
		'fft_mode'	=> $fft_mode,
	);

	# loop until the end of the wav file is reached
	until ($file->reached_end) {
		# advance the buffer positions
		my $buffers = $file->advance_buffers;

		# ... (do something)
	}

=head1 SUBROUTINES

=cut

sub new {
	my $class = shift;

	my $self = bless {
		'clip_size'	=> CLIP_SIZE,
		'clip_step'	=> CLIP_STEP,
		'tex_span_l'	=> TEX_SPAN_L,
		'tex_span_r'	=> TEX_SPAN_R,
		'normalize'	=> NORMALIZE,
		'norm_buffsize'	=> NORM_BUFFSIZE,
		'fft_mode'	=> FFT_MODE,
		@_,
	}, $class;

	# check to see if the instantiation will work
	die __PACKAGE__ . "->new: unable to read file `$self->{'file'}'"
		unless defined $self->{'file'}
			and -f -r $self->{'file'};

	# perform some initialization (weakens code hardiness, but simplifies
	# it and eliminates redundant checks)

	# initialize WAV reader
	my $wav = Audio::Wav->new;
	$self->{'reader'} = $wav->read($self->{'file'});

	# figure out sampling rate
	$self->{'sampling_rate'} = $self->{'reader'}->{'data'}->{'sample_rate'};

	# calculate the normalization coefficient, if necessary
	if ($self->{'normalize'}) {
		$self->calc_norm_coeff;
	} else {
		$self->{'norm_coeff'} = 1 /
			(2 ** $self->{'reader'}->{'data'}->{'bits_sample'}) /
			$self->{'reader'}->{'data'}->{'channels'};
	}

	$self
}

=head2 calc_norm_coeff

Forces (re)calculation of the normalization coefficient.

	$file->calc_norm_coeff;

=cut

sub calc_norm_coeff {
	my $self = shift;

	my ($localmax, $samples_read, $num_samples) = (0, 0,
		$self->{'reader'}->length_samples);

	# reset the normalization coefficient to not do anything
	$self->{'norm_coeff'} = 1;

	# loop until we reach the end of the file
	while ($samples_read < $num_samples) {

		# read in the next sample buffer
		# (note: here, $samples_read is equal to the sample
		# index just after the last sample we read last time
		# around)
		my $sample_buffer = $self->_read_mono_norm($samples_read,
			# here, read either a full buffer-load or to the end of
			# the file
			(sort {$a <=> $b} $self->{'norm_buffsize'},
				$num_samples - $samples_read)[0]);

		# XXX : now, before you even think about replacing this method
		# of finding the maximum sample value with a sliced-sort
		# algorithm, STOP! -- this has been tested to be about twice as
		# fast

		# check each sample in the buffer we just read against our
		# local maximum sample value
		foreach my $sample (@{$sample_buffer}) {
			$localmax = abs $sample
				if $localmax < abs $sample
		}

		# increment our position
		$samples_read += @{$sample_buffer};
	}

	# set this object's normalization coefficient (making sure
	# we're not dividing by zero)
	$self->{'norm_coeff'} = 1 / $localmax if $localmax;
}

=head2 advance_buffers

Advances the positions of the buffers holding the audio sample data according to the settings, given upon instantiation, determining the size and spacing of the audio buffers.

	my $buffer_set = $file->advance_buffers;

Returns a multi-dimensional hash reference with the following format:

	{
		'prev'	=> {
			'pos'	=> byte offset from beginning of file,
			'clip'	=> [ ...clip sample values... ],
			'tex'	=> [ .....texture frame sample values..... ],
			'amps'	=> [ unweighted fft bins for 'clip' ],
			'mags'	=> [ weighted fft bins for 'clip' ],
			't_amps'=> [ unweighted fft bins for 'tex' ],
			't_mags'=> [ weighted fft bins for 'tex' ],
		},
		'curr'	=> {
			'pos'	=> byte offset from beginning of file,
			'clip'	=> [ ...clip sample values... ],
			'tex'	=> [ .....texture frame sample values..... ],
			'amps'	=> [ unweighted fft bins for 'clip' ],
			'mags'	=> [ weighted fft bins for 'clip' ],
			't_amps'=> [ unweighted fft bins for 'tex' ],
			't_mags'=> [ weighted fft bins for 'tex' ],
		},
		'next'	=> {
			'pos'	=> byte offset from beginning of file,
			'clip'	=> [ ...clip sample values... ],
			'tex'	=> [ .....texture frame sample values..... ],
			'amps'	=> [ unweighted fft bins for 'clip' ],
			'mags'	=> [ weighted fft bins for 'clip' ],
			't_amps'=> [ unweighted fft bins for 'tex' ],
			't_mags'=> [ weighted fft bins for 'tex' ],
		},
	}

=cut

sub advance_buffers {
	my $self = shift;

	# perform some minor pre-calculations
	my $clip_step_samples = $self->{'clip_step'} *
		$self->{'sampling_rate'};

	unless (defined $self->{'clip_buffs'}) {
		# retrieving the first set of buffers

		# this will hold our buffers for the moment
		my $buffer = {};

		# since the 'curr' buffer is starting at the beginning of the
		# file, the 'prev' buffer should begin one step before it
		@{$buffer}{ qw/ prev curr next / } = (
			$self->_read_buffers(
				-$clip_step_samples,
				0,
				$clip_step_samples
			)
		);

		# calculate weighted and unweighted FFT bins for each part of
		# the buffer

		# set the completed buffer collection as the new internal data
		# object
		$self->{'clip_buffs'} = $buffer;

	} else {
		# there are already buffers read

		# calculate where the next read is going to take place
		my $next_pos = $self->{'clip_buffs'}->{'next'}->{'pos'} +
			$clip_step_samples;

		# `roll' the pointers and read in the 'next' buffer
		@{$self->{'clip_buffs'}}{qw/ prev curr next /} = (
			@{$self->{'clip_buffs'}}{qw/ curr next /},

			$self->_read_buffers($next_pos)
		);
	}

	# return the set of buffers
	$self->{'clip_buffs'}
}

=head2 skip

Skips a buffer-reading or buffer-readings. Optional argument is the number of buffers to skip.

	$file->skip; # skip one

	$file->skip($num_buffers); # skip multiple

=cut

sub skip {
	my $self = shift;

	my $skip = int shift;
	$skip = 1 unless defined $skip;

	# perform some minor pre-calculations
	my $clip_step_samples = $self->{'clip_step'} *
		$self->{'sampling_rate'};

	# save time if we already have one of the buffers read
	if ($skip == 1) {
		# put the position at two buffers from now (i.e. 'next' gets
		# moved to 'prev' and 'curr' and 'next' are read in)
		my $curr_begin = $self->{'clip_buffs'}->{'next'}->{'pos'} + $clip_step_samples;

		@{$self->{'clip_buffs'}}{qw/ prev curr next /} = (
			$self->{'clip_buffs'}->{'next'},
			$self->_read_buffers(
				$curr_begin,
				$curr_begin + $clip_step_samples,
			)
		);
	} else {
		# moving to something we haven't read before
		my $prev_begin = $self->{'clip_buffs'}->{'prev'}->{'pos'} + $clip_step_samples * ($skip + 1);

		@{$self->{'clip_buffs'}}{qw/ prev curr next /} = (
			$self->_read_buffers(
				$prev_begin,
				$prev_begin + $clip_step_samples,
				$prev_begin + $clip_step_samples * 2,
			)
		);
	}
}

=head2 reached_end

Retruns true if the buffer designated B<'curr'> spans across the end of the file. This is especially useful when reading a file in a for or while loop.

While it is still possible to continue reading audio data past the end of the file, this subroutine gives a good indication of when to stop.

	until ($file->reached_end) {
		my $buffers = $file->advance_buffers;

		# ...
	}

=cut

sub reached_end {
	my $self = shift;

	# if 'clip_buffs' isn't defined, we haven't started reading yet, so
	# there's no way we could have reached the end
	(defined $self->{'clip_buffs'}) &&

	# comparison returns boolean
	($self->{'clip_buffs'}->{'curr'}->{'pos'} +
		$self->{'sampling_rate'} *
		$self->{'clip_size'} >=
		$self->{'reader'}->length_samples)
}

=head2 move_to

Causes the audio buffers to move to a specific sample offset, relative to the beginning of the wav file. The position specifies where the 'curr' clip begins. When no offset is given, it positions the buffers at the beginning of the file.

If a negative offset is given, it is taken to mean the number of samples before the end of the file.

	# position at sample offset 30 (sample #29)
	my $buffers = $file->move_to(30);

	# position at beginning of file (first sample)
	my $buffers = $file->move_to;

=cut

sub move_to {
	my ($self, $pos) = @_;

	# substitute 0 for undef
	$pos ||= 0;

	my $clip_step_samples = $self->{'clip_step'} *
		$self->{'sampling_rate'};

	(@{$self->{'clip_buffs'}}{qw/ prev curr next /}) = (
		$self->_read_buffers(
			$pos - $clip_step_samples,
			$pos,
			$clip_step_samples
		)
	);

	$self->{'clip_buffs'}
}

=head2 move_to_second

Does the same thing as L</move_to>, except in terms of time (seconds).

	# position at the beginning of second offset 20
	# (sample index of one sample before 00:20)
	$feature->move_to_second(20);

=cut

sub move_to_second {
	my ($self, $pos) = @_;

	# substitute 0 for undef
	$pos ||= 0;

	$self->move_to($pos * $self->{'sampling_rate'})
}

################################################################################
# reads one or more audio buffer from the file, given their sample offsets

sub _read_buffers {
	my $self = shift;

	# perform some minor pre-calculations
	my ($clip_size_samples, $tex_span_l_samples, $tex_span_r_samples) = 
		($self->{'clip_size'} * $self->{'sampling_rate'},
		$self->{'tex_span_l'} * $self->{'sampling_rate'},
		$self->{'tex_span_r'} * $self->{'sampling_rate'});

	# initialize the return buffer
	my @buffers;

	foreach my $pos (@_) {

		# initialize temporary object for use in return buffer
		my $buffer;

		# read the clip buffer and the [wrapped] start position
		@{$buffer}{qw/ clip pos /} = $self->_read_mono_norm($pos,
			$clip_size_samples);

		# construct the texture buffer by concatenating its left and
		# right portions (before and after the clip buffer)
		$buffer->{'tex'} = [
			@{$self->_read_mono_norm($pos - $tex_span_l_samples,
				$tex_span_l_samples)},

			@{$buffer->{'clip'}},

			@{$self->_read_mono_norm($pos + $clip_size_samples,
				$tex_span_r_samples)}
		];

		# calculate the weighted and unweighted Fourier transforms for
		# the clip and texture buffers, respectively

		@{$buffer}{qw/ amps mags freqs t_amps t_mags t_freqs /} = (
			# clip
			@{&fft_all(
				'samples' => $buffer->{'clip'},
				'sampling_rate'	=> $self->{'sampling_rate'},
				'mode'	=> $self->{'fft_mode'},
			)}{qw/ amps mags freqs /},

			# and tex
			@{&fft_all(
				'samples' => $buffer->{'tex'},
				'sampling_rate'	=> $self->{'sampling_rate'},
				'mode'	=> $self->{'fft_mode'},
			)}{qw/ amps mags freqs /}
		);

		push @buffers, $buffer
	}

	@buffers
}

# reads a bunch of samples, merges the channels, normalizes and returns an
# array ref to the floating-point samples
#
# * $reader->read() isn't doing what I expected; it's returning large
# (two-byte) ints! This doesn't matter, as long as $self->{'norm_coeff'} is
# right.

sub _read_mono_norm {
	my ($self, $start_pos, $length) = @_;

	# figure out the number of samples in the file
	my $num_samples = $self->{'reader'}->length_samples;

	# wrap the starting position to fall within data bounds (weird but works)
	$start_pos = ($start_pos % $num_samples + $num_samples) % $num_samples;

	# specifying $length = -1 means read to the end of the file
	# (you probably don't ever want to do this, but why the hell not
	# support it)
	$length = $num_samples if $length == -1;

	# initialize the sample buffer
	my @sample_buffer;

	# seek to the position at which the reading will start
	$self->{'reader'}->move_to_sample($start_pos);

	# fill samples until we complete the length requirement
	while (@sample_buffer < $length) {
		# read all unpacked parallel channels and increment the
		# reader's internal position (returns empty array if we've hit
		# the end of the file)
		my @chans = $self->{'reader'}->read;

		# wrap around to the beginning (first sample) if the reader has
		# reached the end of the file
		unless (@chans) {
			$self->{'reader'}->move_to_sample(0);
			@chans = $self->{'reader'}->read;
		}

		# sum the channels' values
		my $sample = 0;
		$sample += $_ foreach @chans;

		# add this sample to the sample buffer, after dividing by the
		# number of channels (effectively averaging the channels) and
		# multiplying by our pre-calculated normalization coefficient
		push @sample_buffer, $sample * $self->{'norm_coeff'};
	}

	wantarray ? (\@sample_buffer, $start_pos) : \@sample_buffer;
}

=head1 NOTES

This module can be used directly, but is meant for use in L<Audicon::Feature>.

=head1 AUTHOR

Dan Church S<E<lt>amphetamachine@gmail.comE<gt>>

=head1 SEE ALSO

=over

=item L<Audio::Wav>

=item L<Audicon>

=item L<Audicon::Tools>

=item L<Audicon::Feature>

=back

=head1 COPYRIGHT

Copyright 2008 Dan Church.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the LICENSE file included with this module.

=cut

1
