function [data]=normalize(data, maxvalue)
// normalizes a matrix of data to fall within a given range
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
//
// Returns the normalized vector.
//
// Version: 1.0
//!
// Part of project Audicon by Dan Church <daniel.church@uwrf.edu>

	// load defaults if necessary
        if ~exists('maxvalue', 'local')
                maxvalue = 1;
	else
		maxvalue = abs(maxvalue);
	end

	// call function to get what we need to multiply `data' by
	nc = normalization_coeff(data, maxvalue);

	// max * x = 'max allowed value'
	data = data * nc;

endfunction
