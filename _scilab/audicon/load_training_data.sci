function [in_data, out_data]=load_training_data(td_file)
// load current training data from disk
//
// Arguments:
//	td_file:	(optional) character-string file name where training
//				data is saved. Default is SCIHOME + 
//				'/audicon/training_data.sav'.
//
// Returns:
//	in_data:	matrix of real inputs. Each input pattern is defined on
//				a different row.
//	out_data:	matrix of real target outputs. Each output pattern is
//				defined on a different row.
//
// Version: 1.0b
//!
// Part of project Audicon by Dan Church <daniel.church@uwrf.edu>

	// load default variables if necessary
	for a = [ 'td_file' ]
		if ~exists(a, 'local')
			execstr(a + '=audicon_defaults(a)');
		end
	end

	// load file, if it exists
	[x err] = fileinfo(td_file);
	if ~err
		// adjust stack
		adjust_stack(td_file);

		// no problems opening it for a `stat' -- it should work
		load(td_file); // defines `in_data' & `out_data' for us
		if ~exists('in_data', 'local') | ~exists('out_data', 'local')
			// variables were not in the file -- we have a problem
			warning('load_training_data(): error loading `' + ..
				td_file + '''. Using empty set.');
			in_data = [];
			out_data = [];
		end
	else
		// couldn't stat file -- we had a problem
		warning('load_training_data(): error loading `' + td_file + ..
				'''. Using empty set.');
		in_data = [];
		out_data = [];
	end

endfunction
