package Audicon::Progressmeter;

use strict;
use warnings;

use threads::shared;

our $VERSION = '0.2';

use constant WIDTH	=> 37;
use constant LABELS	=> 1;
use constant REDRAW	=> 0;

=head1 NAME

Audicon::Progressmeter - Provides an easy-to-use and text-based progress meter based on the L<wget> meter style.

=head1 DESCRIPTION

This simple module is meant to provide a quick and easy solution to the problem of improving end-user cognisance of what programs are doing and give a better estimation of when they will complete their task. This module can draw (and redraw) as many progress meters as one desires, barring limited screen space.

For example, setting up three meters of quantities 33/100, 45/60 and 929/929, labelled, respectively "foo," "bar," and "baz," then calling the C<draw> subroutine would produce the following on STDERR:

	foo: 33% [===========>                         ] 33/100
	bar: 75% [==========================>          ] 45/60
	baz: 100%[====================================>] 929/929

Then changing the value of the first meter to 70 and re-drawing the meter display using the C<redraw> subroutine produces the following in the same place on the console:

	foo: 70% [========================>            ] 70/100
	bar: 75% [==========================>          ] 45/60
	baz: 100%[====================================>] 929/929

This module is thread-safe.

=head1 SYNOPSIS

	use Audicon::Progressmeter;

	# width in columns of output (37 is default)
	my $width = 37;

	# the meters listing is a hash reference with the meter names as keys
	# (empty by default)
	my $meters = {
		'this'	=> [ $current_value1, $max_value1 ],
		'that'	=> [ $current_value2, $max_value2 ],
	};

	# whether to display each meter's name as a label (nonzero is default)
	my $labels = 1;

	# how many calls to ->update_meter() between automatic redraw calls (0
	# to disable automatic display updates)
	my $redraw = 0;

	my $pm = Audicon::Progressmeter->new(
		'width'		=> $width,
		'meters'	=> $meters,
		'labels'	=> $labels,
		'redraw'	=> $redraw,
	);

	# upon first drawing the meter display, use the draw subroutine
	$pm->draw;

	### ...meanwhile... ###
	$pm->update_meter('name' => $my_meter, 'val' => $my_progress);
	# alternately, force a redraw while updating
	$pm->update_meter('name' => $my_meter, 'val' => $my_progress,
		'redraw' => 1);
	# ...

	# when re-drawing the meter display, use the redraw subroutine, as it
	# will draw over the old meters (unnecessary if ->{'redraw'} is set to
	# a nonzero value)
	$pm->redraw;

=head1 SUBROUTINES

=head2 new

Returns a blessed Audicon::Progressmeter object. All arguments are optional.


	# default options are as follows:
	my $pm = Audicon::Progressmeter->new( 
		'width'		=> 37,
		'meters'	=> {},
		'labels'	=> 1,
		'redraw'	=> 0,
	);

	# create a 50-column meter with two meters, one at 20/55 and the
	# second one at 6/100, and display their names as labels
	my $pm = Audicon::Progressmeter->new(
		'width'		=> 50,
		'meters'	=> {
			'meter1'	=> [ 20, 55 ],
			'meter2'	=> [ 6, 100 ],
		},
		'labels'	=> 1,
	);

Here, "20/55" has an index of 0 and "foo: 6/100" has an index of 1. These indices are important when using L</update_meter> and L</delete_meter>.

Optionally, a B<'redraw'> parameter can be passed in upon instantiation, which will update the meter display automatically every time L</update_meter> is called. This parameter also makes it so the initial call of L</draw> is unnecessary. 

=cut

sub new {
	my $class = shift;

	my $self = &share({});

	my ($width, $meters, $labels, $redraw) =
		@{{@_}}{qw/ width meters labels redraw /};

	@{$self}{qw/ width meters labels redraw /} = (
		(defined $width ? $width : WIDTH),
		(defined $meters && &is_shared($meters) ? $meters : &share({})),
		(defined $labels ? $labels : LABELS),
		(defined $redraw ? $redraw : REDRAW),
	);

	# make sure the 'meters' data structure exists in shared memory
	unless (&is_shared($meters)) {
		# copy the values from the unshared hash into a shared one
		while (my ($name, $vals) = each %{$meters}) {
			$self->{'meters'}->{$name} = &share([]);
			@{$self->{'meters'}->{$name}} = @{$vals};
		}
	}

	# set the auto-redraw interval couter to zero
	$self->{'redraw_count'} = 0;

	$self = bless $self, $class;
	# draw the initial meter display if it's going to be updating itself
	# automatically
	$self->draw if $self->{'redraw'};

	$self
}

