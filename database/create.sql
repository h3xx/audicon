-- SQLite3 database definition for use in project Audicon --

--pragma auto_vacuum = 1; /* only for individual queries */

begin transaction;

/* table featureset
 *
 * stores the calculated featuresets for each clip+texture frame pair, as well
 * as the ids of the two adjacent ones.
 *
 * I felt that storing the values as text would eliminate type conversion
 * problems. Besides, in Perl the line between text and numbers blurs greatly.
 *
 * note: when inserting keyamps field, use perl's array->string interpolation
 */
drop table if exists feature;
create table feature (
	feature_id	integer	primary key,
	prev_id		integer,
	next_id		integer,
	audio_id	integer,
	pos		integer,

	centroid	text,
	magratio	text,
	flux		text,
	rolloff		text,
	zerocrossings	text,
	keyamps		text,
	enabled		integer	not null	default 1
);

/* table audio
 *
 * holds information about all audio files processed
 */
drop table if exists audio;
create table audio (
	audio_id	integer	primary key,
	audio_name	text	unique	not null,
	audio_norm	text,
	audio_srate	text
);

/* table genre
 *
 * holds text descriptions of all genres explored
 */
drop table if exists genre;
create table genre (
	genre_id	integer	primary key,
	genre_name	text	unique	not null
);

/* table c_audio_genre
 *
 * serves as a composite table between audio and genre
 * allows audio files to take on multiple genres
 */
drop table if exists c_audio_genre;
create table c_audio_genre (
	audio_id	integer,
	genre_id	integer,
	primary key (audio_id, genre_id)
);

commit;
