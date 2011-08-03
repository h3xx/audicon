function [tid]=pvm_next_idle(group_name, stat_group, stat_listen, stat_send)
// queries the `stat' daemon and gets the first-idle or least-busy tid. If no
// `stat' daemons are running, it selects a random tid from the groups
// specified. If there's nobody in the group(s) specified, returns an empty
// vector ([]).
//
// Does NOT return until it finds something.
//
// Arguments:
//	group_name:	(optional) character string (or vector thereof) group
//				names to search
//	stat_group:	(optional) character string group name to which to
//				broadcast one's status (idle/busy). Default is
//				`status'.
//	stat_listen:	(optional) integer message tag on which status daemon(s)
//				is/are listening for status changes & queries.
//				Default is 1.
//	stat_send:	(optional) integer message tag to which `stat' daemons
//				will send their query data. Default is 11.
//
// Returns a single integer tid of the response from the `stat' daemon
//
// Version 1.0a
//!
// Part of project Audicon by Dan Church <daniel.church@uwrf.edu>

	// load defaults if necessary
	for a = [ 'stat_group' 'stat_listen' 'stat_send' ]
		if ~exists(a, 'local')
			execstr(a + '=audicon_defaults(a)');
		end
	end

	// make sure there's a `stat' daemon running
	if pvm_gsize(stat_group) > 0
		// construct query
		send = 'q';
		if exists('group_name', 'local')
			send = [ send group_name ];
		end
		// send query
		pvm_bcast(stat_group, send, stat_listen);
		// wait for response (-1 => from any tid)
		tid = pvm_recv(-1, stat_send);
	else
		warning('pvm_next_idle(): no running stat daemons; using ' + ..
			'random member of group `' + string(group_name) + '''');
		// get list of all members of the group(s)
		group_tids = pvm_get_group_tids(group_name);
		group_size = size(group_tids, '*');
		if group_size
			// there's someone in the group; select a random member
			tid = group_tids(int(rand() * group_size) + 1);
		else
			// nobody in the group(s)
			tid = [];
		end
	end
		

endfunction
