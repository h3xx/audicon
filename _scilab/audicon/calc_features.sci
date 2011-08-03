function [o]=calc_features(fcns, sampling_rate, curr_clip, curr_tex, ..
	prev_clip, prev_tex, next_clip, next_tex)
// calculates all features on a given set of clip data & collates the output
//
// If you're going to use this to process multiple clips at once, have the
// decency to ensure that the inputs all have the same number of rows. And make
// sure the function calls passed in can handle it.
//
//
// Arguments:
//	FIXME: arguments stub
//
// Returns FIXME: return stub
//!
// Part of project Audicon by Dan Church <daniel.church@uwrf.edu>

	// load defaults if necessary & correct floating-point badness
	for a = [ 'fcns' 'sampling_rate' ]
		if ~exists(a, 'local')
			execstr(a + '=audicon_defaults(a)');
		end
	end

	sampling_rate = int(sampling_rate);

	// run each function
	o = [];
	for f = fcns
		// append each function's output to the output vector
		o = [ o evstr(f) ];
	end
		
endfunction
