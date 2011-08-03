package Audicon;

use strict;
use warnings;

our $VERSION = 0.02;

use Audicon::Database	qw//;
use Audicon::NeuralNet	qw//;
use Audicon::File	qw//;
use Audicon::Feature	qw//;

# (prev, next, cur) * (centroid, magratio, flux, rolloff, zerocrossings, keyamps[96]) = 3 * 101 = 303
use constant INPUT_NODES	=> 303;
use constant AUTOSAVE_NETWORK	=> 1;
use constant HIDDEN_NODES	=> 1000;
use constant AUTOWEED_DATABASE	=> 0;
use constant AUTOINIT_DATABASE	=> 1;

=head1 NAME

Audicon - FIXME

=head1 SYNOPSIS

FIXME

=head1 DESCRIPTION

FIXME

=head1 SUBROUTINES

=head2 new

Returns a blessed Audicon object. All arguments are optional and the defaults are shown.

	my %options = (
		'display_progress' => 1, # display wget-style progress bars?
	);
	my $audicon = Audicon->new(%options);

See L<Audicon::Database>, L<Audicon::Feature> and L<Audicon::File> for accepted constructor arguments.

=cut

sub new {
	my $class = shift;

	my $self = bless {
		'net_hidden'		=> HIDDEN_NODES,
		'autosave_network'	=> AUTOSAVE_NETWORK,
		'autoweed_database'	=> AUTOWEED_DATABASE,
		'autoinit_database'	=> AUTOINIT_DATABASE,
		@_,
	}, $class;

	$self->connect_database if defined $self->{'dbfile'};
	$self->connect_network if defined $self->{'annfile'};

	$self
}

=head2 connect_database

Connects to an SQLite database file for storing audio feature data.

	$aud->connect_database('/path/to/mydatabase.db');

=cut

sub connect_database {
	my ($self, $dbfile) = @_;
	$self->{'dbfile'} = $dbfile if defined $dbfile;

	$self->{'database'} = Audicon::Database->new(
		'dbfile'	=> $self->{'dbfile'},
		'auto_weed'	=> $self->{'autoweed_database'},
		'auto_init'	=> $self->{'autoinit_database'},
	);

	# refresh the genre listing
	$self->_get_genres;
}

=head2 connect_network

FIXME

=cut

sub connect_network {
	my ($self, $annfile) = @_;
	$self->{'annfile'} = $annfile if defined $annfile;

	$self->{'neural_net'} = Audicon::NeuralNet->new(
		'annfile'	=> $self->{'annfile'},
		'autosave'	=> $self->{'autosave_network'},
		'input_nodes'	=> INPUT_NODES,
		'hidden_nodes'	=> $self->{'net_hidden'},
		'output_nodes'	=> scalar @{$self->{'genres'}},
	);
}

=head2 add_files

Adds new audio files to the Audicon database, associating them with each of the given genres.

	$audicon->add_files(
		'genres' => [ 'blues', 'rock' ],
		'files' => [ '/path/to/audio1.wav', '/path/to/audio2.wav' ],
	);

=cut

sub add_files {
	my $self = shift;
	my ($genres, $files) = @{{@_}}{qw/ genres files /};

	$genres = [ $genres ] unless ref $genres eq 'ARRAY';
	$files = [ $files ] unless ref $files eq 'ARRAY';
	
	die 'cannot add audio data to database (database not defined); please use &connect_database' unless defined $self->{'database'};

	foreach my $file_idx (0 .. $#{$files}) {
		# hidden progress meter code
		$self->{'meter'}->update_meter(
			'name'	=> $self->{'meter_name'},
			'val'	=> $file_idx + 1,
			'max'	=> scalar @{$files},
		) if $self->{'meter'} && $self->{'meter_name'};

		my $feature = $self->_create_feature($files->[$file_idx]);

		$self->{'database'}->add_feature($feature, $genres);
	}
}

=head2 run_audio

Runs WAV files through the network and returns the results in the form of hashed genre probabilities.

	my $genre_probabilities = $aud->run_audio('/path/to/myfile.wav');

=cut

