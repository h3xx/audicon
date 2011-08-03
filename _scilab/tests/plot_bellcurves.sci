function plot_bellcurves(xmin, xmax, step)

	// load defaults if necessary
	for a = [ 'xmin' 'xmax' 'step' ]
		if ~exists(a, 'local')
			execstr(a + '=defs(a)');
		end
	end

	// generate x coordinates
	x = xmin : step : xmax;

	// let's not waste cpu cycles plotting when we could be calculating
	drawlater();

	// normal bell curve
	subplot(2, 3, 1);
	a = gca();
	a.title.text = 'normal';
	y = bell_curve(x);
	plot(x, y);

	// variation on `f'
	subplot(2, 3, 2);
	a = gca();
	a.title.text = 'exponent';
	for xp = 1 : 10
		y = bell_curve(x, xp=xp);
		plot(x, y);
	end

	// variation on `w'
	subplot(2, 3, 3);
	a = gca();
	a.title.text = 'width';
	for wd = 1 : 10
		y = bell_curve(x, wd=wd);
		plot(x, y);
	end

	// variation on `s'
	subplot(2, 3, 4);
	a = gca();
	a.title.text = 'scale';
	for sc = 1 : 10
		y = bell_curve(x, sc=sc);
		plot(x, y);
	end

	// variation on `h'
	subplot(2, 3, 5);
	a = gca();
	a.title.text = 'height';
	for he = 1 : 10
		y = bell_curve(x, he=he);
		plot(x, y);
	end

	// variation on `c'
	subplot(2, 3, 6);
	a = gca();
	a.title.text = 'center';
	for cn = 0 : 9
		y = bell_curve(x, cn=cn);
		plot(x, y);
	end

	// finally, let scilab draw the plots
	drawnow();

	clear defs; // clean up
endfunction

function [settings]=defs(index)
	settings.xmin=-10;
	settings.xmax=10;
	settings.step=0.01;
	if exists('index', 'local')
		// user wants a particular setting
		settings=settings(index);
	end
endfunction
