function plot_centroid(wd, sampling_rate)

	// load defaults
	for a = [ 'sampling_rate' ]
		if ~exists(a, 'local')
			execstr(a + '=audicon_defaults(a)');
		end
	end

	sampling_rate = int(abs(sampling_rate));

	[amps freqs] = fft_unweighted(wd, sampling_rate);
	cn = centroid(wd, sampling_rate);

	plot(freqs, amps, 'r');

	plot([cn cn], [0 max(amps)], 'b');

endfunction
