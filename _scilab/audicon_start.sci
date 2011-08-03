// starts Audicon
function audicon_start()
	// load the libraries
	loadlibs(['gui/' 'main/']);
	// start the program
	audicon_main();
endfunction

// loads and compiles the necessary libraries
//
// Arguments:
//	libdirs:	A vector of character strings; paths to viable library
//			locations.
function loadlibs(libdirs)
	// flatten out the list of dirs
	//libdirs = matrix(libdirs, 1, -1); // I don't wanna
	// do a foreach on libdirs, adding to library path then compiling
	for l = libdirs
		// define functions in library
		fns = lib(l);
		// compile functions in library
		genlib('fns');
	end
endfunction