=head2 draw

Draws the initial set of progress meters. This subroutine should only be called directly once in order to draw the initial display. After that, L</redraw> should be used to update the meter positions.

	$pm->draw;

=cut

sub draw {
	my $self = shift;
	foreach my $name (sort keys %{$self->{'meters'}}) {
		my $vals = $self->{'meters'}->{$name};

		# don't draw empty or corrupt meters
		next unless defined $vals and ref $vals eq 'ARRAY';

		my ($val, $max) = @{$vals};

		# don't draw the meter if we have no idea how to draw it
		next unless defined $val and defined $max;

		# this is pretty self-explanitory
		my $percent = $val / $max;

		# print the label first if it's defined
		print STDERR "$name: " if defined $name and $self->{'labels'};

		printf STDERR "%2d%%%s[%-$self->{'width'}s] %-1d/%-1d\e[K\r\n",

		$percent * 100,
		int $percent ? '' : ' ',
		('=' x ($percent * $self->{'width'} - 1)).'>',
		$val, $max;
	}
}

=head2 redraw

Re-draws the current set of meters, overwriting what had been drawn with the first call of L</draw>. This is the only drawing subroutine that should be called after the initial call of L</draw>.

	$pm->redraw;

=cut

sub redraw {
	my $self = shift;

	# back up to the start of the list
	print STDERR "\e[A" x grep {
		defined @{$_}[0 .. 1]
	} sort values %{$self->{'meters'}};

	$self->draw;
}

=head2 update_meter

Replaces the value(s) of the named meter with (a) new one(s). The 'name' is the only required argument.

	# make the meter named 'meter1' to read read 50/100 and force a redraw
	$pm->update_meter(
		'name' => 'meter1',
		'val' => 50,
		'max' => 100,
		'redraw' => 1,
	);

Sometimes it's just easier to specify the new value. You can do so without changing the maximum:

	# change the aforementioned meter to read 55/100
	$pm->update_meter('name' => 'meter1', 'val' => 55);

And, lastly, it may be useful to be able to just modify the maximum value of the meter:

	# if we decide we underestimated what completion looks like, we can
	# change the max value (in this case, 100 -> 120)
	$pm->update_meter('name' => 'meter1', 'max' => 120);

If no meter exists at the given index, one will be created at that index. If no defined values are given, the meter is unchanged. To delete a meter, use L</delete_meter>.

=cut

sub update_meter {
	my $self = shift;

	# (apparently that mess of brackets is the fastest way to coerce an
	# array into a hash and slice it)
	my ($name, $val, $max, $redraw) = @{{@_}}{qw/ name val max redraw /};

	return undef unless defined $name;

	# mimic object's behavior unless otherwise specified
	$redraw = $self->{'redraw'} unless defined $redraw;

	# set up an empty meter if it doesn't exist yet
	$self->{'meters'}->{$name} = &share([])
		unless exists $self->{'meters'}->{$name};

	my $meter = $self->{'meters'}->{$name};

	$meter->[0] = $val if defined $val;
	$meter->[1] = $max if defined $max;

	if ($redraw) {
		$self->redraw unless ++$self->{'redraw_count'} % $redraw;
	}
}

=head2 delete_meter

Removes (or rather "hides") a meter from the list.

Returns a reference to the empty internal array that would (and still could) hold the selected meter's values.

	# 'name' is the name of the meter we're deleting
	$pm->delete_meter('name' => 'meter1');

=cut

sub delete_meter {
	my $self = shift;

	print STDERR "\e[A\e[K" if defined
		$self->{'meters'}->{${{@_}}{'name'}};

	$self->{'meters'}->{${{@_}}{'name'}} = &share([]);
}

=head1 NOTES

Adding or deleting meters has an unknown effect on the drawing.

=head1 AUTHOR

Dan Church S<E<lt>amphetamachine@gmail.comE<gt>>

=head1 SEE ALSO

L<Audicon>

=head1 COPYRIGHT

Copyright 2008 Dan Church.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the LICENSE file included with this module.

=cut

1
