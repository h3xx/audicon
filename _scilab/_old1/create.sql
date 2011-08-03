drop table file;
create table file (
	file_id integer primary key,
	file_name text,
	file_description text,
	file_year integer
);

drop table sample;
create table sample (
	sample_id integer primary key,
	file_id integer not null default 0,
	sample_index integer,
	sample_data blob not null
);

drop table genre;
create table genre (
	genre_id integer primary key,
	genre_description text not null
);

drop table instrument;
create table instrument (
	instrument_id integer primary key,
	instrument_description text not null
);

drop table c_file_genre;
create table c_file_genre (
	file_id integer,
	genre_id integer,
	magnitude integer not null default 1,
	primary key (file_id, genre_id)
);

drop table c_sample_instrument;
create table c_sample_instrument (
	sample_id integer,
	instrument_id integer,
	magnitude integer not null default 1,
	primary key (sample_id, instrument_id)
);
