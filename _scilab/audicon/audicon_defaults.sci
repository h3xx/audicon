function [settings]=audicon_defaults(index)
// gets a hash of the default settings, as defined by yours truly
//
// Arguments:
//	index:		(optional) character string. Preference value to look
//				up. Can also be done with integer-indexing
//				(strongly discouraged).
//
// Returns a nice struct (I think that's what they're called -- I call them
// hashes because I'm a perl programmer) of the default values of settings.
// Alternatively, if a value is given for `index' then it returns the value at
// `settings(index)', settings being the struct of settings.
//
// Version: 1.0a
//!
// Part of project Audicon by Dan Church <daniel.church@uwrf.edu>

	// --- GENERAL SETTINGS ---
	// CD redbook standard (also a lot of soundcards use it too) for
	// sampling rate, in samples per second. Used throughout project Audicon
	settings.sampling_rate = 44100;

	// where do we store our data
	settings.datadir = SCIHOME + '/audicon';

	// data filenames section
	// training data file
	settings.td_file = settings.datadir + '/training_data.sav';
	// genre save file
	settings.genre_file = settings.datadir + '/genre_defs.sav';
	// temporary network save file
	settings.temp_net_file = settings.datadir + '/net_temp_state.sav';
	// network save file
	settings.net_file = settings.datadir + '/net_state.sav';
	// key matches save file
	settings.keymatches_file = settings.datadir + '/key_matches.sav';
	// default backup suffix
	settings.backup_suf = '~';

	// network training section
	// default number of hidden nodes (needs testing)
	settings.num_hidden = 500;
	// default weight initialization limits [lower upper]
	settings.weight_init_limits = [ -1 1 ]; // ANN default
	// default biases
	settings.biases = [ 0 0 ]; // no bias
	// allowed error before exiting epoch-loop
	settings.training_goal = 0.03; // semi-lenient goal
	// number of epochs to train with
	settings.num_epochs = 10000;
	// learning rate of the network
	settings.learning_rate = 0.2;
	// squelch errors below this size
	settings.error_squelch = 0; // adjust for all errors, no matter how tiny
	// activation function names (ANN default)
	settings.activation_functions = ['ann_log_activ', 'ann_d_log_activ'];
	// executable string to be run after each training epoch
	settings.ex = []; // do nothing
	// ANN training function
	settings.training_fn = 'ann_FF_Std_batch';
	// ANN initialization function (is there more than one?)
	settings.init_fn = 'ann_FF_init';
	// epochs to pass between saving the network
	settings.net_save_every = 10;
	// idk
	settings.err_deriv_y = 'ann_d_sum_of_sqr'; // ANN default

	// network testing section
	// numbers of hidden nodes to test with
	settings.test_hidden = 50 : 5 : 900;
	// number of trials over which to test network accuracy
	settings.num_trials = 100;

	// `rolloff' settings
	// default magnitude concentration to determine spectral rolloff
	settings.ro_concentration = 0.85;

	// `amp_by_key' settings
	// default piano key definitions
	// Hz values courtesy of wikipedia
	settings.keydefs = [ 261.626 277.183 293.665 311.127 329.628 349.228 ..
			369.994 391.995 415.305 440.000 466.164 493.883 ];
	// default span of octaves
	// (should cover every note on an 88-key piano)
	settings.octave_span = [ -3 4 ];
	// default span for note frequencies
	settings.note_span = [ 0.5 0.5 ];

	// `bell_curve' settings
	settings.xp = 2;
	settings.wd = 1;
	settings.sc = 1;
	settings.he = 1;
	settings.cn = 0;

	// `foreach_split' settings
	// default values for function calls that compute a particular musical
	// feature.
	settings.fcns = [ 'centroid(curr_clip, sampling_rate)' ..
			'zerocrossings(curr_clip, sampling_rate)' ..
			'rolloff(curr_clip, sampling_rate=sampling_rate)' ..
			'sum(spectral_flux([ curr_clip ; prev_clip ], ' + ..
				'sampling_rate)) / 2' ..
			'magnitude_ratio(curr_clip, curr_tex, sampling_rate)' ..
			'amps_by_key(prev_clip, ' + ..
				'sampling_rate)' ..
			'amps_by_key(curr_clip, ' + ..
				'sampling_rate)' ..
			'amps_by_key(next_clip, ' + ..
				'sampling_rate)' ..
			];
	// size of each split clip in seconds
	settings.clip_duration = 0.5;
	// span of each `texture' frame in seconds [ before, after ] split clip
	settings.tex_span = [ 1 1 ];
	// seconds between the start of each split clip
	settings.step = settings.clip_duration; // split discrete clips

	// --- PVM SECTION ---
	// default settings for our pvm network

	// general settings
	// time between sending results and re-scanning the network
	settings.wait_time = 1000; // milliseconds

	// message tag to be used for daemons to receive the kill signal
	settings.kill_listen = 101;

	// message to send / listen for when killing daemons
	settings.kill_msg = 'stop that!';

	// whether to show warning messages
	settings.show_warnings = %f;

	// `daemon_stat' settings
	settings.stat_group = 'status';
	settings.stat_listen = 1;
	settings.stat_send = 11;

	// `daemon_proc' settings
	settings.proc_group = 'processors';
	settings.proc_listen = 2;

	// `daemon_coll' settings
	settings.coll_group = 'collectors';
	settings.coll_listen = 3;
	settings.coll_send = 13;
	settings.save_size = 200;

	// `daemon_execstr' settings
	settings.execstr_group = 'dimwits';
	settings.execstr_listen = 9;
	settings.execstr_send = 19;

	if exists('index', 'local')
		// user requested specific setting
		settings = settings(index);
	end
endfunction
