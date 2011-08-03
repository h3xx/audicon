function process_dir(dir_name, genre, td_file, genre_file, backup_suf, fcns, ..
		clip_duration, tex_span, step)
// process an entire directory as a single genre
//
// Arguments:
//	dir_name:	character string (or vector thereof) of directory
//				name(s) to process.
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
//
//!
// Part of project Audicon by Dan Church <daniel.church@uwrf.edu>

	// load default variables if necessary
	for a = [ 'td_file' 'genre_file' 'backup_suf' 'fcns' 'clip_duration' ..
			'tex_span' 'step' ]
		if ~exists(a, 'local')
			execstr(a + '=audicon_defaults(a)');
		end
	end

	wavlist = listfiles(dir_name + '/*.wav');
	num_wavs = size(wavlist, '*');

	for wav_file_ind = 1 : num_wavs
		wav_file = wavlist(wav_file_ind);
		disp('processing file `' + wav_file + ''' (' + ..
				string(wav_file_ind) + '/' + ..
				string(num_wavs) + ')');
		process_wav(wav_file, genre, td_file, genre_file, backup_suf, ..
				fcns, clip_duration, tex_span, step);
	end

endfunction
