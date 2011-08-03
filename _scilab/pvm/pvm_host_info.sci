function [name, arch, speed, err]=pvm_host_info(hosttid)
// figures out information about a given host tid
//
// This function was created basically so I didn't have to remember how to do
// this in the future.
//
//!
// Part of project Audicon by Dan Church <daniel.church@uwrf.edu>

	cfg = pvm_config();

	hosts = cfg(3);

	// find index of matching host
	m = find(hosts==hosttid);

	name = cfg(4);
	name = name(m);

	arch = cfg(5);
	arch = arch(m);

	speed = cfg(6);
	speed = speed(m);

	err = cfg(7);
endfunction
