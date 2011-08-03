package Audicon::Feature;

use strict;
use warnings;

our $VERSION = '0.02';

use Audicon::Tools			qw/ fft_all associated_frequencies /;
use Audicon::Feature::CentroidFreq	qw/ centroid_frequency /;
use Audicon::Feature::MagnitudeRatio	qw/ magnitude_ratio /;
use Audicon::Feature::SpectralFlux	qw/ spectral_flux /;
use Audicon::Feature::SpectralRolloff	qw/ spectral_rolloff /;
use Audicon::Feature::ZeroCrossings	qw/ zero_crossings /;
use Audicon::Feature::KeyAmplitudes	qw//;

our $precalc = {};

=head1 NAME

Audicon::Feature - Aids in the extraction of audio `feature' information.

=head1 DESCRIPTION

This module is a layer of abstraction between the end user and the L<Audicon::File> and L<Audicon::Feature::*> libraries. Its purpose is to simplify the calculation and extraction of the features in audio data.

=head1 SYNOPSIS

	use Audicon::File;

	# see Audicon::File for more information
	my $file = Audicon::File->new(
		'file'	=> '/path/to/file.wav',
	);

	my $feature = Audicon::Feaure->new(
		'file'	=> $file,
	);

	# loop until the end of the wav file is reached
	until ($feature->reached_end) {
		# calculate the current featureset and advance the position
		# inside the file
		my $featureset = $feature->calc_featureset;

		# ... (do something)
	}


=head1 SUBROUTINES

=cut

sub new {
	my $class = shift;

	my $self = bless {
		'file'		=> undef,
		@_,
	}, $class;

	# create the key amplitude calculator
	unless (exists $self->{'keycalc'}) {
		my ($sampling_rate, $clip_size) =
			@{$self->{'file'}}{qw/ sampling_rate clip_size /};

		my $precalc_idx = "$sampling_rate $clip_size";

		# if precalculated use it, otherwise calculate, set and use it
		$self->{'keycalc'} = $precalc->{$precalc_idx} ||
			Audicon::Feature::KeyAmplitudes->new(
			'freqs'	=> &associated_frequencies(
				$sampling_rate * $clip_size / 2 + 1,
				$sampling_rate));
	}

	$self
}

=head2 calc_featureset

Performs feature calculation on the current set of audio/fft data buffers, and then automatically advances the position in the file.

Returns a hash reference with the computed values:

	{
		'centroid'	=> scalar
		'magratio'	=> scalar
		'flux'		=> scalar
		'rolloff'	=> scalar
		'zerocrossings'	=> scalar
		'keyamps'	=> reference to array of scalars
	}

=cut

sub calc_featureset {
	my $self = shift;

	my ($as_array) = @{{@_}}{qw/ as_array /};

	# keep our data against the changing of the buffers
	my ($prev, $curr, $next) =
		(@{$self->{'file'}->advance_buffers}{qw/ prev curr next /});

	# hidden progress meter code
	$self->{'meter'}->update_meter(
		'name'	=> $self->{'meter_name'},
		'val'	=> $curr->{'pos'} / $self->{'file'}->{'sampling_rate'} / $self->{'file'}->{'clip_size'},
		'max'	=> int $self->{'file'}->{'reader'}->{'data'}->{'length'} / $self->{'file'}->{'clip_size'},
	) if $self->{'meter'} && $self->{'meter_name'};

	# prepare argument buffer
	my %args = (
		'sampling_rate'	=> $self->{'file'}->{'sampling_rate'},
	);

	@args{qw/ samples_p t_samples_p amps_p mags_p t_amps_p t_mags_p /} =
		@{$prev}{qw/ clip tex amps mags t_amps t_mags /};

	@args{qw/ samples t_samples amps mags t_amps t_mags /} =
		@{$curr}{qw/ clip tex amps mags t_amps t_mags /};

	@args{qw/ samples_n t_samples_n amps_n mags_n t_amps_n t_mags_n /} =
		@{$next}{qw/ clip tex amps mags t_amps t_mags /};

	# return a hash (or array) of the calculations
	$as_array ? [
		&centroid_frequency(%args),
		&magnitude_ratio(%args),
		&spectral_flux(%args),
		&spectral_rolloff(%args),
		&zero_crossings(%args),
		@{$self->{'keycalc'}->key_amplitudes(%args)} ] :
	{
		'centroid'	=> &centroid_frequency(%args),
		'magratio'	=> &magnitude_ratio(%args),
		'flux'		=> &spectral_flux(%args),
		'rolloff'	=> &spectral_rolloff(%args),
		'zerocrossings'	=> &zero_crossings(%args),
		'keyamps'	=> $self->{'keycalc'}->key_amplitudes(%args),
	}
}

=head2 calc_all_featuresets

Calculates all the featuresets in the file. FIXME

=cut

sub calc_all_featuresets {
	my $self = shift;
	my ($as_array, $norm_coeffs) = @{{@_}}{qw/ as_array norm_coeffs /};

	# initialize the collection of uncollated feature data
	my @feature_data;

	# cycle until we reach the end of the file
	until ($self->reached_end) {
		# grab the current featureset
		my $featureset_part = $self->calc_featureset(
			'as_array'	=> $as_array,
		);

		# normalize if wanted
		if ($norm_coeffs) {
			$featureset_part->[$_] *= $norm_coeffs->[$_]
				foreach 0 .. $#{$norm_coeffs}
		}

		# push the featureset into the collation array
		push @feature_data, $featureset_part;
	}

	# temporarily extend array for collating indices
	push @feature_data, $feature_data[0];

	# connect previous and last sets of feature data
	my @featuresets = map {
		# if they're arrays, concatenate them, else just use hash refs
		$as_array ?
			[ @{$feature_data[$_ - 1]}, @{$feature_data[$_]}, @{$feature_data[$_ + 1]} ] :
			[ @feature_data[$_ - 1, $_, $_ + 1] ]
	} 0 .. ($#feature_data - 1);

	wantarray ? @featuresets : \@featuresets
}

=head2 reached_end

Retruns true if the L<Audicon::File> object we're reading audio data from file has reached the end of the file. This is especially useful when calculating audio feaures in a for or while loop.

	until ($feature->reached_end) {
		my $featureset = $feature->calc_featureset;

		# do something with the calculations
	}

=cut

sub reached_end {
	my $self = shift;

	# just go with whatever the file object reports
	$self->{'file'}->reached_end
}

=head1 NOTES

This module can be used directly, but is meant for use in L<Audicon>.

=head1 AUTHOR

Dan Church S<E<lt>amphetamachine@gmail.comE<gt>>

=head1 SEE ALSO

=over

=item L<Audicon::File>

=item L<Audicon::Tools>

=item L<Audicon::Feature::CentroidFreq>

=item L<Audicon::Feature::MagnitudeRatio>

=item L<Audicon::Feature::SpectralFlux>

=item L<Audicon::Feature::SpectralRolloff>

=item L<Audicon::Feature::ZeroCrossings>

=item L<Audicon::Feature::KeyAmplitudes>

=back

=head1 COPYRIGHT

Copyright 2008 Dan Church.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the LICENSE file included with this module.

=cut

1
