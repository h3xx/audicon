function [l, g]=free()
// gives amount of free stack

	s = stacksize();
	l = s(1) - s(2);

	s = gstacksize();
	g = s(1) - s(2);
endfunction
