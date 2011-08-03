function [t]=pvm_get_remote_tids()
// returns a row vector of integers describing all the task ids (tids) on all
// the hosts configured, NOT including your own.
//
// This function was created basically so I didn't have to remember how to do
// this in the future.
//
//!
// Part of project Audicon by Dan Church <daniel.church@uwrf.edu>

	t = [];

	for h = pvm_get_remote_hosts()
		p = pvm_tasks(h);
		t = [ t p(1) ];
	end
endfunction
