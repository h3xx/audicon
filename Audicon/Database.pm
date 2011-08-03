package Audicon::Database;

use strict;
use warnings;

our $VERSION = '0.02';

use DBI				qw//;
use File::Temp			qw/ tempdir /;

use constant TRANSACTION	=> 1;
use constant AUTO_INIT		=> 1;
use constant AUTO_WEED		=> 0;
use constant WEED_THRESHOLD	=> 100;

=head1 NAME

Audicon::Database - Maintain a database of extracted audio feature data

=head1 DESCRIPTION

This extends the functionality of L<Audicon> by maintaining an SQLite database backend to store the extracted audio feature data as well as miscellaneous other information pertaining to setup.

=head1 SYNOPSIS

FIXME

=head1 SUBROUTINES

=head1 new

Initializes the object.

	# (defaults are shown here)

	# this specifies the mode that transactions are handled when updating
	# the database in any way
	# 0 => transactions are not automatically used (autocommit)
	# 1 => use a transaction for every file being added (default)
	# 2 => use a transaction for every set of files
	my $transaction_mode = 1;

	# autmatically make sure the tables, views and indices are present upon
	# initialization?
	my $auto_init = 1;

	# weed the database of unusable featuresets upon initialization?
	my $auto_weed = 0;

	# the default weeding threshold (see &weed)
	my $weed_threshold = 100;

	my $adb = Audicon::Database->new(
		'dbfile'	=> '/path/to/my_sqlite_db',
		'transaction'	=> $transaction_mode,
		'auto_init'	=> $auto_init,
		'auto_weed'	=> $auto_weed,
		'weed_threshold'=> $weed_threshold,
	);

=cut

sub new {
	my $class = shift;

	my $self = bless {
		'transaction'	=> TRANSACTION,
		'auto_init'	=> AUTO_INIT,
		'auto_weed'	=> AUTO_WEED,
		'weed_threshold'=> WEED_THRESHOLD,
		@_,
	}, $class;

	$self->{'dbh'} = DBI->connect('dbi:SQLite:dbname=' . $self->{'dbfile'},
		'', '')
		or die 'connect to database failed';

	$self->init_db if $self->{'auto_init'};
	$self->weed if $self->{'auto_weed'};

	# initialize the query library
	$self->_prepare_queries;

	$self
}

=head2 add_feature

Takes an L<Audicon::Feature> object and iterates through it, adding all of its audio feature data to the database, linking it to the set of genres specified.

	# instantiate the featureset calculator
	my $feature = Audicon::Feature->new(...);

	# add everything from it to the database as being of the genre 'rock'
	$adb->add_feature($feature, 'rock');

	# --OR--

	# add it to the database as blues AND rock
	$adb->add_feature($feature, [ 'blues', 'rock' ]);

=cut

sub add_feature {
	my $self = shift;

	my ($feature, $genre) = @_;

	# retrieve pre-prepared insertion queries
	my ($link_genre, $insert, $update_prev, $update_next) =
		@{$self->{'queries'}}{qw/ link_genre insert update_prev update_next /};

	$genre = [ $genre ] unless ref $genre eq 'ARRAY';
	$feature = [ $feature ] unless ref $feature eq 'ARRAY';

	# transaction control support
	$self->begin_work if $self->{'transaction'} > 1;

	foreach my $f (@{$feature}) {
		$self->begin_work if $self->{'transaction'} == 1;
		# extract necessary parameters
		my $filename = $f->{'file'}->{'file'};
		my $norm_coeff = $f->{'file'}->{'norm_coeff'};
		my $sampling_rate = $f->{'file'}->{'sampling_rate'};

		# create an entry for the file
		my $file_num = $self->audio_id(
			'name'		=> $filename,
			'norm_coeff'	=> $norm_coeff,
			'sampling_rate'	=> $sampling_rate,
		);

		# link the genres specified to the file
		$link_genre->execute(
			$file_num,
			$self->genre_id(
				'name'	=> $_,
				'insert'=> 1,
			),
		) foreach @{$genre};

		# insert first featureset and retain the id for linking
		my ($first_feature, $first_fid) =
			($f->calc_featureset, $self->feature_id);

		$insert->execute($first_fid, $file_num,
			$f->{'file'}->{'clip_buffs'}->{'curr'}->{'pos'},
			@{$first_feature}{ qw/ centroid magratio flux
			rolloff zerocrossings / },
			@{$first_feature->{'keyamps'}});

		my $prev_fid = $first_fid;

		my $fid;

		until ($f->reached_end) {
			$fid = $self->feature_id;
			$update_next->execute($fid, $prev_fid);
			my $featureset = $f->calc_featureset;

			$insert->execute($fid, $file_num,
				$f->{'file'}->{'clip_buffs'}->{'curr'}->{'pos'},
				@{$featureset}{ qw/ centroid magratio
				flux rolloff zerocrossings / },
				@{$featureset->{'keyamps'}});

			$update_prev->execute($prev_fid, $fid);
			$prev_fid = $fid;
		}

		# link the previous and next pointers of the first and last
		# featuresets in the database, respectively
		# ($fid now refers to the id of the last feature in the file)
		$update_next->execute($first_fid, $fid);
		$update_prev->execute($fid, $first_fid);

		$self->commit if $self->{'transaction'} == 1;
	}

	# weed the database if auto-weeding
	$self->weed if $self->{'auto_weed'};

	$self->commit if $self->{'transaction'} > 1;
}

