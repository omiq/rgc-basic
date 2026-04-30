REM Should fail: IMAGE CREATE / LOAD / BLEND — RGBA blitter is modern-only.
SCREEN 2
IMAGE CREATE 1, 64, 64
IMAGE LOAD 1, "chick.png"
IMAGE BLEND 1, 0, 0, 32, 32 TO 0, 100, 100
END
