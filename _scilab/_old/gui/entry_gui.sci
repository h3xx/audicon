function setup_entry_gui(gwin)
	disp('creating an entry gui in window '+gwin)
endfunction

function file_menu(entry, gwin)
	select entry
		case 1 then
		disp('you selected file menu entry 1: Open')
	end
endfunction
