#!/usr/bin/perl -w
use strict;

my $code_lines = 0;
my $doc_lines = 0;
my $comment_lines = 0;
my $total_lines = 0;

while (<>) {
	unless (/^\s*$/) { # ignore blank lines
		if (m#^//#) {
			++$doc_lines;
		} else {
			if (m#^\s+//#) { # just a comment line
				++$comment_lines;
			} else {
				if (m#//#) { # any commenting at all
					++$comment_lines;
				}
				++$code_lines;
			}
		}
		++$total_lines;
	}
}

print "code: $code_lines\ndoc: $doc_lines\ncomment: $comment_lines\ntotal: $total_lines\n";
