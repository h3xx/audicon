function [received_kill, killed_by]=pvm_have_kill(kill_listen, kill_msg)
// checks to see whether the PVM tid of the calling process has received the
// kill message specified
//!
// Part of project Audicon by Dan Church <daniel.church@uwrf.edu>

	// load defaults if necessary
	for a = [ 'kill_listen' 'kill_msg' ]
		if ~exists(a, 'local')
			execstr(a + '=audicon_defaults(a)');
		end
	end

	// data will be [] if we haven't received anything
	[ data killed_by ] = pvm_next_buff(kill_listen);

	receivied_kill = data == kill_msg;
endfunction
