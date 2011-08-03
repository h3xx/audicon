function [c]=pvm_send_kill(to_whom, kill_listen, kill_msg)
// sends the 'kill' signal to a tid or group of tids.
//
// Arguments:
//	to_whom:	integer or character string (or vector thereof)
//				describing any one of the following:
//				* the target tid(s) (integers)
//				* the tid(s) (integers) of the host(s) on which
//				  the process is running. These are unique from
//				  the tids of the individual processes.
//				* the group name(s) (character strings). Beware,
//				  as this sends the kill signal to every member
//				  of the group(s).
//	kill_listen:	(optional) integer message tag on which daemons are
//				listening for the kill signal. Default is 101.
//	kill_msg:	(optional) character string message daemons are
//				listening for. Default is defined in
//				`audicon_defaults'.
//
// Returns the number of hosts to whom the kill signal was sent.
//
// Version 0.1b
//!
// Part of project Audicon by Dan Church <daniel.church@uwrf.edu>

	// load defaults if necessary
	for a = [ 'kill_listen' 'kill_msg' ]
		if ~exists(a, 'local')
			execstr(a + '=audicon_defaults(a)');
		end
	end


	if typeof(to_whom) == 'string'
		// killing an entire group
		// we can save time by broadcasting the message

		c = 0; // none killed yet
		// support lists of groups
		for grp = to_whom(:)'
			gs = pvm_gsize(grp)
			if gs > 0
				pvm_bcast(grp, kill_msg, kill_listen);
				c = c + gs;
			end
		end

	elseif typeof(to_whom) == 'constant'
		// killing tids OR hosts full of tids

		// retrieve list from pvm
		tasks = pvm_tasks();

		tids = tasks(1);
		hosts = tasks(3);

		// support lists
		targets = [];
		for tid = to_whom(:)'
			targets = [ targets tids([ find(tids == tid) ..
				find(hosts == tid) ]) ];
		end

		// make sure we don't send the kill signal twice to one tid
		targets = unique(targets);
		c = size(targets, '*'); // (for returnind)
		pvm_send(targets, kill_msg, kill_listen);

	end

endfunction
