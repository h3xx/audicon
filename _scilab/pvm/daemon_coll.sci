function daemon_coll(coll_group, coll_listen, kill_listen, kill_msg, ..
		wait_time, datadir, save_size)
// FIXME: description stub
//
// When the kill signal is received, the daemon runs through any remaining data
// in the buffer from PVM, then exits.
//
// Arguments:
//	FIXME: arguments stub
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
	for a = [ 'coll_group' 'coll_listen' ..
			'kill_listen' 'kill_msg' 'wait_time' 'datadir' ]
		if ~exists(a, 'local')
			execstr(a + '=audicon_defaults(a)');
		end
	end

	// join our group (so as to receive broadcasts)
	pvm_joingroup(coll_group);

	// helps coordinate our save buffer names
	save_ext = 0;
	save_ind = 1;
	save_buff = list();

	// this gets set after we receive the kill signal on the appropriate
	// message tag & then run through any waiting data from PVM
	exiting = %f;

	// helps coordinate when to exit
	received_kill = %f;

	while ~exiting
		// wait for next buffer from PVM (-1 => from any tid)
		// this gives a faster response time than probing and waiting
		[ data err tid tag ] = pvm_recv(-1, -1);

		select tag
		case proc_listen // received data to process
			// we actually got something from pvm
			if save_ind > save_size
				// buffer's full; time to dump it to file
				save(sprintf("%s/%s.sav%d", ..
					datadir, coll_group, save_ext), ..
					save_buff);
				save_buff = list();
				save_ind = 1;
				save_ext = save_ext + 1;
			else
				// append to buffer
				save_buff(save_ind) = data;
				save_ind = save_ind + 1;
			end
			

		case kill_listen // received (potential) kill signal
			if data == kill_msg & status_reported ~= 'x'
				// kill signal confirmed
				// exit from pvm group so as to not receive any
				// more data from broadcasts
				pvm_lvgroup(proc_group);
				// request that the `stat' daemons take us off
				// their lists so we can run through any waiting
				// data without it piling up any further
				pvm_bcast(stat_group, 'x', stat_listen);
				status_reported = 'x';
				received_kill = %t;

				// figure out just who killed us
				[ name arch speed ] = pvm_host_info( ..
					pvm_tidtohost(tid));
				// warn the user that we're going down
				warning(sprintf('daemon_coll(): received ' + ..
					'kill from tid %d (%s/%s; %d)', ..
					tid, name, arch, speed));
			end
		end // if it's not on those two message tags, ignore it

		// check to see whether we have more data to process
		more_data = pvm_probe(-1, proc_listen);
			
		// check to see if it's okay to exit
		if received_kill & ~more_data
			// no more data; clear to exit
			exiting = %t;
		end

	end

	// time to exit
	// we've already exited from the group & run through all waiting data,
	// so just tell the user that we're exiting
	warning('daemon_coll(): exiting');

endfunction
