#!/bin/sh

tar czf "`date '+%Y-%m%d-%H%M'`_Audicon.tar.gz" Audicon.pm $(find Audicon -type f -iname '*.pm') doc
