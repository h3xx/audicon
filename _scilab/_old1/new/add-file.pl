#!/usr/bin/perl -w
use strict;

use Audio::Wav;

use constant SECONDS_PER_ENTRY => 0.5;

foreach my $filename (@ARGV) {

	open SQLITE, '|sqlite3 samples.db';

	my $wav = new Audio::Wav;
	my $wavdata = $wav -> read ($filename);

	print "adding wav file `$filename' to database\n";
	print "sample rate: ".($wavdata -> sample_rate ())."\n";

	

	my $samples_per_entry = $wavdata -> sample_rate () * SECONDS_PER_ENTRY;
	print "adding clips of $samples_per_entry samples (".SECONDS_PER_ENTRY." seconds)\n";


}
