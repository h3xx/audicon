function process_wav(wav_file, genre, td_file, genre_file, backup_suf, ..
		fcns, clip_duration, tex_span, step)
// does everything it needs to in order to add a wav file to the training data
//
// Arguments:
//	wav_file:	character-string path to wav file to be processed
//	genre:		vector of character-string descriptions of genres.
//				These are all the genres defined in this wav
//				file.
//	td_file:	(optional) character-string file name where training
//				data is to be saved. Default is SCIHOME + 
//				'/audicon/training_data.sav'.
//	genre_file:	(optional) character-string path to the file containing
//				the defined genres. Default is SCIHOME +
//				'/audicon/genre_defs.sav'.
//	backup_suf:	(optional) character-string siffix to be appended to the
//				old training data file. Default is '~' (ala vi
//				& EMACS). Use '' (empty string) to disable
//				backups.
//	fcns:		(optional) row-vector of character strings. names of
//				function calls to execute. These must be fully-
//				qualified Scilab function calls. Feel free to
//				use any of these internal variables:
//				c_sz:		each clip's size in samples
//				t_sz:		each texture frame's size in
//					samples
//				curr_ind:	the index of the sample on which
//					the current clip started
//				curr_clip:	the row-vector of clip sample
//					values
//				prev_ind:	the index of the sample on which
//					the previous clip started
//				prev_clip:	the previous clip's sample
//					values
//				next_ind:	the index of the sample on which
//					the next clip starts
//				next_clip:	the next clip's sample values
//				curr_tex:	the row-vector of samples in the
//					current texture frame
//				prev_tex:	the row-vector of samples in the
//					previous texture frame
//				next_tex:	the row-vector of samples in the
//					next texture frame
//				For example `centroid(clip, sampling_rate)'
//				Note: functions must return a single value (can
//				be a vector of values). Anything else will be
//				ignored. Don't say I didn't warn you.
//				Default is defined in `audicon_defaults.sci'.
//	clip_duration:	(optional) duration in seconds of each clip. Default is
//				0.5 seconds.
//	tex_span:	(optional) span defining the range of each `texture'
//				frame of data such that:
//				tex_span(1) is equal to the number of seconds
//				of audio data included BEFORE the target clip
//				and tex_span(2) is equal to the number of
//				seconds of audio data included AFTER the target
//				clip. Default is [ 1 1 ].
//	step:		(optional) for splitting; the number of seconds between
//				the starting points of each clip. Default is
//				0.5 seconds (same as clip_duration).
//				To read DISCRETE samples, make sure this is set
//				to the same value as your clip_duration.
//				to split a clip from EVERY sample, use a value
//				equal to 1 / sampling_rate.
//
// Version 0.1a
//!
// Part of project Audicon by Dan Church <daniel.church@uwrf.edu>

	// load default variables if necessary
	for a = [ 'td_file' 'genre_file' 'backup_suf' 'fcns' 'clip_duration' ..
			'tex_span' 'step' ]
		if ~exists(a, 'local')
			execstr(a + '=audicon_defaults(a)');
		end
	end

	// resize stack to accomodate incoming file
	adjust_stack(wav_file);

	// read samples -> double-precision Sciddlab matrix (one row for each
	// audio channel)
	//[wavdata sampling_rate] = wavread(wav_file);

	// the above process takes up way too much memory. I think I've found
	// an easier way.
	// FIXME: cleanup comments

	// get output from functions
	// the sheer amount of code encapsulated in the next two lines is
	// mind-boggling... and all for little `o'
	o = foreach_split(wavdata, fcns, clip_duration, tex_span, ..
			sampling_rate, step);

	// clear up a bit of memory -- scratch that; `a LOT of memory'
	//clear wavdata;
	// CORRECTION: no need, now that I've simplified the process through
	// trickery

	// load saved training data
	[in_data out_data] = load_training_data(td_file);

	// save on arduous function calls
	num_outs = size(out_data, 'c');
	num_ins = size(in_data, 'c');

	// get the column index of the genre the user said this file was
	genre_ids = process_genre(genre, genre_file, backup_suf);

	// construct this file's genre output patterns (one for each row in `o')

	for genre_id = genre_ids(:)'
		if num_outs < genre_id
			// we have a new genre; we're going to have to resize
			// our output node space
			warning('new genre found: `' + genre + '''');
			out_data(1, genre_id) = 0; // that should resize it
			num_outs = genre_id;
		end

		// genre should now fall within our input pattern
		proto_out(1, genre_id) = 1;
	end

	if size(proto_out, 'c') < num_outs
		// probably -- we can't hope to achieve the last- or newly-
		// defined genre in every file -- we need to resize our
		// prototypic output vector for this file
		proto_out(1, num_outs) = 0;
	end

	num_records_adding = size(o, 'r');

	// ok, now the old output patterns and the new output pattern have the
	// same numeber of outputs -- we can now append one copy of our output
	// vector to the collection of output patterns. One for each input
	// pattern we're adding.
	for z = 1 : num_records_adding
		// append!
		out_data = [ out_data ; proto_out ];
	end

	if num_ins & num_ins ~= size(o, 'c')
		// uh-oh! inconsistency in number of inputs per pattern!
		error(6); // `inconsistent row/column dimensions'
	else
		// good to go -- append new records
		in_data = [ in_data ; o ];
	end

	// finally save
	save_training_data(in_data, out_data);

endfunction
