function [buff, tid]=pvm_next_buff(message_tag)
// collects one buffer from any tid (including your own) waiting on the given
// message tag, sent to the tid of the process which calls this function
//
// Arguments:
//	message_tag:	the integer message tag of the data.
//
// Returns:
//	buff:		the scilab variable contents of the next waiting buffer.
//				This will be [] if there was no data waiting.
//	tid:		the integer task id of the process which sent the data.
//				This will be 0 if there was no data waiting.
//
// Version 1.0
//!
// Part of project Audicon by Dan Church <daniel.church@uwrf.edu>

	// these won't get set if there's nothing waiting
	tid = 0;
	buff = [];

	// check every tid (wildcard tid is -1)
	if pvm_probe(-1, message_tag)
		// there's something waiting; let's retrieve it
		[ buff err tid ] = pvm_recv(-1, message_tag);
	end

endfunction
