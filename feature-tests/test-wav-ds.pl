#!/usr/bin/perl -w
use strict;

use Audio::Wav;

my $wav = Audio::Wav->new;
my $read = $wav->read(@ARGV[0]);

#printf STDERR "%s\t=> %s\n" foreach keys %{$read};

print STDERR "pos: $read->{'pos'}\n";

my @fs = $read->read;

print STDERR "pos: $read->{'pos'}\n";

print STDERR "first samples: (@fs)\n";


