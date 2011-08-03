function save_net(W, net_file, backup_suf)
// saves the state of the network to disk
//
// Arguments:
//	W:		the weight hypermatrix from ANN
//	net_file:	(optional) character-string file name where network
//				state is to be saved. Default is SCIHOME + 
//				'/audicon/net_state.sav'.
//	backup_suf:	(optional) character-string siffix to be appended to the
//				old net state file. Default is '~' (ala vi &
//				EMACS). Use '' (empty string) to disable
//				backups.
//
//!
// Part of project Audicon by Dan Church <daniel.church@uwrf.edu>

	// load default variables if necessary
	for a = [ 'net_file' 'backup_suf' ]
		if ~exists(a, 'local')
			execstr(a + '=audicon_defaults(a)');
		end
	end

	// create backup if necessary
	if length(backup_suf)
		// user wants a backup
		// warning: `copyfile()' is new to Scilab 4.1
		if ~copyfile(net_file, net_file + backup_suf)
			// copyfile returns 0 if there's an error
			warning('could not backup file `' + net_file + ..
					''' to `' + net_file + backup_suf + ..
					'''');
		end
	end

	// save our data
	// (Scilab's save() function seems to not care if it's over-writing)
	save(net_file, W);

endfunction
