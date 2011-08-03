function [splits]=split_wav(wavdata, duration, sampling_rate, m)
// splits a given wav data vector into a two-dimensional matrix of clips
//
// Arguments:
//	wavdata:	the vector of PCM wav sample values (see loadwave).
//	duration:	duration in seconds of each clip.
//	sampling_rate:	(optional) samples per second. Default is 44100.
//	m:		mode of splitting:
//				1: (default) reads a clip from EACH sample
//				2: reads discrete samples
//
// Returns a matrix of separated clips, each defined on a different row.
//
// Version: 0.9
//!
// Part of project Audicon by Dan Church <daniel.church@uwrf.edu>

	// load defaults if necessary & correct floating-point badness
	if ~exists('sampling_rate')
		sampling_rate = 44100;
	else
		sampling_rate = int(abs(sampling_rate));
	end

	if ~exists('m') | mmm > 2 | mmm < 1
		m = 1;
	else
		m = int(m);
	end
	// merge channels & normalize
	wavdata = normalize(sum(wavdata, 'r'));
	// adjust stack size
	// FIXME

	// begin splitting
	splits=[];
	sz = duration * sampling_rate; // each clip's size
	select m
		case 1 then
			// more data for your byte!
			// procedure:
			//
			// example: size = 2
			//	1	2	3	4	5
			//[	][	][	][	][	]
			//|-------------|
			//	 |--------------|
			//		 |--------------|
			//			|---------------|
			// DEBUG: disp('splitting each sample');
			for ind = 1:(size(wavdata, 2) - sz + 1)
				splits(ind,:) = wavdata(ind:(ind + sz - 1));
			end
		case 2 then
			//FIXME split discrete waves
			// DEBUG: disp('splitting discrete samples');
		else
			disp('WARNING: no mode selected');
	end
endfunction
