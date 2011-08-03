function [amps, freqs]=fft_unweighted(clipdata, sampling_rate)
// gives a representation of the fast Fourier transform that is 'unweighted' &
// 'squelched,' plus the vector of associated frequencies for each clip.
//
// This function takes into account that when:
// dataset is a set of points of length n, a representation of a sine wave that
// cycles x times within the dataset and has an amplitude of a,
// abs(real(fft(dataset))) will produce the following:
//
//   |                     .
// z |          .    <-symmetric->    .
//   |          |          .          |
//   |          |          .          |
//   |          |          .          |
//   |          |          .          |
// 0 |---------/ \---------.---------/ \-------------
//   +--------(x+1)--------.-------(n-x+1)----------n
// where z is equal to x * a * %pi
//
// Thus, if you add a bunch of waves with different frequencies and the same
// amplitude, the fft() output would look like the waves with higher frequencies
// had a higher amplitude, which they don't. That, ladies and gentlemen, is why
// I created this function.
//
// Arguments:
//      clipdata:	nxm matrix, raw waveform data of each clip to be
//				processed row-by-row.
//				Should be normalized -- see normalize().
//	sampling_rate:	(optional) samples per second. Default is 44100.
//
// Returns two vectors:
//	amps:		matrix of absolute (unweighted) amplitudes of all waves
//				composing the sample data of each clip. Each
//				clip processed is contained on a different row.
//				These values should translate DIRECTLY to
//				coefficients on subordinate waveforms.
//	freqs:		vector of associated frequencies.
//
// amps(clip_index, n) is the amplitude of wave with freqs(n)
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

	// size of output in frequency bands
	num_bins = size(clipdata, 'c') / 2;
	// minimize arduous function calls
	num_clips = size(clipdata, 'r');

	// associated vector of frequencies
	freqs = sampling_rate * (0 : (num_bins - 1)) / num_bins / 2;

	for clip_ind = 1 : num_clips
		clip_fft = abs(real(fft(clipdata(clip_ind, :))));

		// Transform to unweighted vector of absolute amplitudes.
		// Believe it or not this code is very coherent and based on
		// days of trial and error.
		amps(clip_ind, :) = [ 0 ..
				clip_fft(2 : num_bins) ./ ..
				(1 : (num_bins - 1)) / %pi ];
	end

	// DEBUG
	// bah! if they want a specific amplitude, they can always normalize it
	//if max(amps) > 1
	//	disp('uh-oh!');
	//end
	// END DEBUG

endfunction