=head2 begin_work, rollback, commit

Access to transaction control of the database.

	$adb->begin_work;

	# [change database]

	if ($error) {
		$adb->rollback;
	} else {
		$adb->commit;
	}

=cut

sub begin_work {
	my $self = shift;

	$self->{'dbh'}->begin_work;
}

sub rollback {
	my $self = shift;

	$self->{'dbh'}->rollback;
}

sub commit {
	my $self = shift;

	$self->{'dbh'}->commit;
}

=head2 audio_id

Retrieves the integer audio identifier from the database. If the file doesn't exist yet in the database, it creates a new entry and returns the identifier for it.

	my $audio_id = $adb->audio_id(
		'name'	=> '/path/to/myaudio.wav',
		'norm_coeff'	=> $normalization_coefficient,
		'sampling_rate'	=> $audio_sampling_rate,
	);

=cut

sub audio_id {
	my $self = shift;

	my ($file, $norm, $srate) =
		@{{@_}}{qw/ name norm_coeff sampling_rate /};

	my $q = $self->{'queries'}->{'audio_lookup'};

	$q->execute($file);

	# note: fetchall_arrayref returns ref to array of refs to rows (eek)
	my $res = $q->fetchall_arrayref;

	unless (@{$res}) {
		# no rows returned -- insert
		$self->{'queries'}->{'insert_audio'}->execute($file, $norm, $srate);
		# re-execute first query (should come up with something)
		$q->execute($file);
		$res = $q->fetchall_arrayref;
	}

	die "cannot insert file '$file' into database"
		unless @{$res};

	# return the first column from the first (and hopefully only) result
	$res->[0]->[0]
}

=head2 genre_id

Retrieves the integer genre identifier from the database.

In the event that C<'insert'> is nonzero, and if the genre doesn't exist yet in the database, a new entry will be created for it and the identifier for it will be returned.

If C<'insert'> is zero (the default) and the genre does not yet exist in the database, a value of C<-1> will be returned.

	my $genre_id = $adb->genre_id(
		'name'	=> 'blues',
		'insert'=> 0,	# don't insert anything if we don't find it
	);

=cut 

sub genre_id {
	my $self = shift;

	my ($genre, $insert) = @{{@_}}{qw/ name insert /};

	# execute the query that returns the genre_id for a named genre
	(my $lookup_q = $self->{'queries'}->{'genre_lookup'})
		->execute($genre);

	# note: fetchall_arrayref returns ref to array of refs to rows (eek)
	my $res = $lookup_q->fetchall_arrayref;

	# the return value placeholder
	my $genre_id;

	# test to see if the genre_name specified was found in the database
	unless (@{$res}) {
		# nothing was returned (genre not found; let's insert it)

		# test to see if the user wants to insert the genre_name if it
		# wasn't found ('insert' argument was set to nonzero)
		if ($insert) {
			# insert the genre_name
			$self->{'queries'}->{'insert_genre'}->execute($genre);

			# re-execute first query (should come up with something
			# now that it's supposedly been inserted)
			$lookup_q->execute($genre);
			# ... and re-fetch the result
			$res = $lookup_q->fetchall_arrayref;

			# well, shit; apparently the insert didn't work (no
			# matching genre_names after it was explicitly inserted
			# -- THIS SHOULD NEVER EVER HAPPEN)
			die "cannot insert genre `$genre' into database"
				unless @{$res};

			# retrieve the genre_id parameter from the query
			$genre_id = $res->[0]->[0];
		} else {
			# not found and not inserting; set the return value to
			# the error code
			$genre_id = -1;
		}
	} else {
		# found genre_name defined in database; set return value to the
		# genre_id of the named genre (first column of first row of
		# result)
		$genre_id = $res->[0]->[0];
	}

	# return the genre_id we either found or inserted (or the error value)
	$genre_id
}

=head2 genre_names

Returns an array of the genre names defined in the database. The indices this array will be the same as they occur in both the database and in the training data.

	my $genre_names = $adb->genre_names;

=cut

