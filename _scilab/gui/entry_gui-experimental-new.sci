function [h]=entry_gui()
	global audicon_data;

	h = gcf(); // new window
	h.figure_name = 'Audicon Entry Window';
	//'position', [10 10 300 200],

	// file menus
	addmenu(h.figure_id, 
	owm = uimenu(fm, 'label', 'Open Wav', 'callback', 'menu_open_wav(' + string(h) + ')');

	

	// controls

	// get ready for input
	// clear out this entry window's data
	audicon_data.entry_window_data(h) = struct('name', [], 'file', [], 'data', [], 'samples', struct('index', [], 'instruments', [], 'genres', [], 'emotions', []));
endfunction

function menu_open_wav(parent)
	
	disp('FIXME: Stub menu_open_wav(' + string(parent) + ')');
endfunction
