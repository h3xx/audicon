#!/usr/bin/perl -w
use strict;

use Audio::Wav;
my $wav = Audio::Wav->new;
my $self = {
	'reader'	=> $wav->read($ARGV[0]),
	'norm_buffsize'	=> 0x100_00,
};

sub _read_mono_norm {
	my $self = shift;
	my $from = shift;
	my $length = shift;

	my $num_samples = $self->{'reader'}->length_samples;

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

sub _probe_norm_coeff {
	my $self = shift;

	# $self->_probe_reader;

	unless (defined $self->{'norm_coeff'}) {

		# just so &_read_mono_norm isn't trying to multiply an undef
		$self->{'norm_coeff'} = 1;

		my ($localmax, $samples_read, $num_samples) = (0, 0,
			$self->{'reader'}->length_samples);

		while ($samples_read < $num_samples) {
			my $sample_buff = &_read_mono_norm($self, $samples_read,
				$self->{'norm_buffsize'} <
				($num_samples - $samples_read) ?
				$self->{'norm_buffsize'} :
				($num_samples - $samples_read));

			foreach my $sample (@{$sample_buff}) {
				if ($localmax < abs $sample) {
					$localmax = abs $sample;
					print STDERR "found max of $localmax\n";
				}
			}

			$samples_read += @{$sample_buff};
		}

		$self->{'norm_coeff'} = 1 / $localmax
	}
}

&_probe_norm_coeff($self);
print "normalization coefficient: $self->{'norm_coeff'}\n";
