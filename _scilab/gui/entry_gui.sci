function [h]=entry_gui()
	global audicon_data;

	// create the figure
	h = figure();
	set(h, 'figure_name', 'Audicon Entry Window');
	//'position', [10 10 300 200],

	// file menus
	fm = uimenu(h, 'label', 'File');

	owm = uimenu(fm, 'label', 'Open Wav', 'callback', 'menu_open_wav(' + string(h) + ')');

	

	// controls

	// get ready for input
	// clear out this entry window's data
	audicon_data.entry_window_data(h) = struct('name', [], 'file', [], 'data', [], 'rate', [], 'samples', struct('index', [], 'instruments', [], 'genres', [], 'emotions', []));
endfunction

function menu_open_wav(h)
	global audicon_data;

	disp('FIXME: Stub menu_open_wav(' + string(parent) + ')');
	filename = tk_getfile('*.wav');
	if filename == '' then
		// no file was chosen
	else
		// get file size
		fsize = fileinfo(filename);
		fsize = fsize(1);
		// resize stack if necessary
		stack = stacksize();
		stackfree = stack(1) - stack(2);
		if stackfree < fsize then
			stacksize(stack(1) + fsize);
		end

		// resize global stack if necessary
		gstack = gstacksize();
		gstackfree = gstack(1) - gstack(2);
		if gstackfree < fsize then
			stacksize(stack(1) + fsize);
		end

		// open file
		[wavdata wavstats] = loadwave(filename);

		audicon_data.entry_window_data(h).rate = wavstats(3);

endfunction

function button_play(h, start, finish)
	
endfunction
