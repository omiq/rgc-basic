REM Compile-time platform conditionals — the RGC-BASIC answer to #ifdef.
REM
REM #IF TARGET <id[,id...]> / #ELSEIF / #ELSE / #END IF select code at
REM load (interpreter) or transpile time. The non-matching branches are
REM dropped entirely, so per-machine code costs nothing on the machines
REM that do not use it — unlike a runtime IF, which ships every branch.
REM
REM Run it different ways:
REM   basic examples/conditional-target.bas                 (target = native)
REM   basic --target c64 examples/conditional-target.bas
REM   basic --target zxspectrum examples/conditional-target.bas
REM
REM The tier axis (#IF MODERN / RETRO / PORTABLE) still works alongside
REM TARGET; --tier modern|portable picks it (interpreter default: modern).

PRINT "Border setup:"

#IF TARGET c64,c128
PRINT " POKE 53280,0 : REM VIC-II border black"
#ELSEIF TARGET zxspectrum
PRINT " BORDER 0 : REM ULA border black"
#ELSE
PRINT " (no hardware border on this machine)"
#END IF

#IF MODERN
PRINT "Modern host: sound, files, and full-width screen available."
#END IF

#IF RETRO
PRINT "Retro build: keep it small, assume 40 columns or fewer."
#END IF

PRINT "Done."
