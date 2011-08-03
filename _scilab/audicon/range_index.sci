function [r]=range_index(i)
// simplifies a vector of consecutive indices into their component ranges
//
// for example the ranges on the vector [ 4 5 6 1 2 3 ] would be:
// [ 4 1 ]
// [ 6 3 ]
//
// Arguments:
//	i:	a vector of indices
//
// Returns a 1xn matrix of the simplified ranges.
//!

	r = [ i(1); i(1) ];
	i(1) = [];
	cc = 1;
	for ind = i
		if r(2, cc) + 1 == ind
			r(2, cc) = r(2, cc)+ 1;
		else
			cc = cc + 1;
			r(:, cc) = ind;
		end
	end
endfunction
