REM Two includes in a row: first uses "../" (overwrote the
REM aliased-static base_dir buffer pre-fix), second is a sibling
REM that pre-fix resolved against the corrupted dir and exit(1)'d.
#INCLUDE "../include_chain_lib.bas"
#INCLUDE "inner.bas"

FUNCTION main_value()
  RETURN inner_value() + lib_value()
END FUNCTION
