REM Should fail: mouse intrinsics — most retro targets have no mouse.
X = GETMOUSEX()
Y = GETMOUSEY()
IF ISMOUSEBUTTONDOWN(0) THEN PRINT "L"
END
