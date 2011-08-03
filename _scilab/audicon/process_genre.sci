function [genre_id]=process_genre(genre, genre_file, backup_suf)
// appends a genre to the set currently defined and gets its 
//
// Arguments:
//	genre:		character-string (or vector thereof) description of
//				genre(s)
//	genre_file:	(optional) character-string path to the file containing
//				the defined genres. Default is SCIHOME +
//				'/audicon/genre_defs.sav'.
//	backup_suf:	(optional) character-string siffix to be appended to the
//				old training data file. Default is '~' (ala vi
//				& EMACS). Use '' (empty string) to disable
//				backups.
//
// Returns the specified genre(s)' index(es) for internal use.
//!
// Part of project Audicon by Dan Church <daniel.church@uwrf.edu>

	// load default variables if necessary
	for a = [ 'genre_file' 'backup_suf' ]
		if ~exists(a, 'local')
			execstr(a + '=audicon_defaults(a)');
		end
	end

	// make sure input is lower case
	genre = convstr(genre, 'l');

	// load current library of genres
	genre_defs = load_genres(genre_file);

	num_genres = size(genre_defs, '*');

	num_lookups = size(genre, '*');
	for lookup_ind = 1 : num_lookups
		// find genre in library
		genre_id(lookup_ind) = 1;
		while genre_id(lookup_ind) <= num_genres & ..
				genre_defs(genre_id(lookup_ind)) ~= ..
				genre(lookup_ind)
			genre_id(lookup_ind) = genre_id(lookup_ind) + 1;
		end

		if genre_id(lookup_ind) > num_genres
			// we didn't find it
			// add it to our library
			save_genres([ genre_defs genre(lookup_ind) ], ..
				genre_file, backup_suf);
			// genre_id should be fine
		end
	end

endfunction
