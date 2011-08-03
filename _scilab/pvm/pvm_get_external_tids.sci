function [t]=pvm_get_external_tids()
// returns a row vector of integers describing all the task ids (tids) on all
// the hosts configured, including your own, but not containing the same tid as
// the calling process.
//
// This function was created basically so I didn't have to remember how to do
// this in the future.
//
//!
// Part of project Audicon by Dan Church <daniel.church@uwrf.edu>

	t = pvm_get_tids();
	t = t(find(t ~= pvm_mytid()));
endfunction