sub genre_names {
	my $self = shift;

	# execute the query for pulling all (genre_id, genre_name) from the
	# `genre' table
	(my $genre_all_q = $self->{'queries'}->{'genre_all'})
		->execute;

	# initialize the buffer of genre names
	my $genre_names = [];

	# i know this looks obfuscated, but all it's doing is creating an array
	# of genre_names (query row subindex 1) indexed by the genre_ids (query
	# row subindex 0) minus 1 (because the genre_ids start counting from 1)
	$genre_names->[$_->[0] - 1] = $_->[1]
		foreach @{$genre_all_q->fetchall_arrayref};

	wantarray ? @{$genre_names} : $genre_names;
}

=head2 genre_representation

Returns a hash of genre names, with the values being how many featuresets currently in the database represent each genre.

	my $genre_rep = $adb->genre_representation;

	my $rock_rep = $genre_rep->{'rock'}; # etc.

=cut

sub genre_representation {
	my $self = shift;

	# use the query that measures the size of an audio file
	# and the one that gets all audio_ids
	# and the one that finds the genre_ids associated to an audio_id
	my ($ac_q, $aid_q, $gl_q) =
		@{$self->{'queries'}}{qw/ audio_size all_aids genre_assoc /};

	# retrieve the array of genre names
	my $genre_names = $self->genre_names;

	# initialize the return hash
	my $reps = {};
	# initialize to all zeroes
	@{$reps}{@{$genre_names}} = (0) x @{$genre_names};

	# execute the "all audio_ids" query
	$aid_q->execute;

	# iterate through each audio_id in the database
	foreach my $audio_id (map {$_->[0]} @{$aid_q->fetchall_arrayref}) {
		# figure out the size (in featuresets) of the audio in question
		$ac_q->execute($audio_id);
		my $num_featuresets = $ac_q->fetchall_arrayref->[0]->[0];

		# short circuit if there's nothing to do
		next unless $num_featuresets;

		# retrieve all genre_ids associated to this audio_id
		$gl_q->execute($audio_id);

		# for each genre associated with this audio_id, add its size to
		# the hash at that key
		$reps->{$genre_names->[$_ - 1]} += $num_featuresets
			foreach map {$_->[0]} @{$gl_q->fetchall_arrayref};
	}

	# return the hash
	$reps
}

=head2 feature_id

Returns the next C<feature_id> from the database that would be the identifier of the next featureset inserted into the database.

	my $next_feature_id = $adb->feature_id;

=cut

sub feature_id {
	my $self = shift;

	# execute the query for finding the max feature_id
	$self->{'queries'}->{'fid_max'}->execute;
	my $res = $self->{'queries'}->{'fid_max'}->fetchall_arrayref;

	# return either the max plus 1, or, if the max is zero or undefined, 1
	$res->[0]->[0] ? $res->[0]->[0] + 1 : 1
}

=head2 init_db

Sets up the initial tables, views and indices in the database if they don't exist. It's generally a good idea to run this function if the file is just being created.

It also serves to clear the database and set up new, empty tables if it is called with a non-zero argument.

If the C<'auto_init'> parameter was set in L</new>, this function is automatically run without any arguments upon instantiation.

	# don't clear anything
	$adb->init_db;
	# or
	$adb->init_db(0);

	# clear the entire database (!!!)
	$adb->init_db(1);

=cut

sub init_db {
	my $self = shift;
	my $force = shift;

	# implement transaction control
	$self->begin_work if $self->{'transaction'};

	if ($force) {
		$self->{'dbh'}->do('drop table if exists ' . $_)
			foreach qw/ audio genre c_audio_genre feature /;

		#$self->{'dbh'}->do('drop view if exists link');

		$self->{'dbh'}->do('drop index if exists ' . $_)
			foreach qw/ usable source
			centroid magratio flux rolloff zerocrossings /;
	}

	$self->{'dbh'}->do(
'create table if not exists audio (
	audio_id	integer	primary key,
	audio_name	text	unique	not null,
	audio_norm	text,
	audio_srate	text
)'
	);

	$self->{'dbh'}->do(
'create table if not exists genre (
	genre_id	integer	primary key,
	genre_name	text	unique	not null
)'
	);

	$self->{'dbh'}->do(
'create table if not exists c_audio_genre (
	audio_id	integer,
	genre_id	integer,
	primary key (audio_id, genre_id)
)'
	);

	$self->{'dbh'}->do(
'create table if not exists feature (
	feature_id	integer	primary key,
	prev_id		integer,
	next_id		integer,
	audio_id	integer,
	pos		integer,

	centroid	real,
	magratio	real,
	flux		real,
	rolloff		real,
	zerocrossings	real,' .
	join ("\n", (map {"keyamps$_	real,"} 1 .. 96)) . '
	enabled		integer	not null	default 1
)'
	);

	# create the view (for pulling the data)
