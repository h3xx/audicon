function [cn]=centroid(clipdata, sampling_rate)
// computes the fentroid feature of the given set of clips
//
// Based on the unweighted output of the fast Fourier transform (FFT) and
// characterized by the function
//
//  N
// ---
// \
//  \ f * M[f]
//  /
// /
// ---
//  f
// -----------
//  N
// ---
// \
//  \ M[f]
//  /
// /
// ---
//  f
//
// where N is the highest frequency bin, f is the frequency & M[f] is the
// unweighted amplitude of the fft bin corresponding to frequency f.
//
//
// Centroid is a measure of spectral brightness.
//
// Arguments:
//	clipdata:	nxm matrix, the centroid of each row will be computed
//	sampling_rate:	(optional) samples per second. Default is 44100.
//
// Returns a nx1 vector of computed centroids of each row of clipdata.
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

	for clip_ind = 1 : num_clips
		[amps freqs] = fft_unweighted(clipdata(clip_ind, :), ..
			sampling_rate);

		cn(clip_ind) = sum(freqs .* amps) / sum(amps);
	end
endfunction
