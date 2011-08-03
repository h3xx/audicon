function plot_centroid(duration, num_rand_waves, max_freq)

	// initialize waveform
	wd = gen_tone(0, duration);

	for r = rand(1, num_rand_waves) * max_freq
		wd = wd + gen_tone(r, duration);
	end

	[amps freqs] = fft_unweighted(wd);

	cn = centroid(wd);

	plot(freqs, amps, 'r');

	plot([cn cn], [0 max(amps)], 'b');

endfunction