#	$self->{'dbh'}->do(
#'create view if not exists link as select all
#audio_id, feature_id, enabled,
#centroid_prev, magratio_prev, flux_prev, rolloff_prev, zerocrossings_prev, keyamps_prev,
#centroid, magratio, flux, rolloff, zerocrossings, keyamps,
#centroid_next, magratio_next, flux_next, rolloff_next, zerocrossings_next, keyamps_next
#from (
#	select all * from feature
#		left join (
#			select all
#				feature_id as next_id,
#				enabled as enabled_next,
#				centroid as centroid_next,
#				magratio as magratio_next,
#				flux as flux_next,
#				rolloff as rolloff_next,
#				zerocrossings as zerocrossings_next,
#				keyamps as keyamps_next
#			from feature
#		) using (next_id)
#) left join (
#	select all
#		feature_id as prev_id,
#		enabled as enabled_prev,
#		centroid as centroid_prev,
#		magratio as magratio_prev,
#		flux as flux_prev,
#		rolloff as rolloff_prev,
#		zerocrossings as zerocrossings_prev,
#		keyamps as keyamps_prev
#	from feature
#) using (prev_id)
#	where enabled > 0 and enabled_prev > 0 and enabled_next > 0'
#	);

	# create an indices for each scalar column (greatly speeds performance)
	$self->{'dbh'}->do(
"create index if not exists $_ on feature ($_)"
	) for qw/ centroid magratio flux rolloff zerocrossings /, (map {"keyamps$_"} 1 .. 96);

	# create an index for enabled vs. disabled
	$self->{'dbh'}->do(
'create index if not exists usable on feature (enabled)'
	);

	# create an index for audio source id (potentially speeds up &pull_data)
	$self->{'dbh'}->do(
'create index if not exists source on feature (audio_id)'
	);

	# implement transaction control
	$self->commit if $self->{'transaction'};
}

=head2 clear_db

Clears the entire database. Don't ever do this unless you really, REALLY want to.

	$adb->clear_db;

=cut

sub clear_db {
	my $self = shift;

	# implement transaction control
	$self->begin_work if $self->{'transaction'};

	$self->{'dbh'}->do("delete from $_")
		foreach qw/ feature genre audio c_audio_genre /;

	# implement transaction control
	$self->commit if $self->{'transaction'};
}

=head2 weed

Weeds out feature data that was derived from audio data that contained only null, or mostly null samples. It does this by finding entries where the number of zero-axis crossings is less than the given value and marking them as "disabled" inside the database. This will prevent these featuresets, as well as their adjacent featuresets, from being returned when either L</pull_data>, L</save_training_data> or L</save_training_data_random> is called.

The default zero-crossing threshold value is 100, or whatever was passed in for the C<'weed_threshold'> parameter upon instantiation.

	# weed-out only empty audio
	$adb->weed(0);

	# just use the default value (100)
	$adb->weed;

=cut

sub weed {
	my ($self, $min_zerocrossings) = @_;

	# use the default value if there was none specified
	$min_zerocrossings = $self->{'weed_threshold'}
		unless defined $min_zerocrossings;

	# implement transaction control
	$self->begin_work if $self->{'transaction'};

	# execute the weeding query
	$self->{'queries'}->{'weed'}->execute($min_zerocrossings);

	# implement transaction control
	$self->commit if $self->{'transaction'};
}

=head2 total_genres

Returns the total number of genres represented in the database. Effective way of determining the size of the output layer of Audicon's neural network (see L<Audicon::NeuralNet>).

	my $num_genres = $adb->total_genres;

=cut

sub total_genres {
	my $self = shift;

	# this query is pretty self-explanitory
	(my $count_q = $self->{'queries'}->{'count_genres'})
		->execute;

	# return the first (and hopefully only) value of the result
	$count_q->fetchall_arrayref->[0]->[0]
}

=head2 featureset_size

Returns the size of a featureset. This is an effective way of determining the size of the input layer of Audicon's neural network (see L<Audicon::NeuralNet>).

	my $num_features = $adb->featureset_size;

=cut

sub featureset_size {
	my $self = shift;

	# get the information from the 'lookup' query -- (next|prev)_id +
	# feature columns; multiplied by 3 for (prev|curr|next) bindings
	($self->{'queries'}->{'lookup'}->{'NUM_OF_FIELDS'} - 2) * 3
}

=head2 mark_random_test_data

Marks random featureset data in the database to be used as test data. This data will only be pulled if either one of the data-pulling functions is called with the argument C<< 'is_test' => 1 >>.

	# (defaults are shown here)
	# 5% to be marked as training data
	my $test_data_portion = 0.05;

	# reset all previously-marked training data?
	my $only = 1;

	$adb->mark_random_test_data(
		'ratio'	=> $test_data_portion,
		'only'	=> $only,
	);

See L</test_data_ratio> for determining if this needs to be done.

