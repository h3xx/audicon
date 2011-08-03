package Audicon::Feature::ZeroCrossings;

use strict;
use warnings;

our $VERSION = '0.01';

require Exporter;

our @ISA = qw/ Exporter /;

our %EXPORT_TAGS = ( 'all' => [ qw/
	zero_crossings
/ ] );

our @EXPORT_OK = qw//;
our @EXPORT = ( @{ $EXPORT_TAGS{'all'} } );

=head1 NAME

Audicon::Feature::ZeroCrossings - calculates the number of zero crossings per second of a given signal.

=head1 DESCRIPTION

Finds the rate at which a signal crosses the zero axis per second.

A zero crossing is defined as when a signal crosses its zero axis (neutral pressure) and is an effective measure of the amount of noise in the signal. It is characterized by the following function:

    N
   ---
   \
    \  | sign(x[n]) - sign(x[n-1]) |
    /
   /
   ---
    n
 --------------------------------------
                  2 * H

where B<x[n]> is the value of the sample at index B<n>, B<N> is the total number of samples in the signal, B<H> is the number of samples per second of signal (the I<sampling rate>), and B<sign()> is a pseudo-function such that C<sign(x) = x / |x|>.

=head1 SYNOPSIS

	use Audicon::Feature::ZeroCrossings	qw/ zero_crossings /;

	# people don't usually type their own audio data,
	# but this is just an example
	my @audio_samples = (....);

	# 44.1 kHz (standard CD audio)
	my $sampling_rate = 44_100;

	my $zerocrossings = &zero_crossings(
		'samples'	=> \@audio_samples,
		'sampling_rate'	=> $sampling_rate,
	);

=head1 EXPORT

Exports the function L</zero_crossings>.

=head1 SUBROUTINES

=head2 zero_crossings

Returns the number of times per second the given set of samples crossed the zero axis.

	my $zerocrossings = &zero_crossings(
		'samples'	=> \@audio_samples,
		'sampling_rate'	=> $sampling_rate,
	);

=cut

sub zero_crossings {
	my ($samples, $sampling_rate) = @{{@_}}{qw/ samples sampling_rate /};

	my $z = 0;

	foreach (1 .. $#{$samples}) {
		# old code
		#++$z if $samples->[$_] > 0 && $samples->[$_ - 1] < 0 ||
		#	$samples->[$_] < 0 && $samples->[$_ - 1] < 0

		# new method (only [+] * [-] yields negative)
		++$z if $samples->[$_] * $samples->[$_ - 1] < 0
	}

	$z / @{$samples} * $sampling_rate
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
