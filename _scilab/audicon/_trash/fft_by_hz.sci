function [amp_by_freq]=fft_by_hz(wavdata, sampling_rate)
// creates a map of the fft output of a given waveform by Hz (cycles per second)
//
// Parameters:
//	wavdata:	raw waveform data (1xn vector) -- see wavread()
//	sampling_rate:	the sampling rate per second; sampling_rate * size(wavdata, 2) = duration
//
// Returns a 2xn matrix, row 1 being frequency, row 2 being amplitude.
//
// Default sampling rate is 14.4 kHz (14400) -- CD quality.
//!
// Part of the Audicon project by Dan Church
	if ! exists(sampling_rate)
		sampling_rate = 14400;
	end

	fftdata = fft(wavdata);
	// Determine duration:
	//
	// size(wavdata, 2) -samples-           1 second          size(wavdata, 2)
	// -------------------------- * ----------------------- = ---------------- seconds/data
	//           1 data             sampling_rate -samples-    sampling_rate
	duration_seconds = size(wavdata, 2) / sampling_rate;

	// fftdata(X) is amplitude of wave cycling X times in the duration of the dataset.
	// Therefore, the frequency in Hz of that wave with respect to time would be X / duration
	for x = 1:size(fftdata, 2)
		amp_by_freq(x) = [x / duration_seconds; fftdata(x)];
	end
endfunction