=cut

sub mark_random_test_data {
	my $self = shift;

	my ($ratio, $only) = @{{@_}}{qw/ ratio only /};
	$ratio = 0.05 unless defined $ratio;
	$only = 1 unless defined $only;

	# implement transaction control
	$self->begin_work if $self->{'transaction'};

	# reset the previous marks if wanted
	$self->{'queries'}->{'reset_marks'}->execute
		if $only;

	# execute the query to fetch all feature_ids where enabled is 1
	(my $fid_q = $self->{'queries'}->{'all_fids'})
		->execute;

	# get the first column from the query
	my @feature_ids = map {$_->[0]}
		@{$fid_q->fetchall_arrayref};

	my $mark_total = $ratio * @feature_ids;

	# hold the list of test data feature_ids
	my @test_fids;

	# until the list contains the appropriate amount...
	while (@test_fids < $mark_total) {
		# ...splice out a random fid and push it onto the list
		push @test_fids, (splice @feature_ids, rand (@feature_ids), 1);
	}

	# retrieve the marking query
	my $mark_q = $self->{'queries'}->{'mark_test'};

	# mark them in the database
	$mark_q->execute($_) foreach @test_fids;

	# implement transaction control
	$self->commit if $self->{'transaction'};
}

=head2 test_data_ratio

Returns what the ratio of B<training> data out of the B<total> data not marked as C<disabled> is. Useful for determining whether to run L</mark_random_test_data>.

	my $test_ratio = $adb->test_data_ratio;

=cut

sub test_data_ratio {
	my $self = shift;

	# execute query for getting (count(train), count(test))
	(my $count_q = $self->{'queries'}->{'dataset_counts'})
		->execute;

	# grab the first columns of data from the query
	my ($tr_count, $te_count) = map {$_->[0]}
		@{$count_q->fetchall_arrayref};

	# set test count to zero if it wasn't set
	$te_count = 0 unless defined $te_count;

	my $total = $tr_count + $te_count;

	# return the ratio, OR undef if dividing by zero
	$total ?
		$te_count / $total :
		undef
}

=head2 genre_buff

Fetches a buffer of genre data associated with a given C<audio_id>. Returns a reference to an array of ones and zeroes. In the case of an C<audio_id> that represents more than one genre, this array will have values such that their sum will equal C<1>.

	my $file_genres = $adb->genre_buff($my_audio_id);

	my $whether_genre0 = $file_genres->[0];

See L</genre_names> for how to interpret this list.

=cut

sub genre_buff {
	my ($self, $audio_id) = @_;

	# figure out how many genres will need to be represented in the output
	# buffer
	my $total_genres = $self->total_genres;

	# execute the query to get the genre_ids associated with an audio_id
	(my $genre_q = $self->{'queries'}->{'genre_assoc'})
		->execute($audio_id);

	# pull out the first column of the result
	my @genre_ids = map {$_->[0]} @{$genre_q->fetchall_arrayref};

	# initialize buffer to all zeroes
	my $genre_buf = [ (0) x $total_genres ];

	# add the genres as their indices to the output
	# note: dividing by @genre_ids causes multiple genre representation to
	# be represented as fractional values (this is very much intentional)
	$genre_buf->[$_ - 1] = 1 / @genre_ids
		foreach @genre_ids;

	# return the constructed buffer
	$genre_buf
}

=head2 feature_buff

Returns a buffer of joined 'previous', 'current' and 'next' featuresets for a C<feature_id>.

	my $featureset = $adb->feature_buff($my_feature_id);

=cut

sub feature_buff {
	my ($self, $feature_id, $norm_coeffs) = @_;

	# use the 'lookup' query; gets prev_id, next_id + all feature cols
	# given that enabled > 0
	(my $fdata_q = $self->{'queries'}->{'lookup'})
		->execute($feature_id);
	# current
	my $curr = $fdata_q->fetchall_arrayref;

	my $featureset = [];

	if (@{$curr}) {
		# cut out the annoying multidimensional indices
		$curr = $curr->[0];

		# splice-out the first two columns; this accomplishes two
		# things: cleaning the featureset array and giving the
		# feature_ids of the adjacent featuresets so we can retrieve
		# them in turn
		my ($prev_id, $next_id) = splice @{$curr}, 0, 2;

		# retrieve the adjacent featuresets
		# previous
		$fdata_q->execute($prev_id);
		my $prev = $fdata_q->fetchall_arrayref;
		# next
		$fdata_q->execute($next_id);
		my $next = $fdata_q->fetchall_arrayref;

		# test to see if both the previous and next featureset returned
		# (meaning they're both in the database AND not marked as
		# disabled)
		if (@{$prev} and @{$next}) {
			# cut out the annoying multidimensional indices
			($prev, $next) = ($prev->[0], $next->[0]);

			# discard unused sequencing data from the adjacent row
			# buffers (prev_id, and next_id - first two cols)
			splice @{$prev}, 0, 2;
			splice @{$next}, 0, 2;

			# normalize the feature data
			if ($norm_coeffs) {
				foreach (0 .. $#{$norm_coeffs}) {
					$prev->[$_] *= $norm_coeffs->[$_];
					$curr->[$_] *= $norm_coeffs->[$_];
					$next->[$_] *= $norm_coeffs->[$_];
				}
			}

			# concatenate the values and put them into the
			# featureset buffer
			$featureset = [
				@{$prev}, @{$curr}, @{$next},
			];
		}
	}

	$featureset
}

