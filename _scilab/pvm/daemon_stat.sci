function daemon_stat(stat_group, stat_listen, stat_send, kill_listen, ..
		kill_msg, show_warnings)
// keeps records of which daemon processes are busy or idle, and also is used by
// distributor processes to determine the best daemon for the job.
//
// This should be the first daemon started.
//
// "Best daemon for the job" is determined by:
//	A. daemon that has been idle the longest
//	B. if no daemons are idle, select the one that has the least number of
//		jobs pending
//
// Buffers received from PVM must be character string arrays of the following
// format:
//
// recv(1)	(	'q'	query tid of idle server
//			'l'	get lists of servers
//			'i'	set sending tid's status as `idle'
//			'b'	set sending tid's status as `busy'
//			'x'	exit sending tid from the queue
//		)
// recv(2:?)	(optional: character string group name; can be a vector of them)
//
// Specifying recv(2) limits the search to that group. This is ignored if
// recv(1) is 'a' or 'b'.
//
// If recv(1) is 'l', this daemon sends a buffer with the following structure:
// send	=>	idle	(integer vector of tids currently marked `idle')
// 		busy	(integer vector of tids currently marked `busy')
//
// If the received buffer does not meet the requirements, it is ignored. (Sorry,
// but you're going to have to code more carefully)
//
// Arguments:
//	stat_group:	(optional) character string group name that this daemon
//				process will join (and leave when the kill
//				signal is received). This makes classifying
//				running daemon processes much easier. Default
//				is `status'.
//	stat_listen:	(optional) integer message tag on which this daemon
//				process will listen for incoming data. Default
//				is 1.
//	stat_send:	(optional) integer message tag to which this daemon
//				will send its query data (if `recv(1)' is
//				'q' or 'l'). Default is 11.
//	kill_listen:	(optional) integer message tag on which to listen for
//				the kill signal. Default is 101.
//	kill_msg:	(optional) character string message to listen for. When
//				received, the daemon leaves its group and exits.
//				Default is defined in `audicon_defaults'.
//	show_warnings:	(optional) boolean whether to show warning messages.
//				Beware when allowing them, as Scilab will pause
//				and ask "[More (y or n) ?]" after each
//				screenful of text. Default is %f (no warnings).
//
// Version 1.0a
//
// This daemon cannot be tested until Scilab fixes their `pvm_recv' function
//!
// Part of project Audicon by Dan Church <daniel.church@uwrf.edu>

	// load defaults if necessary
	for a = [ 'stat_group' 'stat_listen' 'stat_send' ..
			'kill_listen' 'kill_msg' 'show_warnings' ]
		if ~exists(a, 'local')
			execstr(a + '=audicon_defaults(a)');
		end
	end

	// join our group (so as to receive broadcasts)
	pvm_joingroup(stat_group);

	// initialize vectors of idle / busy tids
	idle = [];
	busy = [];

	// this gets set when we receive the kill signal on the appropriate
	// message tag
	received_kill = %f;
	// helps coordinate when to exit
	exiting = %f;

	while ~exiting
		// wait for next buffer from PVM (-1 => from any tid)
		// this gives a faster response time than probing and waiting
		[ data err tid tag ] = pvm_recv(-1, -1);

		// delineate types of messages by their tag
		select tag
		case stat_listen // received something to do

			if typeof(data) == 'string'
				// shortcut for group-limited tid lists
				ds = size(data, '*'); // save on function calls
				if ds > 1
					// user specified group(s)
					limit_to = pvm_get_group_tids(..
						data(2 : ds));
				else
					// no group specified; limit to everyone
					limit_to = union(idle, busy);
				end

				select data(1)
				case 'q' // `query': first-idle or least-busy
					// figure out from where we're pulling
					// our data
					// basically, set `sf' to the name of
					// the first non-empty tid vector
					o = [ 'idle' 'busy' ];
					sf = o(min(find([ size(idle, 'c'), ..
							size(busy, 'c') ])));
					// pull the named vector out of our
					// variable namespace
					sfd = evstr(sf);

					// limit the list we send by what we
					// chose as the limiter (`limit_to' is
					// either the vector of tids in the
					// group specified by the incoming data
					// buffer, or is a list of everyone
					// we've heard from if no group
					// specified)
					[ g i ] = intersect(sfd, limit_to);
					send = sfd(min(i));

					// rotate stock (cleans up duplicates
					// as well)
					execstr(strsubst('% = [ %(find(% ' + ..
						'~= send)) send ];', '%', sf));

					// send response
					pvm_send(tid, send, stat_send);
					warn_msg = sprintf('reporting ' + ..
						'`%d'' (from list `%s'') ' + ..
						'to tid %d', send, sf, tid);
				case 'l' // `list': report what we know
					// just retrieve a list of the idle tids
					// limited by group
					[ g ii ] = intersect(idle, limit_to);
					[ g bi ] = intersect(busy, limit_to);
					send.idle = idle(ii);
					send.busy = busy(bi);

					// send response
					pvm_send(tid, send, stat_send);
					warn_msg = sprintf('sending list ' + ..
						'of idle/busy tids to %d ' + ..
						'(%d members)', ..
						tid, size(send, '*'));
				case 'i' // `idle': mark sender idle
					// mark this tid idle (if it hasn't
					// already been marked)
					idle = [ idle(find(idle ~= tid)) tid ];
					warn_msg = sprintf('tid %d marked ' + ..
						'as `idle''', tid);
				case 'b' // `busy': mark sender busy
					// mark this tid busy (if it hasn't
					// already been marked)
					busy = [ busy(find(busy ~= tid)) tid ];
					warn_msg = sprintf('tid %d marked ' + ..
						'as `busy''', tid);
				case 'x' // `exit': delete sender from lists
					// this tid wants to exit from our
					// stacks
					idle = [ idle(find(idle ~= tid)) ];
					busy = [ busy(find(busy ~= tid)) ];
					warn_msg = sprintf('tid %d ' + ..
						'exited from queues', tid);
				else
					warn_msg = sprintf('invalid ' + ..
						'request: `%s'' tid: %d', ..
						data(1), tid);
				end

			else
				// got strange output 
				warn_msg = sprintf('malformed request ' + ..
					'(expected type `string'', got ' + ..
					'type `%s''; offending tid: %d', ..
					typeof(data), tid);
			end

		case kill_listen // received (potential) kill signal
			if data == kill_msg
				// kill signal confirmed
				// exit from pvm group so as to not receive any
				// more data from broadcasts
				pvm_lvgroup(proc_group);
				received_kill = %t;

				// figure out just who killed us
				[ name arch speed ] = pvm_host_info( ..
					pvm_tidtohost(tid));
				// warn the user that we're going down
				warning(sprintf('daemon_stat(): received ' + ..
					'kill from tid %d (%s/%s; %d)', ..
					tid, name, arch, speed));
				// clear any previous warning message
			end
		end // if it's not on those two message tags, ignore it

		// print out generated error message
		if show_warnings & exists('warn_msg', 'local')
			warning('daemon_stat():' + warn_msg);
		end

		// check to see whether we have more data to process
		more_data = pvm_probe(-1, stat_listen);

		// check to see if it's okay to exit
		if received_kill & ~more_data
			// no more data; clear to exit
			exiting = %t;
		end

	end

	// we've already exited from the group, so just tell the user that we're
	// exiting
	warning('daemon_stat(): exiting');

endfunction
