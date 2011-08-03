function [y]=bell_curve(x, xp, wd, sc, he, cn)
// generates a bell curve from given x value(s)
//
// Generates the author's take on a bell curve with the following characteristic
// function:
//
// y = he * %e ^ ( -abs( ( ( x - cn ) / sc ) ^ xp / wd ) )
//
// Some notes about this bell curve:
// * for all values of xp, wd, cn, sc, & he, y = bell_curve(x,xp,wd,sc,he,cn)
//   will contain the points { (cn-sc, he/%e^(1/wd)), (cn+sc, he/%e^(1/wd)) }.
//   * try graphing it for a bunch of random values of `xp'; you'll see what I
//     mean -- they all meet at the same two points.
//   * complete instructions for generating your own curve (you're on your own
//     if you want to analyze them) are included below.
// 
//
// Arguments:
//	x:	the values or matrix of values to which the function is to be
//			applied
//	xp:	(optional) the exponent applied to the input values. Larger
//			values generate a curve with a wider peak and steeper
//			slopes, whereas a smaller value will generate a curve
//			with a narrow peak and shallower sides. Default is 2.
//	wd:	(optional) an expression of the `width' of the curve. Note that
//			this is different from `sc' in that, considering the
//			point made above that all values of `xp' produce lines
//			that pass through a single point, changing the value of
//			`wd' will cause the point at which those lines meet to
//			move higher or lower with respect to y, but will not
//			change its value with respect to x. Note that higher
//			values of `wd' will cause the curve to narrow greatly
//			towards the peak, but will cause its slopes to decrease
//			very gradually farther from the peak. Default is 1.
//	sc:	(optional) also an expression of the `scaling' of the curve.
//			Note that this is different from `wd' in that, instead
//			of causing the common point (for all values of `xp') to
//			change its y value, it causes it instead to move left or
//			right with respect to x. Note that changing this value
//			does not change the general shape of the curve; it
//			merely widens it (sc>1) or narrows it (sc<1). I suppose
//			you could use this value to mirror the curve (sc=-1)
//			around the line x=cn, but I can't see a reason to mirror
//			a symmetric curve. Default is 1 (no scaling).
//	he:	(optional) the peak height of the curve (at its center). This is
//			merely a coefficient applied to the curve, and can thus
//			be applied to mirror the curve (he=-1) around the line
//			y=0. Default is 1.
//	cn:	(optional) the value where the center peak should be. This does
//			nothing to the shape of the curve, but translates it
//			along the x axis. Default is 0 (no translation).
//
// Returns the computed y value for the point (or series of points) as it/they
// would lie on the curve.
//
// Version 1.1
//!
// Part of project Audicon by Dan Church <daniel.church@uwrf.edu>

	// load defaults if necessary
	for a = [ 'xp' 'wd' 'sc' 'he' 'cn']
		if ~exists(a, 'local')
			execstr(a + '=audicon_defaults(a)');
		end
	end

	// let's do this!
	y = he * %e ^ (-abs(((x - cn) / sc) ^ xp / wd));
	// how's that for a high comment-to-code ratio?
endfunction
