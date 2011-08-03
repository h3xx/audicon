function [matches, key_freqs, key_limits]=get_keymatches(sampling_rate, ..
		keydefs, octave_span, note_span, keymatches_file, backup_suf)
// gets the currently-saved matrix of key matches, checks it against the
// generation data given. If it doesn't check out, it generates a new one and
// saves it over the old one.
//
// Does most of the calculating for amps_by_key().
//
// Arguments:
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
// Returns a matrix of values, either 0 or 1, whereby one may multiply this
// matrix by the vector of amplitudes (see fft_unweighted) to get a vector v,
// such that:
// v(n) = the sum of all amplitudes falling between the upper and lower limit of
// key n.
//!
// Part of project Audicon by Dan Church <daniel.church@uwrf.edu>

	// load defaults if necessary & correct floating-point badness
	for a = [ 'sampling_rate' 'keydefs' 'octave_span' ..
			'note_span' 'keymatches_file' 'backup_suf' ]
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

	// load and check key matches file, if it exists
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
		// and define `matches', `key_freqs' and `key_limits'
		// plus verification data:
		// `keydefs', `note_span', `octave_span', `sampling_rate' &
		// `clip_duration'
		load(keymatches_file);

		// check over data contents
		if ~exists('matches', 'local') | ..
				~exists('key_freqs', 'local') | ..
				~exists('key_limits', 'local') | ..
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

			warning('get_keymatches(): file doesn''t ' + ..
					'match generation data');

			// restore our data (for generation below)
			keydefs = kd;
			note_span = n_s;
			octave_span = o_s;
			sampling_rate = s_r;
			clip_duration = c_d;

			// make sure no corrupt data escapes
			clear matches key_freqs key_limits;
		end
	end

	// if long-loading variables still aren't present, let's generate them
	if ~exists('matches', 'local') | ..
			~exists('key_freqs', 'local') | ..
			~exists('key_limits', 'local')
		warning('get_keymatches(): generating new set of key ' + ..
				'matches (this may take a while)');

		// TODO: construct a new set of `matches', `key_freqs' &
		// 'key_limits` for saving and returning

		// minimize arduous function calls
		keys_per_octave = size(keydefs, '*');
		samples_per_clip = sampling_rate * clip_duration;
		num_freqs = samples_per_clip / 2;
		total_keys = keys_per_octave * (octave_span(2) - ..
				octave_span(1) + 1);

		// adjust stack to hold a matrix with one row for each frequency
		// & one column for each key
		adjust_stack(total_keys * num_freqs, 0);

		// calculate all key freqs
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

		// calculate limits for all keys
		// format:
		// [ lower_limit(key1), lower_limit(key2) ... ;
		//   upper_limit(key1), upper_limit(key2) ... ]
		key_limits = [];
		for key_ind = 2 : (total_keys + 1)
			// I can't tell you how many times I've thought about
			// this code.
			// It would scare you ... to death.
			key_limits = [ key_limits [ all_key_defs(key_ind) - ..
					note_span(1) * ..
					(all_key_defs(key_ind) - ..
					all_key_defs(key_ind - 1)) / 2 ; ..
					..
					all_key_defs(key_ind) + ..
					note_span(2) * ..
					(all_key_defs(key_ind + 1) - ..
					all_key_defs(key_ind)) / 2 ] ];
		end

		// lastly, calculate the associated vector of frequencies
		freqs = sampling_rate * (0 : (num_freqs - 1)) / ..
				num_freqs / 2;

		// END of TODO

		// initialize matches
		matches(num_freqs, total_keys) = 0;

		// construct matches, row-by-row (warning: this takes a while)
		// find which bins are going to match where. Form of a matrix
		// whose dimensions equal size(all_key_defs, '*') columns &
		// size(amps, '*') rows
		//
		// and whose values are thus:
		//
		// [ bin1 matches key1, bin1 matches key2;
		//   bin2 matches key1, bin2 matches key2;
		//          ...                ...
		//   binx matches key1, binx matches key2 ];
		//
		// so that `amps * matches' is a row-vector describing
		// the total amplitudes matching each key.

		// open a waitbar (we're nice to our user)
		wb = waitbar('calculating matching key frequencies');
		for bin_ind = 1 : num_freqs
			matches(bin_ind, :) = freqs(bin_ind) >= ..
					key_limits(1, :) & ..
					freqs(bin_ind) <= ..
					key_limits(2, :);
			waitbar(bin_ind / num_freqs, wb);
		end
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
		// `matches', `key_freqs' and `key_limits'
		// verification data:
		// `keydefs', `note_span', `octave_span', `sampling_rate' &
		// `clip_duration'
		// (Scilab's save() function seems to not care if it's
		// over-writing)
		save(keymatches_file, matches, key_freqs, key_limits, ..
				keydefs, note_span, octave_span, ..
				sampling_rate, clip_duration);
	end

endfunction
