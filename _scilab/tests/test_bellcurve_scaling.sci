function test_bellcurve_scaling()
// FIXME: description stub

// Arguments:
//	FIXME: arguments stub
//
// Returns FIXME: return stub
//!

	x = (-100) : 0.01 : 100;

	clf();
	drawlater();

	for sc = 10 : 10 : 90
		// r = int((sc - 1) / 3) + 1;
		// c = modulo(sc - 1, 3);
		subplot(3, 3, sc / 10);
		a = gca();
		// calculate curve
		y = bell_curve(x, sc=sc);
		// calculate where guide crosses curve
		g = bell_curve(sc, sc=sc);
		// add useful label to plot
		a.title.text = sprintf('sc=%d; f(sc)=%e', sc, g);
		// plot curve
		plot(x, y);
		// plot guides
		plot([ sc sc ], [ 0 1 ], 'r');
		plot([ -sc -sc ], [ 0 1 ], 'r');
	end

	drawnow();
endfunction
