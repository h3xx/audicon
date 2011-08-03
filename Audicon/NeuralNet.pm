package Audicon::NeuralNet;

use strict;
use warnings;

our $VERSION = '0.01';

use AI::FANN		qw//;

use constant HIDDEN_NODES	=> 1e3;

use constant AUTOSAVE		=> 0;

use constant TRAIN_ITERATIONS	=> 10;
use constant TRAIN_EPOCHS	=> 1e3;
use constant LEARN_RATE		=> 0.00001;
# TODO : tweak target error
use constant TRAIN_TARGET_ERROR	=> 0.1;
use constant DEBUG		=> 1;

=head1 NAME

Audicon::NeuralNet - Abstraction layer for building, training and saving a neural network to map audio feature data to genres using L<AI::FANN>

=head1 DESCRIPTION

L<AI::FANN>

=head1 SYNOPSIS

=head2 Construction

	use Audicon::Database;
	use Audicon::NeuralNet;

	# (see the appropriate documentation page)
	my $adb = Audicon::Database->new(...);

	# retrieve the size of a featureset from the database; this will be the
	# size of the input layer of the network
	my $input_nodes = $adb->featureset_size;

	# retrieve the number of genres in the database; this will be the size
	# of the output layer of the network
	my $output_nodes = $adb->total_genres;

	# choose a size for the hidden layer
	# (1000 is the default)
	my $hidden_nodes = 1000;

	# set the learning rate; though higher values learn faster, lower
	# values are more suitable because of the sheer amount of data that is
	# to be passed through the network upon training
	# (1/100_000 is the default)
	my $learning_rate = 0.00001;

	# set the file the network will be saved into
	my $annfile = '/path/to/my_audicon.ann';

	# whether the network will be automatically saved
	# (no automatic saving [0] is the default)
	# Note: use $nn->save for manual saving
	my $autosave = 0;

	# construct the network
	my $nn = Audicon::NeuralNet->new(
		'input_nodes'	=> $input_nodes,
		'hidden_nodes'	=> $hidden_nodes,
		'output_nodes'	=> $output_nodes,
		'learning_rate'	=> $learning_rate,
		'annfile'	=> $annfile,
		'autosave'	=> $autosave,
	);

=head2 Training

	# step 1:
	# save the training data from the database in the FANN internal format
	# and save the names of the files it saved it to
	# (see the appropriate documentation page)

	my @train_data_files = $adb->save_training_data_random(
		...
		'is_test'	=> 0,
	);

	# step 2:
	# train the network using the files

	# (defaults are shown here)
	$nn->load_and_train(
		'files'		=> \@train_data_files,
		'iterations'	=> 10,
		'epochs'	=> 1_000,
		'target_error'	=> 0.1,
		'incremental'	=> 0,
	);

=head2 Testing

	# step 1:
	# save the test data from the database

	my @test_data_files = $adb->save_training_data_random(
		...
		'is_test'	=> 1,
	);

	# step 2:
	# run the data through the network and get a hash of cumulative error
	# by genre name

	# retrieve the set of genre names from the database (for hashing)
	my $genre_names = $adb->genre_names;

	# send the test data through the network
	my $cumulative_error = $nn->load_and_run(
		'files'		=> \@test_data_files,
		'genres'	=> $genre_names,
	);

	# pull out the cumulative error for the `rock' genre
	my $rock_error = $cumulative_error->{'rock'};	

=head1 SUBROUTINES

=head2 new

Instantiates the neural network object.

	# (default values are shown here)
	my $nn = Audicon::NeuralNet->new(

		# parameters for constructing the network

		'input_nodes'	=> $num_in,	# required
		'hidden_nodes'	=> 1000,
		'output_nodes'	=> $num_out,	# required
		'learning_rate'	=> 0.00001,

		# parameters for saving the network

		'annfile'	=> $my_annfile,	# optional
		'autosave'	=> 0,
	);

If the 'autosave' argument is unset, no automatic saving of the neural network will occur. In order to save it manually, please use the function L</save>.

=cut

sub new {
	my $class = shift;

	my $self = bless {
		'hidden_nodes'	=> HIDDEN_NODES,
		'autosave'	=> AUTOSAVE,
		'learning_rate'	=> LEARN_RATE,
		@_,
	}, $class;

	warn 'no network save file specified; will not save work'
		unless $self->{'annfile'};


	# attempt to load or create a new network
	if ($self->{'annfile'} and -e $self->{'annfile'}) {
		$self->load;
	} else {
		$self->create;
	}

	$self
}

