function [changes]=delta_from_left(fftdata)
// helper function in determining peaks; finds changes in amp from the freq bin
// to the left.
//
// Part of project Audicon by Dan Church
	fftdata = abs(fftdata); // just to make sure
	data(1) = fftdata(1); // amp of 0-freq wav is always 0
	sz = size(fftdata, 2) - 1; // number of input bins to go
	// now, take the current set of bins and subtract the bin to the left,
	// getting change (delta) from left to current
	data(2:sz) = fftdata(2:sz) - fftdata(1:(sz-1));
	// data should be of size 1 x size [cols] of fftdata
endfunction