=head2 pull_data

Retrieves all the feature data in the database, leaving out any sequencing data.

The data returned will be in the following format:

	[
		{
			'in'	=> [ $feature1, $feature2, ... ],
			'out'	=> [ $whether_genre1, $whether_genre2, ... ],*
		},
		{'in' => ..., 'out' => ...}, ...
	]

* The length of the output vector will be equal to the number of genres currently defined in the database. A B<1> in, say, column 1 will denote that the featureset defined at the B<'in'> index is marked as being an example of genre #1, whatever that might have been defined as.

	# retrieve ALL the featuresets from the database
	my $ins_and_outs = $adb->pull_data;

	# or, only retrieve 10 (default is no limit)
	my $ins_and_outs = $adb->pull_data(
		'limit'	=> 10,
	);

Alternately, one may retrieve the data as a set of data compatible with L<AI::FANN>'s training data formats, which would look something like this:

	[
		[ [ $in1, $in2, ... ], [ $out1, $out2, ... ] ],
		[ [ ... ], [ ... ] ],
		...
	]

To retrieve the data in this format, one would use the following syntax:

	my $data = $adb->pull_data(
		'as_array'	=> 1,
	);

It might even be easier to instantiate the L<AI::FANN::TrainData> object with the data from this method:

	my $tdata = AI::FANN::TrainData->new(
		$adb->pull_data(
			'as_array'	=> 1,
		)
	);

=cut

sub pull_data {
	my $self = shift;

	my ($limit, $as_array, $is_test, $normalize) =
		@{{@_}}{qw/ limit as_array is_test normalize /};

	# initialize the audio_id-based queries
	my $fid_q = $self->{'queries'}->{'fid_'.($is_test ? 'test' : 'train')};

	# perform some minor pre-calculations
	my @audio_ids = @{$self->{'dbh'}->selectcol_arrayref('select all audio_id from audio')};

	# initialize the return buffer
	my $data = [];

	# calculate the normalization coefficient array
	my $norm_coeffs;
	$norm_coeffs = $self->_norm_coeffs if $normalize; # leave undef if not

	# count through the audio files in the database
	AUDIO: foreach my $audio_id (@audio_ids) {
		# figure out what the output will look like for all featuresets
		# in this file

		my $genre_data = $self->genre_buff($audio_id);

		# fetch the feature ids associated with the current audio id
		$fid_q->execute($audio_id);
		my @fids = map {$_->[0]} @{$fid_q->fetchall_arrayref};

		# collate the data and add to the return buffer
		foreach my $feature_id (@fids) {
			# &feature_buff only normalizes if $norm_coeffs is set,
			# which it wouldn't be if the 'normalize' argument is
			# zero
			my $feature_data = $self->feature_buff(
				$feature_id, $norm_coeffs
			);

			next unless @{$feature_data};
			# add the featureset to the return buffer
			push @{$data},
				$as_array ? [ $feature_data, $genre_data ] :
			{
				'in'	=> $feature_data,
				'out'	=> $genre_data,
			};

			# short-circuit if the limit has been reached
			last AUDIO if $limit and @{$data} > $limit;
		}
	}

	wantarray ? @{$data} : $data
}

=head2 save_training_data, save_training_data_random

Saves collections of training data buffers to files in the internal format readable by L<AI::FANN>. C<save_training_data_random> saves the data in a random order, so that it will be less likely to cause inconsistencies in training a neural network.

This segmentary handling of training data is to overcome memory limitations involved in the processing of large amounts of data.

	# where to save the training data; each separate file will have a
	# numeric index affixed to the end of the basename (for example
	# "$basename.0", "$basename.1", etc.) If this isn't specified, a
	# temporary directory will be used
	my $basename = "/path/to/training_data";

	# how many records to save in each file
	my $size = 10_000; # the default; uses about 275 megs of memory

	# whether to pull TEST data (nonzero) or TRAINING data (zero)
	my $is_test = 0;

	# whether to normalize the columns
	my $normalize = 1;

	my @training_data_files = $adb->save_training_data(
		'normalize'	=> $normalize,
		'basename'	=> $basename,
		'size'		=> $size,
		'is_test'	=> $is_test,
	);

