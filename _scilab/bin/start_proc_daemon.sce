// starts a `proc' daemon on this thread & exits upon completion
//
// Intended to be used as a startup script for calling using `pvm_spawn'
//!
// Part of project Audicon by Dan Church <daniel.church@uwrf.edu>
mode(-1); // silent execution

// change directory
cd HOME/audicon

// load libraries
load audicon/lib
load pvm/lib

// start the daemon
daemon_proc();

exit();