sub run_audio {
	my $self = shift;

	my @files = @_;

	# get the array of normalization coefficients
	my $norm_coeffs = $self->{'database'}->_norm_coeffs;

	# initialize the return buffer
	my @results;

	# process each file in turn
	foreach my $file_idx (0 .. $#files) {
		# hidden progress meter code
		$self->{'meter'}->update_meter(
			'name'	=> $self->{'meter_name'},
			'val'	=> $file_idx + 1,
			'max'	=> scalar @files,
		) if $self->{'meter'} && $self->{'meter_name'};

		# create the Audicon::Feature object
		my $feature = $self->_create_feature($files[$file_idx]);

		# run the feature through the network
		my $likelihoods = $self->{'neural_net'}->run_feature(
			'norm_coeffs'	=> $norm_coeffs,
			'feature'	=> $feature,
			'genres'	=> $self->{'genres'},
		);

		push @results, $likelihoods;
	}

	# return the results for each file
	wantarray ? @results : \@results
}

=head2 train_network

Pulls the training data out of the database and trains the neural network.

FIXME

=cut

sub train_network {
	my $self = shift;
	
	my ($iterations, $epochs, $target_error, $incremental,
		$training_data_basename, $training_data_size) =
		@{{@_}}{qw/ iterations epochs target_error incremental
			training_data_basename training_data_size /};

	# note: you're probably thinking, "why aren't there default values
	# being substituted in here?" the answer is that the individual
	# functions called here handle all the defaults

	my @training_data_files =
		$self->{'database'}->save_training_data_random(
			'basename'	=> $training_data_basename,
			'size'		=> $training_data_size,
		);

	$self->{'neural_net'}->load_and_train(
		'files'		=> \@training_data_files,
		'iterations'	=> $iterations,
		'epochs'	=> $epochs,
		'target_error'	=> $target_error,
		'incremental'	=> $incremental,
	);
}

=head2 select_test_data

FIXME

=cut

sub select_test_data {
	my $self = shift;

	my ($ratio) = @{{@_}}{qw/ ratio /};

	$self->{'database'}->mark_random_test_data(
		'ratio'		=> $ratio,
		'only'		=> 1,
	);
}

=head2 test_network

Pulls the test data out of the database and runs it through the neural network.

FIXME

=cut

sub test_network {
	my $self = shift;

	my ($test_data_basename) = @{{@_}}{qw/ test_data_basename /};

	my @test_data_files =
		$self->{'database'}->save_training_data_random(
			'basename'	=> $test_data_basename,
			'is_test'	=> 1,
		);

	$self->{'neural_net'}->load_and_run(
		'files'		=> \@test_data_files,
		'genres'	=> $self->{'genres'},
	)
}

=head2 run_featureset

Runs a featureset through the database and returns a hash of likelihoods.

	my $likelihoods = $aud->run_featureset([
		[ INPUT VECTOR 0 ],
		[ INPUT VECTOR 1 ],
	]);

=cut

sub run_featureset {
	my ($self, $featureset) = @_;

	$self->{'neural_net'}->run(
		'featureset'	=> $featureset,
		'genres'	=> $self->{'genres'},
	)
}

########################################
# creates a feature from a given file name
sub _create_feature {
	my ($self, $file) = @_;

	# hidden progress meter code
	my %ex_params = (
		'meter'	=> $self->{'meter'},
		'meter_name' => $self->{'meter_name_feature'},
	) if $self->{'meter'} && $self->{'meter_name_feature'};

	Audicon::Feature->new(
		'file'	=> Audicon::File->new(
			'file'	=> $file,
		),
		%ex_params,
	)
}

# figures out what the genres are from the database and saves it to ->{'genres'}
sub _get_genres {
	my $self = shift;

	$self->{'genres'} = $self->{'database'}->genre_names
		if defined $self->{'database'};
}

=head1 AUTHOR

Dan Church S<E<lt>amphetamachine@gmail.comE<gt>>

=head1 SEE ALSO

=over

=item L<Audicon::Database>

=item L<Audicon::Feature>

=item L<Audicon::File>

=back

=head1 COPYRIGHT

Copyright 2008 Dan Church.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the LICENSE file included with this module.

=cut

1
