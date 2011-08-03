function [wavdata]=gen_tone(hz, seconds, sampling_rate)
// generates a sin wave of amplitude 1 given duration and sampling rate
	if ~exists('sampling_rate') then
		sampling_rate = 44100; // CD audio default
	else
		sampling_rate = int(abs(sampling_rate));
	end

	wavdata(1:(sampling_rate * seconds)) = sin((1:(sampling_rate * seconds)) * hz * 2 * %pi / sampling_rate);
endfunction
