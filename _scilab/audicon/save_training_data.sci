function save_training_data(in_data, out_data, td_file, backup_suf)
// saves training data to disk
//
// Arguments:
//	in_data:	matrix of real inputs, each input pattern defined on a
//				different row.
//	out_data:	matrix of real target outputs, each output pattern
//				defined on a different row.
//	td_file:	(optional) character-string file name where training
//				data is to be saved. Default is SCIHOME + 
//				'/audicon/training_data.sav'.
//	backup_suf:	(optional) character-string suffix to be appended to the
//				old training data file. Default is '~' (ala vi
//				& EMACS). Use '' (empty string) to disable
//				backups.
//
//!
// Part of project Audicon by Dan Church <daniel.church@uwrf.edu>

	// load default variables if necessary
	for a = [ 'td_file' 'backup_suf' ]
		if ~exists(a, 'local')
			execstr(a + '=audicon_defaults(a)');
		end
	end

	// create backup if necessary
	if length(backup_suf)
		// user wants a backup
		// warning: `copyfile()' is new to Scilab 4.1
		if ~copyfile(td_file, td_file + backup_suf)
			// copyfile returns 0 if there's an error
			warning('could not backup file `' + td_file + ..
					''' to `' + td_file + backup_suf + ..
					'''');
		end
	end

	// save our data
	// (Scilab's save() function seems to not care if it's over-writing)
	save(td_file, in_data, out_data);

endfunction
