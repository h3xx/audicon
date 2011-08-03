function save_genres(genres, genre_file, backup_suf)
// saves a new vector of genres currently defined in text form 
//
// Arguments:
//	genres:		vector of character-string descriptions of genre.
//				For example: [ 'rock' 'punk' 'metal' ].
//	genre_file:	(optional) character-string path to the file containing
//				the defined genres. Default is SCIHOME +
//				'/audicon/genre_defs.sav'.
//	backup_suf:	(optional) character-string siffix to be appended to the
//				old training data file. Default is '~' (ala vi
//				& EMACS). Use '' (empty string) to disable
//				backups.
//
// Version: 0.1a
//!
// Part of project Audicon by Dan Church <daniel.church@uwrf.edu>

	// load defaults if necessary
	for a = [ 'genre_file' 'backup_suf' ]
		if ~exists(a, 'local')
			execstr(a + '=audicon_defaults(a)');
		end
	end

	// create backup if necessary
	if length(backup_suf)
		// user wants a backup
		// warning: `copyfile()' is new to Scilab 4.1
		if ~copyfile(genre_file, genre_file + backup_suf)
			// copyfile returns 0 if there's an error
			warning('could not backup file `' + genre_file + ..
					''' to `' + genre_file + backup_suf + ..
					'''');
		end
	end

	// save our data
	// (Scilab's save() function seems to not care if it's over-writing)
	save(genre_file, genres);

endfunction
