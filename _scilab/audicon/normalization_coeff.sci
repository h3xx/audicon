function [nc]=normalization_coeff(data, maxvalue, wb)
// finds the coefficient needed to multiply each value in data by, so that the
// absolute value of the range of all the members is [ -maxvalue maxvalue ].
//
// This is meant to be a pre-processor on the sample data of wav files.
//
// Arguments:
//	data:		the matrix of values to be normalized. Alternately, one
//				may specify the character-string file name of
//				a PCM wav file and its normalization coefficient
//				will be found (independent of channels).
//	maxvalue:	(optional) the maximum absolute value the normalized
//				vector should have. Default is 1.
//	wb:		(optional) integer winId of a waitbar (see `waitbar()'
//				manual page). Progress will be updated as
//				needed. If none specified, this feature is
//				disabled.
//
// Returns the scalar value that, when multiplied to the data matrix, will cause
// `max(abs(data))' to equal `maxvalue'.
//!
// Part of project Audicon by Dan Church <daniel.church@uwrf.edu>

	if ~exists('maxvalue', 'local')
		maxvalue = 1;
	else
		maxvalue = abs(maxvalue);
	end

	// save a little CPU time
	uw = exists('wb', 'local');

	// support wav file name as argument
	if typeof(data) == 'string'
		// user specified a wav file
		// to save memory, let's step through it instead of loading it
		// all at once.

		// number of samples to read at once (reading them one at a time
		// is a very cpu-consuming process)
		buffer_size = 2^20;

		// initialize the maximum found so far
		maxfound = 0;

		// sample span of 0 causes report of wav information
		// [ channels samples ]
		sz = wavread(data, 0);
		sz = sz(2);

		for sample_ind = 1 : buffer_size : sz
			// the last index we're going to read
			// (which comes first -- the end of the buffer or the
			// end of the file?)
			last_samp = min([ sample_ind + buffer_size sz ]);

			local_max = max(abs(sum(wavread(data, [ sample_ind ..
						last_samp ]), 'r')));

			// this is pretty damn self-explanitory
			if local_max > maxfound
				maxfound = local_max;
			end

			// update waitbar (if specified)
			// last sample read / total # of samples
			if uw
				waitbar(last_samp / sz, wb);
			end
		end

	else
		// user specified their own data to normalize
		maxfound = max(abs(data));
	end

	// so, we've found the max value in the target dataset (`maxfound')

	// maxfound * nc = maxvalue
	nc = maxvalue / maxfound;

endfunction
