function [r]=magnitude_ratio(clipdata, texdata, sampling_rate)
// defined as the magnitude (amplitude * frequency) of the clip divided by the
// magnitude of the texture frame
//
// Arguments:
//	clipdata:	real-number wav clip data, each sample defined on a
//				different row
//	texdata:	real-number wav texture frame data, each sample defined
//				on a different row. This should have the same
//				number of rows as `clipdata.'
//	sampling_rate:	(optional) samples per second. Default is 44100.
//
//
// Returns a column vector of the ratio of magnitudes.
//
// Version 1.0b
//!
// Part of project Audicon by Dan Church <daniel.church@uwrf.edu>

	// load default variables if necessary
	for a = [ 'sampling_rate' ]
		if ~exists(a, 'local')
			execstr(a + '=audicon_defaults(a)');
		end
	end

	// this should be relatively simple

	num_clips = size(clipdata, 'r');

	// get fft output (freqs only has one row)
	[ t_amps t_freqs ] = fft_unweighted(texdata, sampling_rate);
	[ c_amps c_freqs ] = fft_unweighted(clipdata, sampling_rate);

	// gotta love that matrix math!
	r = (c_amps * c_freqs') ./ ..
		(t_amps * t_freqs');
endfunction
