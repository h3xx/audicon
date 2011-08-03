function [i]=wrap_to_range(i, mx, mn)
// wraps integers to fall within the range [ mn mx ]
//
// A practical application of this is to force boundaries of indices to a vector
// of size equal to `mx'.
//
// Arguments:
//	i:		the vector of intengers to be wrapped
//	mx:		the maximum any of the integers can take
//	mn:		(optional) the minimum value any of the integers can
//				take. Default is 1.
//
// Returns a vector of indices `i' such that
// 	min(i) == mn
//	max(i) == mx
//
// Version 1.0
//!
// Part of project Audicon by Dan Church <daniel.church@uwrf.edu>

	if ~exists('mn', 'local')
		mn = 1;
	end

	i = modulo(modulo(i - mn, mx) + mx, mx - mn) + mn + 1;
endfunction
