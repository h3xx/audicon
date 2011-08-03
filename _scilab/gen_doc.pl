#!/usr/bin/perl -w
use strict;

# generate basic documentation for a given Scilab file

use File::Basename qw/ dirname basename /;

my $basedir = "$ENV{HOME}/audicon";
my $docdir = "$basedir/doc";
my $docext = '.txt';

mkdir $docdir unless -d $docdir;

foreach my $scifile (@ARGV) {
	open SCIFILE, "<$scifile" or open SCIFILE, "<$basedir/$scifile"
		or die "cannot open file `$scifile'";

	# determine package name
	(my $package = dirname($scifile)) =~ s#^$basedir/##;
	my $docname = 0;

	mkdir "$docdir/$package" unless -d "$docdir/$package";

	foreach (<SCIFILE>) {
		if (/^\s*function\s*(\[.*\]=)?(.*)\(/) {
			$docname = "$docdir/$package/$2$docext";
			unlink $docname if -f $docname;
		} elsif ($docname) {
			if(m#^\s*//!#) {
				# done documenting this function
				$docname = 0;
			} elsif (m#^\s*// ?(.*)$#) {
				# a line of documentation
				open DOC, ">>$docname";
				print DOC "$1\n";
			}
		}
	}
}

