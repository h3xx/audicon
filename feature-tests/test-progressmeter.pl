#!/usr/bin/perl -w
use strict;

use Audicon::Progressmeter;

my $pm = Audicon::Progressmeter->new(
	'meters'	=> [
		[ 0, 40, 'one' ],
		[ 0, 50, 'two' ],
	],
);

$pm->draw;

foreach my $prog (0 .. 50) {
	$pm->update_meter('index' => 0, 'val' => $prog) if $prog <= 40;
	$pm->update_meter('index' => 1, 'val' => $prog) if $prog <= 50;

	sleep 1;
	$pm->redraw;
}