=cut

sub save_training_data {
	my $self = shift;

	my ($basename, $size, $is_test, $normalize) =
		@{{@_}}{qw/ basename size is_test normalize /};

	# replace unspecified parameters with defaults
	$normalize = 1 unless defined $normalize;
	$size = 1e4 unless defined $size;
	$basename = &tempdir('CLEANUP'=>1) .
		($is_test ? 'test' : 'training') . '_data'
			unless defined $basename;

	# initialize the audio_id-based queries
	my $fid_q = $self->{'queries'}->{'fid_'.($is_test ? 'test' : 'train')};

	# perform some minor pre-calculations
	my @audio_ids = @{$self->{'dbh'}->selectcol_arrayref('select all audio_id from audio')};

	# initialize the save buffer
	my $data = [];

	# keep a running filename suffix
	my $filenum = 0;

	# calculate the normalization coefficient array
	my $norm_coeffs;
	$norm_coeffs = $self->_norm_coeffs if $normalize; # leave undef if not

	# count through the audio files in the database
	foreach my $audio_id (@audio_ids) {
		# figure out what the output will look like for all featuresets
		# in this file

		my $genre_data = $self->genre_buff($audio_id);

		# fetch the feature ids associated with the current audio id
		$fid_q->execute($audio_id);
		my @fids = map {$_->[0]} @{$fid_q->fetchall_arrayref};

		# collate the data and add to the return buffer
		foreach my $feature_id (@fids) {
			# &feature_buff only normalizes if $norm_coeffs is set,
			# which it wouldn't be if the 'normalize' argument is
			# zero
			my $feature_data = $self->feature_buff(
				$feature_id, $norm_coeffs
			);

			next unless @{$feature_data};

			# add the featureset to the return buffer
			push @{$data}, [ $feature_data, $genre_data ];

			# rotate files if the size limit has been reached
			if ($size and @{$data} >= $size) {
				# store the current data buffer and increment
				# the file name
				$self->_save_fann_data($data,
					$basename . '.' . $filenum++);

				# then clear the buffer
				$data = [];
			}
		}
	}

	# now, if there's a not-completely-full data buffer, save it to disk
	$self->_save_fann_data($data, "$basename.$filenum") if @{$data};

	# here, $filenum will equal the suffix of the last file
	my @tdfiles = map {"$basename.$_"} 0 .. $filenum;

	wantarray ? @tdfiles : \@tdfiles;
}

sub save_training_data_random {
	my $self = shift;

	my ($basename, $size, $is_test, $normalize) =
		@{{@_}}{qw/ basename size is_test normalize /};

	# replace unspecified parameters with defaults
	$normalize = 1 unless defined $normalize;
	$size = 1e4 unless defined $size;
	$basename = &tempdir('CLEANUP'=>1) .
		($is_test ? 'test' : 'training') . '_data'
			unless defined $basename;

	# initialize the audio_id-based queries
	my @features = @{$self->{'dbh'}->selectall_arrayref('select all feature_id, audio_id from feature where enabled = '.($is_test ? 2 : 1))};

	# perform some minor pre-calculations
	my @audio_ids = @{$self->{'dbh'}->selectcol_arrayref('select all audio_id from audio')};

	# create a hash of audio ids whose values are the genre buffers
	# associated to them
	my %gbuffs;
	@gbuffs{@audio_ids} = map {$self->genre_buff($_)} @audio_ids;

	# initialize the save buffer
	my $data = [];

	# keep a running filename suffix
	my $filenum = 0;

	# calculate the normalization coefficient array
	my $norm_coeffs;
	$norm_coeffs = $self->_norm_coeffs if $normalize; # leave undef if not

	# count through the audio files in the database
	while (@features) {
		# splice out a random feature id and extract
		my ($feature_id, $audio_id) =
			@{splice @features, (int rand @features), 1};

		# retreve the data components
		my ($feature_data, $genre_data) = (
			# &feature_buff only normalizes if $norm_coeffs is set,
			# which it wouldn't be if the 'normalize' argument is
			# zero
			$self->feature_buff($feature_id, $norm_coeffs),
			$gbuffs{$audio_id}
		);

		# skip if unusable
		next unless @{$feature_data} and @{$genre_data};

		# add the featureset to the save buffer
		push @{$data}, [ $feature_data, $genre_data ];

		# rotate files if the size limit has been reached
		if ($size and @{$data} >= $size) {
			# store the current data buffer and increment
			# the file name
			$self->_save_fann_data($data,
				$basename . '.' . $filenum++);

			# then clear the buffer
			$data = [];
		}
	}

	# now, if there's a not-completely-full data buffer, save it to disk
	$self->_save_fann_data($data, "$basename.$filenum") if @{$data};

	# here, $filenum will equal the suffix of the last file
	my @tdfiles = map {"$basename.$_"} 0 .. $filenum;

	wantarray ? @tdfiles : \@tdfiles;
}

