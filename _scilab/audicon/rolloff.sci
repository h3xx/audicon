function [ro]=rolloff(clipdata, ro_concentration, sampling_rate)
// finds the spectral rolloff for each of the given clips
//
// The spectral rolloff is based on the weighted (amplitude * frequency) output
// of the fast Fourier transform (FFT) and is defined as the minimum frequency
// R, such that the following equasion is true:
//
//  R                               N
// ---                             ---
// \                               \
//  \ M[f] >= (ro_concentration) *  \ M[f]
//  /                               /
// /                               /
// ---                             ---
// f=1                             f=1
//
// where M[f] is the weighted amplitude of the fft frequency bin corresponding
// to frequency f, N is equal to the total number of frequency bins, and
// ro_concentration is the second argmuent passed in (default is 0.85).
//
// Arguments:
//	clipdata:	nxm matrix, the spectral rolloff of the waveform
//				described on each row will be computed
//	ro_concentration: (optional) the value to be applied in the above
//				formula. I.E. what fraction of the total
//				spectral magnitude will	determine where the
//				frequency rolloff point is? Default is 0.85 (or
//				85%).
//				Note: this value should be between 0 and 1.
//
// Returns a column-vector of the computed spectral rolloff of each row defined
// in `clipdata'.
//!
// Part of project Audicon by Dan Church <daniel.church@uwrf.edu>

	// load defaults if necessary & correct floating-point badness
	for a = [ 'ro_concentration' 'sampling_rate' ]
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
		// get weighted fft
		amps = amps .* freqs;

		// compute target magnitude
		target = ro_concentration * sum(amps);

		num_freqs = size(freqs, 'c');
		ro_sum = 0;
		f = 1;
		while f <= num_freqs & ro_sum <= target
			ro_sum = ro_sum + amps(f);
			f = f + 1;
		end

		// check whether the function works
		if f == num_freqs
			warning('rolloff(): didn''t reach target');
		end

		// add rolloff to output vector
		ro(clip_ind) = freqs(f);
	end

endfunction
