function [changes]=delta_from_right(fftdata)
// helper function in determining peaks; finds changes in amp from the freq bin
// to the right.
//
// Part of project Audicon by Dan Church
	fftdata = abs(fftdata); // just to make sure
	sz = size(fftdata, 2) - 1; // number of input bins to go
	data(sz+1) = fftdata(sz+1); // amp of bin past last bin is always 0
	// XXX
	// now, take the current set of bins and subtract the bin to the left,
	// getting change (delta) from left to current
	data(2:sz) = fftdata(2:sz) - fftdata(1:(sz-1));
	// data should be of size 1 x size [cols] of fftdata
endfunction
