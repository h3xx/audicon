function [h]=pvm_get_remote_hosts()
// returns a row vector of integers describing all the hosts configured,
// NOT including your own.
//
// This function was created basically so I didn't have to remember how to do
// this in the future.
//
//!
// Part of project Audicon by Dan Church <daniel.church@uwrf.edu>

	h = pvm_get_hosts();
	h = h(find(h ~= pvm_my_host_tid()));
endfunction
