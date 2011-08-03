function [key_amps, key_freqs, key_matches]=amps_by_key(clipdata, ..
	sampling_rate, keydefs, octave_span, note_span, xp, wd, he, ..
	keymatches_file, backup_suf)
// finds the amplitudes [unweighted] of keys (read: piano keys) in the given set
// of clips
//
// New for version 2.0: uses an implementation of the bell curve to determine
// coefficients applied to fft amplitudes
//
// Arguments:
//      clipdata:	nxm matrix, raw waveform data of each clip to be
//				processed row-by-row.
//	sampling_rate:	(optional) samples per second. Default is 44100.
//	keydefs:	(optional) row-vector of the frequency values, in Hz, of
//				the keys in one octave (on a piano there are 12,
//				but I'm not counting).
//				Special note: this vector must be sorted
//				ascending! Also, `max(keydefs)' must be less
//				than `2 * min(keydefs)'!
//	octave_span:	(optional) vector (or scalar) of the number of octaves
//				in each direction being processed, such that:
//				octave_span(1) is equal to the number of octaves
//				above the defined octave (negative == octaves
//				below) that marks the start of the octaves to be
//				processed, and
//				octave_span(2) is equal to the number of octaves
//				above the defined octave that marks the end of
//				the span of octaves to be processed.
//				If octave_span is a scalar, it is taken to be a
//				measure of the octave-distance in each direction
//				of the span. Default is [ -3 4 ].
//	note_span:	(optional) vector (or scalar) of the span (as a fraction
//				of the distance between the note and the
//				halfway-point between adjacent notes) for which
//				each note will have amplitude counted for it,
//				such that:
//				note_span(1) is the span below each note, and
//				note_span(2) is the span above each note.
//				Note: `lower notes' means notes of lower
//				frequencies and `higher notes' means notes of
//				higher frequencies.
//				If note_span is a scalar, it is taken to be a
//				measure of the span of each note in each
//				direction. Default is [ 0.5 0.5 ].
//				Beware, though. If you have a value in here
//				that's greater than 1, there's a good chance
//				you'll have some overlapping of notes. 
//				... this might not be a bad thing.
//	xp, wd, he:	(optional) See documentation for `bell_curve'
//				for information about what these parameters do.
//	keymatches_file: (optional) file name of the Scilab save file where the
//				matrix of matching keys are kept. Due to
//				unforseen complexities concerning the extraction
//				of keys, a simpler way of determining the
//				sums of the amplitudes of all the keys matched
//				was developed to save time. However, because
//				it involved matrix multiplication and the
//				creation of a gigantic (but narrow) matrix, said
//				method would work very slowly in creating this
//				matrix, but would go extremely quickly through
//				calculating matching keys for all samples
//				concerned. This file will be set up to contain
//				a saved copy of that matrix, along with all
//				necessary information about how that matrix came
//				to be, the latter portion being used to check
//				whether it would save time to load the saved
//				matrix, or whether to generate a new one.
//				Default is SCIHOME + '/audicon/key_matches.sav'.
//	backup_suf:	(optional) character-string suffix to be appended to the
//				old training data file. Default is '~' (ala vi
//				& EMACS). Use '' (empty string) to disable
//				backups.
//
// Returns:
//	key_amps:	an nxm vector of the notes' average amplitudes, each
//				clip in `clipdata' defined on a different row
//	key_freqs:	a column-vector of all note frequencies found in the
//				octave span
//	key_matches:	a matrix of size nxm, such that n is equal to the number
//				of possible frequencies in the given set of clip
//				data (size in samples divided by 2) & m is equal
//				to the number of keys in the span of octaves
//				(size(keydefs, '*') * (sum(abs(octave_span)) +
//				1))
//
// Version: 2.0
//!
// Part of project Audicon by Dan Church <daniel.church@uwrf.edu>

	// load defaults if necessary & correct floating-point badness
	for a = [ 'sampling_rate' 'keydefs' 'octave_span' 'note_span' ..
			'xp' 'wd' 'he' ..
			'keymatches_file' 'backup_suf' ]
		if ~exists(a, 'local')
			execstr(a + '=audicon_defaults(a)');
		end
	end

	sampling_rate = int(abs(sampling_rate));

	// if they only specified one direction, make that value count in both
	// directions
	if size(octave_span, '*') < 2
		octave_span(1) = -abs(octave_span(1));
		octave_span(2) = -octave_span(1);
	end

	// maybe I'll implement partial octaves later...
	octave_span = int(octave_span);

	// make sure everything is in order
	octave_span = [ min(octave_span) max(octave_span) ];

	// if they only specified one direction, make that value count in both
	// directions
	if size(note_span, '*') < 2
		note_span(2) = note_span(1);
	end

	// because negative note spans won't count
	note_span = abs(note_span);

	// get (hopefully) pre-calculated match matrix
	// or, if we need to, calculate it and save it for later
	
	// --- BEGIN LARGE MATRIX CALCULATION ---

	// adjust stack
	adjust_stack(size(clipdata, 'c') / 2 * ..
			size(keydefs, '*') * (sum(abs(octave_span)) + 1));

	// calculate clip duration (for saving later)
	clip_duration = size(clipdata, 'c') / sampling_rate;

	// load and check pre-existing key matches file, if it exists
	[x err] = fileinfo(keymatches_file);
	if ~err

		// backup our variables before loading
		kd = keydefs;
		n_s = note_span;
		o_s = octave_span;
		s_r = sampling_rate;
		c_d = clip_duration;

		// make sure the file isn't cheating
		clear keydefs note_span octave_span sampling_rate clip_duration;

		// no problems doing a `stat' -- it should work to load it
		// and define `key_matches' & `key_freqs'
		// plus verification data:
		// `keydefs', `note_span', `octave_span', `sampling_rate' &
		// `clip_duration'
		load(keymatches_file);

		// check over data contents
		if ~exists('key_matches', 'local') | ..
				~exists('key_freqs', 'local') | ..
				~exists('keydefs', 'local') | ..
				~exists('note_span', 'local') | ..
				~exists('octave_span', 'local') | ..
				~exists('sampling_rate', 'local') | ..
				~exists('clip_duration', 'local') | ..
				sum(size(keydefs, '*') ~= size(kd, '*')) | ..
				sum(keydefs ~= kd) | ..
				sum(size(note_span, '*') ~= size(n_s, '*')) | ..
				sum(note_span ~= n_s) | ..
				sum(size(octave_span, '*') ~= ..
					size(o_s, '*')) | ..
				sum(octave_span ~= o_s) | ..
				sum(size(sampling_rate, '*') ~= ..
					size(s_r, '*')) | ..
				sum(sampling_rate ~= s_r) | ..
				sum(size(clip_duration, '*') ~= ..
					size(c_d, '*')) | ..
				sum(clip_duration ~= c_d)

			warning('amps_by_key(): saved variable doesn''t ' + ..
					'match generation data');

			// restore our data (for generation below)
			keydefs = kd;
			note_span = n_s;
			octave_span = o_s;
			sampling_rate = s_r;
			clip_duration = c_d;

			// make sure no corrupt data escapes (and free up a
			// little memory)
			clear key_matches key_freqs kd n_s o_s s_r c_d;
		end
	end

	// if long-loading variables still aren't present, let's generate them
	if ~exists('key_matches', 'local') | ..
			~exists('key_freqs', 'local')
		warning('amps_by_key(): generating new set of key matches' + ..
				'(this may take a while)');

		// construct a new set of `key_matches', `key_freqs'
		// for saving and returning

		// minimize arduous function calls
		keys_per_octave = size(keydefs, '*');
		samples_per_clip = size(clipdata, 'c');
		num_freqs = samples_per_clip / 2;
		total_keys = keys_per_octave * (octave_span(2) - ..
				octave_span(1) + 1);

		// adjust stack to hold a matrix with one row for each frequency
		// & one column for each key
		adjust_stack(total_keys * num_freqs, 0);

		// calculate all key freqs (note to self: this get returned;
		// don't touch it)
		key_freqs = [];
		for octave = octave_span(1) : octave_span(2)
			key_freqs = [ key_freqs keydefs * 2 ^ octave ];
		end

		// grab adjacent notes from adjacent octaves (simplifies the
		// next step a lot)
		all_key_defs = [ keydefs(keys_per_octave) * ..
					2 ^ (octave_span(1) - 1) ..
				key_freqs ..
				keydefs(1) * 2 ^ (octave_span(2) + 1) ];

		// associated vector of frequencies (done the exact same way as
		// in fft_unweighted())
		freqs = sampling_rate * (0 : (num_freqs - 1)) / num_freqs / 2;

		// (See documentation for bell_curve() if you're confused)
		// since I've decided that the all-exponent crossing point (at
		// x=c+-1) should be the determining factor for key `dropoff'
		// points, it would make sense to figure out the average dropoff
		// point determined by `note_span' and compute a bell curve
		// (with respect to the `freqs' vector) for each key frequency
		// such that:
		//	* the peak lies at the place in `freqs' most similar to
		//	  the note's frequency (this eliminates the guesswork
		//	  associated with stepping through the frequency array
		//	  and comparing values.
		//	* the curve (though symmetric) is scaled with respect to
		//	  x in such a way that the exponent-independent common
		//	  point is equal to the average of the distances (in Hz,
		//	  mind you) dictated by the function
		//		s[n] = ( abs( N[n]-N[n-1] ) * note_span[1] / 2 +
		//			abs( N[n]-N[n+1] ) * note_span[2] / 2 )
		//				/ 2
		//
		//	where N is a vector of all the key frequencies
		//
		//	let's get to it

		// open a waitbar (we're nice to our user)
		wb = waitbar('calculating matching key frequencies');

		// initialize `key_matches'
		key_matches = [];

		for key_ind = 2 : (total_keys + 1)
			// how far to scale the curve (rtfm if you don't				// understand)
			sc = ((all_key_defs(key_ind) - ..
					all_key_defs(key_ind - 1)) * ..
					note_span(1) / 2 + ..
				(all_key_defs(key_ind + 1) - ..
					all_key_defs(key_ind)) * ..
					note_span(2) / 2) / 2;

			// the center should appear exactly on our key frequency
			cn = all_key_defs(key_ind);

			// (done): add the other arguments to bell_curve to our
			// parameters
			bc = bell_curve(freqs, xp, wd, sc, he, cn)';

			// add the curve to our matrix
			key_matches = [ key_matches bc ];

			// update waitbar
			waitbar((key_ind - 1) / total_keys, wb);
		end

		// close waitbar
		winclose(wb);

		// save computed data and verification data

		// create backup if necessary
		if length(backup_suf)
			// user wants a backup
			// warning: `copyfile()' is new to Scilab 4.1
			if ~copyfile(keymatches_file, keymatches_file + ..
					backup_suf)
				// copyfile returns 0 if there's an error
				warning('could not backup file `' + ..
						keymatches_file + ''' to `' + ..
						keymatches_file + ..
						backup_suf + '''');
			end
		end

		// save our data
		// computed data:
		// `key_matches' & `key_freqs'
		// verification data:
		// `keydefs', `note_span', `octave_span', `sampling_rate' &
		// `clip_duration'
		// (Scilab's save() function seems to not care if it's
		// over-writing)
		save(keymatches_file, key_matches, key_freqs, ..
				keydefs, note_span, octave_span, ..
				sampling_rate, clip_duration);
	end

	// --- END LARGE MATRIX CALCULATION ---

	// Now process all clips at once
	// ... in one line (squee!) [hint: fft_unweighted's matrix amps output
	// can be multiplied to our `key_matches' to produce a matrix with a row
	// of the key amplitide sums for each clip (row) in clipdata]
	key_amps = fft_unweighted(clipdata, sampling_rate) * key_matches;
endfunction
