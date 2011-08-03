function [t]=pvm_get_group_tids(group_name)
// returns a row-vector of the integer tids of every process in the given
// group(s)
//
// Arguments:
//	group_name:	character string (or vector thereof) group names to look
//				up
//
// Returns a sorted list (without duplicates) of all the tids in the group
// name(s) specified.
//!
// Part of project Audicon by Dan Church <daniel.church@uwrf.edu>

	// apparently if a member leaves a group, the group does not
	// self-compact, so we have to do this by the global list of all
	// tids and not by instance -> group size

	t = [];
	all_tids = pvm_get_tids(); // save some function calls

	// cycle through group names
	for g = group_name
		// get instances of this group (<0 for error)
		instances = [];
		for s = all_tids
			instances = [ instances pvm_getinst(g, s) ];
		end

		// toss errors & look up instances
		for i = instances(find(instances > -1))
			t = [ t pvm_gettid(g, i) ];
		end
	end

	// toss duplicates (also sorts list)
	t = unique(t);

endfunction
