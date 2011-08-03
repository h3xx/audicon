#!/usr/bin/perl -w
use strict;
use Audio::Wav;

my $wav = Audio::Wav->new;
my $read = $wav->read($ARGV[0]);
my $details = $read->{'data'};

print "$_ => $details->{$_}\n" foreach sort keys %{$details};
print "length in samples: " . $read->length_samples . "\n";
