function [zc]=zerocrossings(clipdata, sampling_rate)
// finds the number of zerocrossings per second in each row of a nxm matrix
//
// characterized by the function:
//  N
// ---
// \
//  \  abs(sign(x[n]) - sign(x[n-1]))
//  /  ------------------------------
// /                 2
// ---
// n=1
//
// Arguments:
//	clipdata:	nxm matrix, the zerocrossings (sign changes) of each row
//				will be computed.
//	sampling_rate:  (optional) samples per second. Default is 44100.
//				Note: to get bare number of zerocrossings, use
//				a sampling rate of 0.
//
// Returns a nx1 vector of number of zerocrsooings per second in each row of
//	clipdata.
//
// Version: 1.0b
//!
// Part of project Audicon by Dan Church <daniel.church@uwrf.edu>

	// load defaults if necessary & correct floating-point badness
	for a = [ 'sampling_rate' ]
		if ~exists(a, 'local')
			execstr(a + '=audicon_defaults(a)');
		end
	end
	sampling_rate = int(abs(sampling_rate));

	// minimize arduous function calls
	num_clips = size(clipdata, 'r');
	num_samples = size(clipdata, 'c');

	zc(num_clips) = 0; // initialize vector to all zeroes

	for clip = 1 : num_clips
		for samp = 2 : num_samples
			zc(clip) = zc(clip) + abs(sign(clipdata(clip, samp)) ..
				- sign(clipdata(clip, samp - 1))) / 2;
		end
	end

	// make sure we're not dividing by zero
	if sampling_rate
		// divide by number of seconds to get zerocrossings per second
		//
		//                   second           num_samples samples
		// duration = --------------------- * -------------------
		//            sampling_rate samples          clip
		duration = num_samples / sampling_rate;
		zc = zc / duration;
	end
endfunction
