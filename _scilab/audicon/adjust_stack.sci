function [ns]=adjust_stack(needed, need_free)
// looks at the current local stack and adjusts it
//
// Arguments:
//	needed:		how much memory you think you'll need; how much data are
//				you going to be needing to work with.
//				Alternately, if you're loading a file into
//				memory, you can specify the (character string)
//				file name here.
//	need_free:	(optional) make sure that there is this many bytes free.
//				A value of 0 will ensure that there are as many
//				bytes free as before we adjusted it. A negative
//				value will free the stack so that the amount of
//				free space will equal `abs(need_free)'. Default
//				is 5,000,000 variable slots (Scilab default for
//				startup & a good-sized working environment).
//
// Returns the new amount of stack.
//!
// Part of project Audicon by Dan Church <daniel.church@uwrf.edu>

	curr_stacksize = stacksize(); // [size used]
	curr_used = curr_stacksize(2);
	curr_free = curr_stacksize(1) - curr_used;

	if ~exists('need_free')
		need_free = 5000000;
	elseif ~need_free
		need_free = curr_free;
	else
		need_free = int(need_free);
	end

	needed = max([ needed 2^20 ]);
	newfree = abs(need_free);

	// accept a character string file name
	if typeof(needed) == 'string'
		// get file size
		[fi err] = fileinfo(needed);
		if err
			// couldn't stat file
			// give error 'File %s does not exist or read access
			// denied'
			error(needed, 241);
			// see `error_table' manual page
		end
		// no errors doing a `stat' on the file -- proceed
		needed = fi(1); // index 1 is integer file size in bytes
		clear fi err; // free up some memory
	end

	// calculate new stack size
	if need_free < 0 | curr_free < (needed + newfree)
		// shrink (possibly) stack
		// ... or not enough space for what user wants
		ns = curr_used + needed + newfree;

		// give a warning
		warning('resizing stack ' + string(curr_stacksize(1)) + ..
				' -> ' + string(ns));

		// resize!
		stacksize(ns);
	else
		ns = curr_stacksize(1);
	end
	
	// memory sizes:
	// one scalar:	3 slots
	// nxm matrix:	3 + size
endfunction
