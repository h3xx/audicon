function plot_key_extraction(wd)
	for a = [ 'clip_duration' 'sampling_rate' ]
		execstr(a + '=audicon_defaults(a);');
	end

	if ~exists('wd', 'local')
		// generate random points (mono sound)
		wd = rand(1, clip_duration * sampling_rate);
	end

	[ amps freqs ] = fft_unweighted(wd, sampling_rate); clear amps;

	[ key_amps key_freqs key_matches ] = amps_by_key(wd, sampling_rate);

	// `or' our key matches matrix & rotate it for plotting
	key_matches = max(key_matches, 'c')';

	drawlater();

	plot(key_freqs, key_amps, '.r');
	plot(freqs, key_matches, 'b');

	drawnow();
endfunction
