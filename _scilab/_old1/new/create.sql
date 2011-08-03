create table file (
	file_id integer primary key,
	file_name text,
	file_description text,
	file_year integer
);

create table sample (
	sample_id integer primary key,
	file_id integer not null default 0,
	sample_index integer,
	sample_data blob not null
);

create table genre (
	genre_id integer primary key,
	genre_description text not null
);

create table instrument (
	instrument_id integer primary key,
	instrument_description text not null
);

create table c_file_genre (
	file_id integer,
	genre_id integer,
	magnitude integer not null default 1,
	primary key (file_id, genre_id)
);

create table c_sample_instrument (
	sample_id integer,
	instrument_id integer,
	magnitude integer not null default 1,
	primary key (sample_id, instrument_id)
);


