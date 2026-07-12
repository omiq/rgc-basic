REM Tier gating with #IF MODERN / RETRO / PORTABLE — strip whole features
REM out of a build by its class instead of by a named machine.
REM
REM   MODERN   kept only when tier = modern   (big host: sound, files, wide)
REM   RETRO    kept only when tier = portable (8-bit build: keep it small)
REM   PORTABLE always kept                    (the common core)
REM
REM The interpreter defaults to tier modern; --tier flips it. The C
REM transpiler derives the tier from --target (a real machine => retro),
REM so RETRO blocks only reach the vintage image, never a native binary.
REM
REM   basic examples/cond-tier.bas                  (tier = modern)
REM   basic --tier portable examples/cond-tier.bas  (act like an 8-bit build)

PRINT "== Star Chart =="

#IF PORTABLE
PRINT "Core map loaded."
#END IF

#IF MODERN
PRINT "Streaming 24-bit starfield + ambient audio."
PRINT "Autosave every quadrant to disk."
#END IF

#IF RETRO
PRINT "Char-cell map. No audio. Save via SEQ file."
#END IF

PRINT "Ready."
