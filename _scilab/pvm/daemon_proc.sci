function daemon_proc(proc_group, proc_listen, coll_group, coll_listen, ..
	stat_group, stat_listen, kill_listen, kill_msg)
// daemon that accepts wav file splits as input and processes the audio feature
// extraction portion of audicon, then sends (broadcasts) the processed data to
// the group of collectors.
//
// Buffers received from PVM must be structs of of the following format:
//
// buff(n)=>	sampling_rate	(integer)
//		fcns		(character string vector)
//		curr_clip	(row vector of doubles)
//		prev_clip	(row vector of doubles)
//		next_clip	(row vector of doubles)
//		curr_tex	(row vector of doubles)
//		prev_tex	(row vector of doubles)
//		next_tex	(row vector of doubles)
//		genre		(character string)
//		filename	(character string)
//
// Passing a struct array of that format is also acceptable.
//
// Data passed to collection daemons is a struct of the following format:
//
// send(n)=>	features	(row vector of doubles)
//		genre		(character string)
//		filename	(character string)
//
// When the kill signal is received, the daemon runs through any remaining data
// in the buffer from PVM, then exits.
//
// Arguments:
//	proc_group:	(optional) character string group name that this daemon
//				process will join (and leave when the kill
//				signal is received). This makes classifying
//				running daemon processes much easier. Default
//				is `processors'.
//	proc_listen:	(optional) integer message tag on which this daemon
//				process will listen for incoming data. Default
//				is 2.
//	coll_group:	(optional) character string group name to which this
//				daemon process will send (broadcast) its
//				fully-processed data. If this group ever becomes
//				empty, this process will wait until either a
//				process joins the group or it receives the kill
//				signal. Default is `collectors'.
//	coll_listen:	(optional) integer message tag to be used when sending
//				our processed data to a collector daemon.
//				Default is 3.
//	stat_group:	(optional) character string group name to which to
//				broadcast one's status (idle/busy). Default is
//				`status'.
//	stat_listen:	(optional) integer message tag on which status daemon(s)
//				is/are listening for status changes & queries.
//				Default is 1.
//	kill_listen:	(optional) integer message tag on which to listen for
//				the kill signal. Default is 101.
//	kill_msg:	(optional) character string message to listen for. When
//				received, the daemon leaves its group and exits.
//				Default is defined in `audicon_defaults'.
//
// Version 0.9a
//!
// Part of project Audicon by Dan Church <daniel.church@uwrf.edu>

	// load defaults if necessary
	for a = [ 'proc_group' 'proc_listen' 'stat_group' 'stat_listen' ..
			'coll_group' 'coll_listen' 'kill_listen' 'kill_msg' ]
		if ~exists(a, 'local')
			execstr(a + '=audicon_defaults(a)');
		end
	end

	// join our group (so as to receive broadcasts)
	pvm_joingroup(proc_group);

	// let the `stat' daemon know we're open to receiving data
	pvm_bcast(stat_group, 'i', stat_listen);
	status_reported = 'i';

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
		case proc_listen // received data to process

			// tell the `stat' daemon(s) that we're busy if they
			// think we're idle
			if status_reported == 'i'
				pvm_bcast(stat_group, 'b', stat_listen);
				status_reported = 'b';
			end

			// check over the data (so we don't err-out when
			// accessing fields)
			if typeof(data) == 'st'
				flds = getfield(1, data);
				if size(grep(getfield(1, data), [ 'fcns' ..
					'sampling_rate' 'curr_clip' ..
					'curr_tex' 'prev_clip' 'prev_tex' ..
					'next_clip' 'next_tex' 'genre' ..
					'filename' ]), 'c') == 10
					// all fields exist; we're good to go

// support structure arrays
for ind = 1 : data.dims(1)
	// perform the requested operations (I'm glad I made this function)
	send(ind).features = calc_features(data(ind).fcns, ..
		data(ind).sampling_rate, ..
		data(ind).curr_clip, data(ind).curr_tex, ..
		data(ind).prev_clip, data(ind).prev_tex, ..
		data(ind).next_clip, data(ind).next_tex);
	// copy over other fields
	send(ind).genre = data(ind).genre;
	send(ind).filename = data(ind).filename;
end

// send data to collection daemon(s)
pvm_bcast(coll_group, send, coll_listen);

				end
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
				warning(sprintf('daemon_proc(): received ' + ..
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

	// we've already exited from the group & run through all waiting data,
	// so just tell the user that we're exiting
	warning('daemon_proc(): exiting');

endfunction
