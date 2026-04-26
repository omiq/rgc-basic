REM Regression: load_file_into_program's `base_dir` aliased
REM get_base_dir's static buffer. A nested #INCLUDE "../foo" inside
REM main.bas overwrote that buffer, so main.bas's *next* include
REM resolved against the corrupted directory and basic-gfx exit(1)'d
REM with "Cannot open …". Fixed by snapshotting base_dir into a
REM stack-local buffer at function entry.
#INCLUDE "include_chain/main.bas"

PRINT main_value()
