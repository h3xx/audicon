function [flux]=spectral_flux(clipdata, sampling_rate)
// computes spectral flux of each row in clipdata
//
// Spectral flux is defined as the squared difference between the normalized
// magnitudes of successive spectral distributions.
//
// characterized by the function:
//  N
// ---
// \
//  \  (N(t)[n] - N(t-1)[n])^2
//  /
// /
// ---
// n=1
//
// where N(t)[n] and N(t-1)[n] are the normalized magnitude of the Fourier
// transform at the current frame # t, and previous frame # t-1, respectively.
//
// Since this function is not mutually exclusive across clips, and I want to
// include information about EVERY clip sent, the matrix of clip data will be
// thought of internally as a circular buffer. I.E. the flux value of the first
// clip will be the flux from the last clip to the first clip.
//
// Arguments:
//	clipdata:	nxm matrix, the spectral flux of each row will be
//				computed. For meaningful output this must have
//				more than one row.
//	sampling_rate:  (optional) samples per second. Default is 44100.
//				Note: to get bare number of zerocrossings, use
//				a sampling rate of 0.
//
// Returns a nx1 vector of the sum of the magnitudes of changes across the
// (unweighted) spectrum-distributions from the previous frame to the current.
//
// Version: 0.1a
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

	// complete the circle (I.E. take flux from last to first clip)
	amps = fft_unweighted([ clipdata(num_clips, :) ; ..
			clipdata(1, :) ], sampling_rate);
	z = amps(1, :) - amps(2, :);
	flux(1) = sum(z .* z);

	// process clips as normal (flux from previous clip to current)
	for clip_ind = 2 : num_clips
		amps = fft_unweighted([ clipdata(clip_ind - 1, :) ; ..
			clipdata(clip_ind, :) ], sampling_rate);
		z = amps(1, :) - amps(2, :);
		flux(clip_ind) = sum(z .* z);
	end
endfunction