########
# internal functions

sub _prepare_queries {
	my $self = shift;

	my $dbh = $self->{'dbh'};

	my @feat_cols = (qw/ centroid magratio flux rolloff zerocrossings /,
		map {"keyamps$_"} 1 .. 96);

	$self->{'queries'} = {
		'fid_train'	=> $dbh->prepare(
'select all feature_id from feature where audio_id = ? and enabled = 1'
),

		'fid_test'	=> $dbh->prepare(
'select all feature_id from feature where audio_id = ? and enabled = 2'
),

		'link_genre'	=> $dbh->prepare(
'insert into c_audio_genre(audio_id, genre_id) values(?, ?)'
),

		'insert'	=> $dbh->prepare(
'insert into feature(feature_id, audio_id, pos, ' . join (', ', @feat_cols) . ') values(' . (join ', ', ('?') x (3 + @feat_cols)) . ')'
),

		'update_prev'	=> $dbh->prepare(
'update feature set prev_id = ? where feature_id == ?'
),

		'update_next'	=> $dbh->prepare(
'update feature set next_id = ? where feature_id == ?'
),

		'insert_audio'	=> $dbh->prepare(
'insert into audio(audio_name, audio_norm, audio_srate) values(?, ?, ?)'
),
		'insert_genre'	=> $dbh->prepare(
'insert into genre(genre_name) values(?)'
),

		'mark_test'	=> $dbh->prepare(
'update feature set enabled = 2 where feature_id = ?'
),

		'weed'		=> $dbh->prepare(
'update feature set enabled = 0 where zerocrossings < ?'
),

		'audio_lookup'	=> $dbh->prepare(
'select all audio_id from audio where audio_name == ?'
),

		'genre_all'	=> $dbh->prepare(
'select all genre_id, genre_name from genre'
),

		'genre_lookup'	=> $dbh->prepare(
'select all genre_id from genre where genre_name == ?'
),

		'genre_assoc'	=> $dbh->prepare(
'select all genre_id from c_audio_genre where audio_id = ? order by genre_id'
),

		'lookup'	=> $dbh->prepare(
'select all prev_id, next_id, ' . join (', ', @feat_cols) . ' from feature where feature_id = ? and enabled > 0'
),

		'maxes'		=> $dbh->prepare(
'select all ' . (join ', ', map {"max($_)"} @feat_cols) . ' from feature'
),

		'fid_max'	=> $dbh->prepare(
'select all max(feature_id) from feature'
),

		'count_genres'	=> $dbh->prepare(
'select all count() from genre'
),

		'reset_marks'	=> $dbh->prepare(
'update feature set enabled = 1 where enabled = 2'
),

		'all_fids'	=> $dbh->prepare(
'select all feature_id from feature where enabled = 1'
),

		'all_aids'	=> $dbh->prepare(
'select all audio_id from audio',
),

		'dataset_counts'=> $dbh->prepare(
'select all count() from feature where enabled = 2 or enabled = 1 group by enabled order by enabled'
),

		'audio_size'	=> $dbh->prepare(
'select all count() from feature where enabled = 1 and audio_id = ?'
),

	};
}

# retrieves the normalization coefficients for each column
sub _norm_coeffs {
	my $self = shift;

	(my $max_q = $self->{'queries'}->{'maxes'})
		->execute;

	[ map {$_ ? (1 / $_) : 1} @{$max_q->fetchall_arrayref->[0]} ]
}

# formats a buffer of training data in FANN internal format and saves to a file
sub _save_fann_data {
	my ($self, $data, $file) = @_;

	open FDATA, ">$file"
		or die "error opening data file `$file' for writing: $!";

	# data is formatted thusly:
	# line0: [size] [num_in] [num_out]
	# line1: [space-separated inputs1]
	# line2: [space-separated outputs1]

	my ($size, $num_in, $num_out) =
		(scalar @{$data}, scalar @{$data->[0]->[0]}, scalar @{$data->[0]->[1]});

	# write file header
	print FDATA "$size $num_in $num_out\n";

	# write the body
	print FDATA "@{$_->[0]}\n@{$_->[1]}\n"
		foreach @{$data};

	close FDATA
		or warn "error closing data file `$file': $!";
}

=head1 NOTES

This module can be used directly, but is meant for use in L<Audicon>.

=head1 AUTHOR

Dan Church S<E<lt>amphetamachine@gmail.comE<gt>>

=head1 SEE ALSO

=over

=item L<Audicon>

=item L<Audicon::Feature>

=back

=head1 COPYRIGHT

Copyright 2008 Dan Church.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the LICENSE file included with this module.

=cut

1
