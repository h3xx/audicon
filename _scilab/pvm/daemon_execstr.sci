function daemon_execstr(execstr_group, execstr_listen, execstr_send, ..
	kill_listen, kill_msg, wait_time)
// runs as a kind of dimwitted daemon, executing every string sent to it from
// the PVM network.
//
// This was created honestly as a sort of misguided test of PVM.
//
// TODO: catch errors in executed strings; as of right now, this daemon is very
// fragile in that regard
//
// Arguments:
//	execstr_group:	(optional) character string group name that this daemon
//				process will join (and leave when the kill
//				signal is received). This makes classifying
//				running daemon processes much easier. Default
//				is `dimwits'.
//	execstr_listen:	(optional) integer message tag on which this daemon
//				process will listen for incoming data. Default
//				is 9.
//	execstr_send:	(optional) integer message tag to which this daemon
//				process will send back the variable `send' (if
//				it was set when the incoming string(s)
//				executed). Default is 19.
//	kill_listen:	(optional) integer message tag on which to listen for
//				the kill signal. Default is 101.
//	kill_msg:	(optional) character string message to listen for. When
//				received, the daemon leaves its group and exits.
//				Default is defined in `audicon_defaults'.
//	wait_time:	(optional) integer number of milliseconds to wait
//				between	unfruitful probes of the receive
//				buffers. Default is 1000 (1 second).
//
// Version 1.0a
//!
// Part of project Audicon by Dan Church <daniel.church@uwrf.edu>

	// load defaults if necessary
	for a = [ 'execstr_group' 'execstr_listen' 'execstr_send' ..
			'kill_listen' 'kill_msg' 'wait_time' ]
		if ~exists(a, 'local')
			execstr(a + '=audicon_defaults(a)');
		end
	end

	pvm_joingroup(execstr_group);

	// this gets set when we receive the kill signal on the appropriate
	// message tag
	time_to_exit = %f;

	while ~time_to_exit
		// get next waiting buffer
		[ data tid ] = pvm_next_buff(execstr_listen);

		// if we actually got something from pvm, execute it
		if tid
			// so we have a fresh start
			clear send;

			[ name arch speed ] = pvm_host_info(pvm_tidtohost(tid));
			desc = sprintf('%s/%s; %d', name, arch, speed);

			if typeof(data) == 'string'
				// (you can break the program this way...
				// but don't tell anyone)
				warning(sprintf('daemon_execstr(): ' + ..
					'executing string `%s'' ' + ..
					'from tid %d (%s)', data, tid, desc));
				execstr(data);
			else
				warning(sprintf('daemon_execstr(): ' + ..
					'cannot execute non-string ' + ..
					'(type: `%s'') from tid %d (%s)', ..
					typeof(data), tid, desc));
			end

			// I guess you can't sent function pointers through the
			// inter-process mail. pity.
			//elseif typeof(data) == 'fptr'
			//	data();
			//end

			// if the user set `send' in the string we executed,
			// send it back to them
			if exists('send', 'local')
				pvm_send(tid, send, execstr_send);
			end
		else
			// nothing caught; let the wires sleep
			sleep(wait_time);
		end

		// should we exit yet?
		[ time_to_exit killed_by ] = pvm_have_exit(kill_listen, ..
				kill_msg);
	end

	// i guess it's time to exit
	// figure out just who killed us
	[ name arch speed ] = pvm_host_info(pvm_tidtohost(killed_by));

	// warn the user that we're going down
	warning(sprintf('daemon_execstr(): killed by tid %d (%s/%s; %d)', ..
			killed_by, name, arch, speed));

	// exit from the group
	pvm_lvgroup(execstr_group);
endfunction
