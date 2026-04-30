REM Should fail: OVERLAY ON is modern-only (raylib HUD plane).
SCREEN 2
OVERLAY ON
DRAWTEXT 4, 4, "HUD"
OVERLAY OFF
END