=head2 load_and_train

FIXME

=cut

sub load_and_train {
	my $self = shift;

	my ($files, $iterations, $epochs, $target_error, $incremental) =
		@{{@_}}{qw/ files iterations epochs target_error incremental /};

	$iterations = TRAIN_ITERATIONS unless defined $iterations;
	$epochs = TRAIN_EPOCHS unless defined $epochs;
	$target_error = TRAIN_TARGET_ERROR unless defined $target_error;

	foreach my $set_iter (1 .. $iterations) {

		foreach my $td_file (@{$files}) {
			if (-e $td_file) {
				$self->{'net'}->train_on_file(
					# training data
					$td_file,
					# max number of epochs
					$epochs,
					# report every n epochs
					DEBUG ? 1 : 0,
					# target error
					$incremental ?
						# incrementally decrease
						# allowed error
						$target_error / $set_iter :
						$target_error);

				# auto-save after each training data file
				$self->save if $self->{'autosave'}
					and $self->{'annfile'};
			} else {
				# training data didn't exist
				warn "couldn't find training data file `$td_file': $!"
			}
		}
	}

	# auto-save the network if wanted
	$self->save if $self->{'autosave'} and $self->{'annfile'};
}

=head2 run

Runs a featureset, or set of featuresets through the neural network and returns a hash of genres => likelihoods.

	# the list of what genres are meant by what index
	my $genres = [ 'rock', 'classical', ... ];

	# whether to return a vector of the output data, rather than a mapped
	# hash (0 is default)
	my $as_array = 0;

	my $likelihoods = $nn->run(
		'featureset'	=> $featureset,
		'genres'	=> $genres,
		'as_array'	=> $as_array,
	);

	# ...

	# print a list of what the featureset likely represents
	print "$_ => $likelihoods->{$_}\n"
		foreach sort {$likelihoods->{$a} <=> $likelihoods->{$b}};

=cut

sub run {
	my $self = shift;

	my ($featureset, $genres, $as_array) =
		@{{@_}}{qw/ featureset genres as_array /};

	$featureset = [ $featureset ] unless ref $featureset eq 'ARRAY';

	# create the buffer for containing the summed genre likelihoods
	my @genre_buff = (0) x @{$genres};

	# iterate through each featureset in the collection
	foreach my $feat (@{$featureset}) {
		# get the resultant buffer from the network
		my $genre_add = $self->{'net'}->run($feat);

		# sum the likelihoods
		$genre_buff[$_] += $genre_add->[$_]
			foreach 0 .. $#genre_buff;
	}

	# average the likelihood as votes
	@genre_buff = map {$_ / @{$featureset}} @genre_buff;

	# if they didn't specify a genre, there's no way to map likelihoods
	my $ret;
	unless ($as_array) {
		my %genre_map;
		# average the likelihoods and add to the return buffer
		@genre_map{@{$genres}} = @genre_buff;

		$ret = \%genre_map
	} else {
		$ret = \@genre_buff;
	}

	$ret

}

=head2 load_and_run

Loads saved data and runs it through the network. Returns a hash of the genre names mapped to the average error for each of them.

	my $genre_errors = $nn->load_and_run(
		'files'		=> [ 'test_data.0', 'test_data.1', ... ],
		'genres'	=> $genres,
	);

=cut

sub load_and_run {
	my $self = shift;

	my ($files, $genres) = @{{@_}}{qw/ files genres /};

	$files = [ $files ] unless ref $files eq 'ARRAY';

	# initialize the list of genre errors
	my @genre_error = (0) x @{$genres};

	# keep a record of which genres are represented (for averaging error)
	my @genre_representation = (0) x @{$genres};

	foreach my $td_file (@{$files}) {
		if (-e $td_file) {
			my $td = AI::FANN::TrainData->new_from_file($td_file);
			foreach my $test_idx (0 .. ($td->length - 1)) {
				# extract in / supposed out
				my ($t_in, $t_out) = $td->data($test_idx);

				# tally genre representation
				$genre_representation[$_] += $t_out->[$_]
					for 0 .. $#{$genres};

				my $out = $self->{'net'}->run($t_in);

				# loop through the output buffer and compare it
				# to what was supposed to come out
				$genre_error[$_] += abs $t_out->[$_] - $out->[$_]
					foreach 0 .. $#{$out};
			}
		} else {
			warn "couldn't find test data file `$td_file': $!"
		}
	}

	# average the errors using the genre representation array
	$genre_error[$_] /= $genre_representation[$_]
		for 0 .. $#{$genres};

	# collate into a hash
	my %mapped_error;
	@mapped_error{@{$genres}} = @genre_error;

	\%mapped_error
}

