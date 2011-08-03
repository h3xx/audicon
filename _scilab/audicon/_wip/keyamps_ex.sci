function [key_amps, key_freqs]=amps_by_key(clipdata, keydefs, octave_span,
	note_span, sampling_rate)
// NEW METHOD!
// uses an implementation of the bell curve to determine coefficients applied to
// fft amplitudes
//
// bla-dee-bla
//
//!
// Part of project Audicon by Dan Church <daniel.church@uwrf.edu>

// [ calculate all key freqs; grab adjacent ones ]

	// minimize arduous function calls
	keys_per_octave = size(keydefs, '*');
	num_clips = size(clipdata, 'r');
	total_keys = keys_per_octave * (octave_span(2) - octave_span(1) + ..
			1);

	// calculate all key freqs (note to self: this get returned; don't touch
	// it)
	key_freqs = [];
	for octave = octave_span(1) : octave_span(2)
		key_freqs = [ key_freqs keydefs * 2 ^ octave ];
	end

	// grab adjacent notes from adjacent octaves (simplifies the next step
	// a lot)
	all_key_defs = [ keydefs(keys_per_octave) * 2 ^(octave_span(1) - 1) ..
		key_freqs ..
		keydefs(1) * 2 ^ (octave_span(2) + 1) ];

	// now, generate the matrix to be applied to the fft amplitude matrix
	// (one column per key)

	// size of output in frequency bands
	num_bins = size(clipdata, 'c') / 2;
	// associated vector of frequencies (done the exact same way as in
	// fft_unweighted())
	freqs = sampling_rate * (0 : (num_bins - 1)) / num_bins / 2;

	// (See documentation for bell_curve() if you're confused)
	// since I've decided that the all-exponent crossing point (at x=c+-1)
	// should be the determining factor for key `dropoff' points, it would
	// make sense to figure out the average dropoff point determined by
	// `note_span' and compute a bell curve (with respect to the `freqs'
	// vector) for each key frequency such that:
	//	* the peak lies at the place in `freqs' most similar to the
	//	  note's frequency (this eliminates the guesswork associated
	//	  with stepping through the frequency array and comparing
	//	  values.
	//	* the curve (though symmetric) is scaled with respect to x in
	//	  such a way that the exponent-independent common point is equal
	//	  to the average of the distances (in Hz, mind you) dictated by
	//	  the function
	//		s[n] = ( abs( N[n]-N[n-1] ) * note_span[1] / 2 +
	//			abs( N[n]-N[n+1] ) * note_span[2] / 2 ) / 2
	//
	//	where N is a vector of all the key frequencies
	//
	//	let's get to it

	for key_ind = 2 : (total_keys + 1)
		// how far to scale the curve (rtfm if you don't understand)
		s = (abs(all_key_defs(key_ind) - all_key_defs(key_ind - 1)) * ..
				note_span(1) / 2 + ..
			abs(all_key_defs(key_ind)-all_key_defs(key_ind+1))) / 2;

		// the center should appear exactly on our key frequency
		c = all_key_defs(key_ind);

		// TODO: add the other arguments to bell_curve to our parameters
		bc = bell_curve(freqs, s=s, c=c)

		// FIXME: figure out how to add the curve to our matrix
	end

	// TODO: (load, verify, backup, save) matrix; compute the key amplitudes
	// TODO: let the user select how we want to do this

