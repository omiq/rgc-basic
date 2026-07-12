REM Per-target constants with #IF TARGET — pick machine-specific values at
REM compile time, then run one shared body against them.
REM
REM Only the matching branch survives. On a c64 build the VIC-II numbers
REM are the only ones in the image; the ZX and fallback lines are gone.
REM
REM   basic examples/cond-constants.bas                  (target = native)
REM   basic --target c64 examples/cond-constants.bas
REM   basic --target zxspectrum examples/cond-constants.bas
REM   basic --target vic20 examples/cond-constants.bas

#IF TARGET c64,c128
MACHINE$ = "Commodore VIC-II"
BORDER_ADDR = 53280
SCREEN_W = 40
#ELSEIF TARGET vic20
MACHINE$ = "VIC-20"
BORDER_ADDR = 36879
SCREEN_W = 22
#ELSEIF TARGET zxspectrum
MACHINE$ = "ZX Spectrum ULA"
BORDER_ADDR = 0
SCREEN_W = 32
#ELSE
MACHINE$ = "generic host"
BORDER_ADDR = 0
SCREEN_W = 80
#END IF

REM --- shared body, identical on every target ---
PRINT "Machine : "; MACHINE$
PRINT "Screen  : "; SCREEN_W; " columns"

IF BORDER_ADDR > 0 THEN
  PRINT "Border  : POKE "; BORDER_ADDR; ",0 sets it black"
ELSE
  PRINT "Border  : use BORDER 0 (or no hardware border)"
END IF

REM draw a rule the exact width of this machine's screen
RULE$ = ""
FOR I = 1 TO SCREEN_W
  RULE$ = RULE$ + "="
NEXT I
PRINT RULE$
