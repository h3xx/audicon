function [genres]=load_genres(genre_file)
// loads genres currently defined in text form 
//
// Arguments:
//	genre_file:	(optional) character-string path to the file containing
//				the defined genres. Default is SCIHOME +
//				'/audicon/genre_defs.sav'.
//
// Returns a character-string vector of the genres.
//
// Version: 0.4a
//!
// Part of project Audicon by Dan Church <daniel.church@uwrf.edu>

	// load defaults if necessary
	for a = [ 'genre_file' ]
		if ~exists(a, 'local')
			execstr(a + '=audicon_defaults(a)');
		end
	end

	// load file, if it exists
	[x err] = fileinfo(genre_file);
	if ~err
		// adjust stack
		adjust_stack(genre_file);

		// no problems opening it for a `stat' -- it should work
		load(genre_file); // defines `genres' for us
		if ~exists('genres', 'local')
			// variable was not in the file -- we have a problem
			
			warning('load_genres(): error loading `' + ..
				genre_file + '''. Using empty set.');
			genres = [];
		end
	else
		// couldn't stat file -- we had a problem
		warning('load_genres(): error loading `' + genre_file + ..
				'''. Using empty set.');
		genres = [];
	end
endfunction
