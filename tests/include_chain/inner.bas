REM Same-dir include; would resolve incorrectly if the parent's
REM base_dir had been overwritten by the previous "../" include.
FUNCTION inner_value()
  RETURN 11
END FUNCTION