=head2 run_feature

Runs an entire collection of featuresets from an L<Audicon::Feature> object through the network and returns a hash of genres => likelihoods.

	my $likelihoods = $nn->run_feature(
		'feature'	=> $feature,
		'genres'	=> $genres,
	);

=cut

sub run_feature {
	my $self = shift;
	my ($feature, $genres, $norm_coeffs) =
		@{{@_}}{qw/ feature genres norm_coeffs /};

	my $featuresets = $feature->calc_all_featuresets(
		'as_array'	=> 1,
		'norm_coeffs'	=> $norm_coeffs,
	);

	# just pass the collection through the normal run function
	$self->run(
		'featureset'	=> $featuresets,
		'genres'	=> $genres,
	)
}

=head2 save

Saves the network to a file.

	$nn->save("/path/to/my_audicon.ann");

	# alternatively, save to the 'annfile' parameter specified upon
	# instantiation

	$nn->save;

=cut

sub save {
	my ($self, $annfile) = @_;

	$annfile = $self->{'annfile'} unless defined $annfile;

	$self->{'net'}->save($annfile);
}

=head2 load

Loads the network from a file.

	$nn->load("/path/to/my_audicon.ann");

	# alternatively, load from the 'annfile' parameter specified upon
	# instantiation

	$nn->load;

=cut

sub load {
	my ($self, $annfile) = @_;

	$annfile = $self->{'annfile'} unless defined $annfile;

	$self->{'net'} = AI::FANN->new_from_file($annfile);
}

=head2 create

Creates a new network based on the values of the '(input|output|hidden)_nodes' and 'learning_rate' parameters given upon instantiation, or those passed in.

	# use the values passed into &new
	$nn->create;

	# use new values
	$nn->create(
		'input_nodes'	=> $num_in,
		'hidden_nodes'	=> $num_hidden,
		'output_nodes'	=> $num_out,
		'learning_rate'	=> $learn_rate,
	);

=cut

sub create {
	my $self = shift;

	my ($input_nodes, $hidden_nodes, $output_nodes, $learning_rate) =
		@{{@_}}{qw/ input_nodes hidden_nodes output_nodes learning_rate /};

	# replace the object's values if new ones were specified
	$self->{'input_nodes'} = $input_nodes if defined $input_nodes;
	$self->{'hidden_nodes'} = $hidden_nodes if defined $hidden_nodes;
	$self->{'output_nodes'} = $output_nodes if defined $output_nodes;
	$self->{'learning_rate'} = $learning_rate if defined $learning_rate;

	die 'no idea of network sizings (did you specify the "(input|output|hidden)_nodes" parameters?)'
	unless defined $self->{'input_nodes'}
		and defined $self->{'output_nodes'}
		and defined $self->{'hidden_nodes'};

	# create the FANN network
	$self->{'net'} = AI::FANN->new_standard(@{$self}{qw/ input_nodes hidden_nodes output_nodes /});

	# set the learning rate
	$self->{'net'}->learning_rate($self->{'learning_rate'})
		if defined $self->{'learning_rate'};

	# auto-save the newly-created network if wanted
	$self->save if $self->{'autosave'} and $self->{'annfile'};
}

########
# autosave if wanted upon DESTROY
sub DESTROY {
	my $self = shift;
	$self->save
		# check if the necessary data structures still exist
		if $self and $self->{'net'}
			# check if auto-save is in effect
			and $self->{'autosave'} and $self->{'annfile'};
}

=head1 AUTHOR

Dan Church S<E<lt>amphetamachine@gmail.comE<gt>>

=head1 SEE ALSO

=over

=item L<Audicon::Database>

=back

=head1 COPYRIGHT

Copyright 2008 Dan Church.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the LICENSE file included with this module.

=cut

1
