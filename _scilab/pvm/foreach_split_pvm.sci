function foreach_split_pvm(wavfile, genre, fcns, clip_duration, tex_span, ..
	step, proc_group, proc_listen, stat_group, stat_listen, stat_send)
// splits a given wav data vector into clips of specified length, and passes
// each clip through the functions specified
//
// As one can imagine, this is a whole lot less memory-intensive than returning
// a matrix of splits & pushing them onto the stack every time a new operation
// is performed.
//
// Note: in order to preserve EVERY aspect of the given audio data, the song is
// to be thought of a circular buffer of audio data. Thus, of one has a clip
// size of 0.5 seconds and a texture frame size of 1.5 seconds, the first
// texture frame of audio data would begin at the end of the song. Here's a
// handy diagram:
//
//              x
//         e          t
//      t       | c       u
//    \       -----  l
//     \   --   ^   --  i    r
//       /      |      \  p
//      /     song      \  /   e
//     |     start,      |
//     |       end       |
//      \               /
//       \             /  \
//         --       --      \
//            -----
//
// Though, admittedly, this drawing is not to scale.
//
// Arguments:
//	wavfile:	the character-string file name of a PCM wav file to be
//				processed
//	genre:		the character-string name of the genre defined for this
//				file
//	fcns:		(optional) row-vector of character strings. names of
//				function calls to execute. These must be fully-
//				qualified Scilab instructions. Feel free to
//				use any of these internal variables:
//				c_sz:		each clip's size in samples
//				t_sz:		each texture frame's size in
//					samples
//				curr_ind:	the index of the sample on which
//					the current clip started
//				curr_clip:	the row-vector of clip sample
//					values
//				prev_ind:	the index of the sample on which
//					the previous clip started
//				prev_clip:	the previous clip's sample
//					values
//				next_ind:	the index of the sample on which
//					the next clip starts
//				next_clip:	the next clip's sample values
//				curr_tex:	the row-vector of samples in the
//					current texture frame
//				prev_tex:	the row-vector of samples in the
//					previous texture frame
//				next_tex:	the row-vector of samples in the
//					next texture frame
//				For example `centroid(clip, sampling_rate)'
//				Note: functions must return a single value (can
//				be a vector of values). Anything else will be
//				ignored. Don't say I didn't warn you.
//				Default is defined in `audicon_defaults.sci'.
//	clip_duration:	(optional) duration in seconds of each clip. Default is
//				0.5 seconds.
//	tex_span:	(optional) span defining the range of each `texture'
//				frame of data such that:
//				tex_span(1) is equal to the number of seconds
//				of audio data included BEFORE the target clip
//				and tex_span(2) is equal to the number of
//				seconds of audio data included AFTER the target
//				clip. Default is [ 1 1 ].
//	step:		(optional) for splitting; the number of seconds between
//				the starting points of each clip. Default is
//				0.5 seconds (same as clip_duration).
//				To read DISCRETE samples, make sure this is set
//				to the same value as your clip_duration.
//				to split a clip from EVERY sample, use a value
//				equal to 1 / sampling_rate.
//
// Returns a matrix of the return values of the function calls executed.
//
// Version: 1.0b
//!
// Part of project Audicon by Dan Church <daniel.church@uwrf.edu>

	// load defaults if necessary
	for a = [ 'fcns' 'clip_duration' 'tex_span' 'step' 'proc_group' ..
			'proc_listen' 'stat_group' 'stat_listen' 'stat_send' ]
		if ~exists(a, 'local')
			execstr(a + '=audicon_defaults(a)');
		end
	end

	// DEBUG: let me know where I am
	// create waitbar
	wb = waitbar('finding normalization coefficient');
	// END DEBUG

	// for normalization
	nc = normalization_coeff(wavfile, 1, wb);
	// get the sampling rate from the file
	[wav_size sampling_rate] = wavread(wavfile, 0);
	num_samples = wav_size(2);
	num_channels = wav_size(1);

	// some preliminary variables
	// size of entire wav sample set
	//num_samples = size(wavfile, '*');
	// each clip's size in samples
	clip_size = clip_duration * sampling_rate;
	// each texture span's size [left right] in samples
	tex_size = tex_span * sampling_rate;
	// how much to jump after each clip (distance in samples)
	jump = step * sampling_rate;

	// make sure these indices are not out of bounds

	if num_samples < clip_size
		error('wavfile of too small a size to split');
	end

	// positions of clips and texture frames inside the buffer (these stay
	// constant)
	prev_ind = tex_size(1) + 1;
	curr_ind = prev_ind + jump + 1;
	next_ind = curr_ind + jump + 1;
	prev_tex_ind = prev_ind - tex_size(1);
	curr_tex_ind = curr_ind - tex_size(1);
	next_tex_ind = next_ind - tex_size(1);

	// begin creating the struct we're going to sent to PVM (these stay
	// constant)
	send.sampling_rate = sampling_rate;
	send.fcns = fcns;
	send.filename = wavfile;
	send.genre = genre;

	// set up a buffer of wav samples so I don't have to re-load them
	// then, from that buffer, all indices are relative to it
	buff_size = sum(tex_size) + 2 * jump + clip_size;
	buff_start = -jump - tex_size(1);
	buff_end = buff_start + buff_size - 1;

	// adjust stack size
	// let's see... I'll need three clips defined at once (prev, curr, next)
	// and... three texture vectors defined at once + one good-sized read
	// buffer
	adjust_stack(3 * (clip_size + sum(tex_size)) + ..
		num_channels * buff_size);

	// the first loading of the buffer
	// 1. first portion left of wav file range
	buff = wavread(wavfile, [ wrap_to_range(buff_start, num_samples) ..
			num_samples ]);
	// 2. however many times the buffer spans the whole file (hopefully none
	//    at all)
	num_buff_spans = int((buff_size + buff_start - buff_end) / num_samples);
	if num_buff_spans
		// oh well, we can at least save some time extracting from disk
		a = wavread(wavfile);
		for z = 1 : num_buff_spans
			buff = [ buff a ];
		end
	end
	// 3. last chunk from last overshoot of wav file boundaries
	buff = [ buff wavread(wavfile, wrap_to_range(buff_end, num_samples)) ];

	// merge channels & normalize
	buff = sum(buff, 'r') * nc;

	// DEBUG: let me know where I am
	// update waitbar 
	waitbar(0, 'splitting clips...', wb);
	// END DEBUG

	// count through the data
	for i = 1 : jump : num_samples
		// DEBUG: let me know where I am
		waitbar((i - 1) / (int(num_samples / clip_size) * ..
			clip_size), wb);
		// END DEBUG

		// split prev, next & curr clips & texture frames
		send.prev_clip = buff(prev_ind : (prev_ind + clip_size));
		send.curr_clip = buff(curr_ind : (curr_ind + clip_size));
		send.next_clip = buff(next_ind : (next_ind + clip_size));
		send.prev_tex = buff(prev_tex_ind : (prev_tex_ind + ..
				sum(tex_size)));
		send.curr_tex = buff(curr_tex_ind : (curr_tex_ind + ..
				sum(tex_size)));
		send.next_tex = buff(next_tex_ind : (next_tex_ind + ..
				sum(tex_size)));


		// send to network
		// find out who's available to receive our data (in group of
		// processors)
		send_to = pvm_next_idle(proc_group, stat_group, stat_listen, ..
			stat_send);
		while size(send_to, '*') < 1
			// funny response
			if show_warnings
				warning('foreach_split_pvm(): no response ' + ..
					'from network; maybe nobody''s ' + ..
					'listening');
				sleep(1000);
			end
			// ask again
			send_to = pvm_next_idle(proc_group, stat_group, ..
				stat_listen, stat_send);
		end

		// we got an idle (or random) processor tid; let's send
		pvm_send(send_to, send, proc_listen);

		// move the buffer (we are advancing by `jump' samples)
		add_ends = wrap_to_range([ buff_end buff_end + jump ], ..
				num_samples);
		if add_ends(1) < add_ends(2)
			// we still haven't touched the end of the file
			a = wavread(wavfile, add_ends);
		else
			// what we're adding spans across the right edge of the
			// wav file
			a = [ wavread(wavfile, [ add_ends(1) num_samples ]) ..
				wavread(wavfile, add_ends(2)) ];
		end

		// shift the buffer's indices into the wav file
		buff = [ buff(jump : buff_size) ..
			sum(a, 'r') * nc ];
		buff_start = buff_start + jump;
		buff_end = buff_end + jump;

	end
	// DEBUG: let me know where I am
	// close waitbar
	closewin(wb);
	// END DEBUG
endfunction
