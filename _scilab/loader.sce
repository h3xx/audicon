// remove backup files ({audicon,tests.pvm}/*~)
// compile audicon, audicon testing & audicon pvm libraries
//!
// Part of project Audicon by Dan Church <daniel.church@uwrf.edu>

mode(-1); // silent execution

// remove backup files (genlib is dumb and will process those too -> .bin~)
for fn = listfiles([ 'audicon/*~' 'tests/*~' 'pvm/*~' ])'
	warning('deleting backup file `' + fn + '''');
	mdelete(fn);
	// clear the function so it can be reloaded, as it's probably been
	// updated
	execstr('clear ' + basename(fn));
end

//path = get_absolute_file_path('loader.sce');
//genlib('audiconlib', path + '/audicon/');
// genlib('audicontestlib', path + '/tests/');

// let's not mess around with absolute paths
genlib('audiconlib', 'audicon/');
genlib('audicontestlib', 'tests/');
genlib('audiconpvmlib', 'pvm/');
