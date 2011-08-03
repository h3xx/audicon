function [h]=pvm_my_host_tid()
// gets the task id (tid) of the host on which this function is run
//
// This function was created basically so I didn't have to remember how to do
// this in the future.
//
//!
// Part of project Audicon by Dan Church <daniel.church@uwrf.edu>

	h = pvm_tidtohost(pvm_mytid());
endfunction
