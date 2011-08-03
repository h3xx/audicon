function [W]=train_net(in_data, out_data, num_hidden, learning_rate, ..
	error_squelch, num_epochs, training_goal, activation_functions, ..
	init_fn, training_fn, temp_net_file, net_save_every, ex, ..
	weight_init_limits, biases, err_deriv_y)
// Trains a network using ANN, with a goal. Uses an ANN standard training
// function (specified by `training_fn' argument) & and uses the character
// string argument `ex' to achieve the goal-checking.
//
// Arguments:
//	in_data:	matrix of real inputs, each input pattern defined on a
//				different row.
//	out_data:	matrix of real target outputs, each output pattern
//				defined on a different row.
//	num_hidden:	
//	training_goal:	(optional) goal for training. Default is 0 (perfect
//				score).
//	init_fn:	(optional) character string name of the function used to
//				initialize the network. Default is
//				`ann_FF_init'.
//	training_fn:	(optional) character string name of the training
//				function to use. Default is `ann_FF_Std_batch'.
//	temp_net_file:	(optional) character string. Path to file (doesn't have
//				to exist yet) where you want to save the
//				relevant information for training, so that if
//				the training process gets interrupted, one may
//				restart this function and continue training.
//				Default is SCIHOME + '/net_temp_state.sav'.
//	net_save_every:	(optional) integer. How often (in epochs) should the
//				network be saved? A higher value will be easier
//				on cpu/disk usage. Default is to save every 10
//				epochs. This will be adjusted to 1 if the total
//				number of epochs is less than 10.
//	See manpage for `ann_FF_Std_batch' for argument descriptions.
//
// Returns the ANN-generated hypermatrix representing the trained network.
//
// Version: 0.1a
//!
// Part of project Audicon by Dan Church <daniel.church@uwrf.edu>

	// load default variables if necessary
	for a = [ 'num_hidden' 'learning_rate' 'error_squelch' ..
			'num_epochs' 'training_goal' 'activation_functions' ..
			'init_fn' 'training_fn' 'temp_net_file' ..
			'net_save_every' 'ex' 'weight_init_limits' 'biases' ..
			'err_deriv_y' ]
		if ~exists(a, 'local')
			execstr(a + '=audicon_defaults(a)');
		end
	end

	// rotate matrices, because ANN requires it
	in_data = in_data';
	out_data = out_data';
	
	// organized for my benefit, and to minimize arduous function calls
	// these represent the number of input/output nodes (I.E. the number of
	// variables to be input/output at once)
	num_input = size(in_data, 'r');
	num_output = size(out_data, 'r');

	layers = [ num_input num_hidden num_output ];

	// use magic to retrieve pointer to correct init and training functions
	// I don't think this works in Matlab, but who cares?
	// btw, these should only be local to this function; we're not defining
	// a new global function here. I tested that.
	init_fn = evstr(init_fn);
	training_fn = evstr(training_fn);

	// figure out if we're resuming the training
	[fi err] = fileinfo(temp_net_file);
	if ~err
		// file survived a `stat'; should be okay
		load(temp_net_file); // should define `W' for us
		if ~exists('W', 'local')
			warning('Temporary network state was found, but it' + ..
			' is not in the correct format. Re-initializing' + ..
			' network.');
			// initialize network with random weights
			W = init_fn(layers, biases);
		end
	else
		// no temp save found -- initialize network with random weights
		W = init_fn(layers, weight_init_limits, biases);
	end

	// open a waitbar
	wb = waitbar(''); // this gets set in our `ex'

	// make our own executions to do what WE want

	// step 1: save the network if it requires it
	// hints: `time' is an ANN-internal variable equal to the epoch number.
	//	Calls to strsubst are to convert strings which could possibly
	//	have single-quotes in them into a pascal-style doubly-quoted
	//	string when they get sent to `execstr(ex)' inside ANN.
	ex = [ ex 'if ~modulo(time,' + string(net_save_every) + ');' + ..
			'save_net(W,''' + strsubst(temp_net_file, '''', ..
			'''''') + ''',''' + strsubst(backup_suf, '''', ..
			'''''') + '''); end' ];
	// step 2: test for the goal having been reached
	// hints: `T' is an ANN-internal variable equal to the total number of
	//	epochs to run for (exact syntax went something like `for time =
	//	1 : T').
	//	Also, `grad_E' is the error gradient, I.E. `grad_E' times the
	//	learning rate gets added to our network weights every epoch.
	ex = [ ex 'if abs(sum(grad_E)) <= ' + string(training_goal) + ..
			'; time = T;' ];
	// step 3: update our waitbar
	ex = [ ex 'waitbar(time / T, ''Training network: epoch ('' + ' + ..
			'string(time) + ''/'' + string(T) + '') error (''' + ..
			' + string(abs(sum(grad_E))) + ''/' + ..
			string(training_goal) +	')'', ' + string(wb) + ')' ];

	// train network
	W = training_fn(in_data, out_data, layers, W, [ learning_rate ..
			error_squelch ], num_epochs, activation_functions, ..
			ex, err_deriv_y);

	// close waitbar
	close(wb);

endfunction
