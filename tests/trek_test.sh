#!/bin/sh
# Run trek.bas with piped input. trek.txt provides initial commands (e.g. sls);
# we append "xxx" (resign) and "no" (don't restart) to exit cleanly.
set -e
cd "$(dirname "$0")/.."
(cat tests/trek.txt; printf 'xxx\nno\n') | ./basic -petscii examples/trek.bas
