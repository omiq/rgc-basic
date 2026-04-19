' Gamepad poll demo (basic-gfx only; needs a connected controller)
' JOY(port, btn): D-PAD 2..5, Face 9..12. JOYAXIS(port, 0..5): -1000..1000.

SCREEN 0

DO
  TEXTAT 0, 0, "JOY(port,btn) DPAD: 2-5  Face: 9-12  JOYAXIS(port,0-5)"
  TEXTAT 0, 2, "Port 0  BTN2:" + STR$(JOY(0, 2)) + " BTN3:" + STR$(JOY(0, 3)) + " BTN4:" + STR$(JOY(0, 4)) + " BTN5:" + STR$(JOY(0, 5))
  TEXTAT 0, 3, "Face 9-12: " + STR$(JOY(0, 9)) + " " + STR$(JOY(0, 10)) + " " + STR$(JOY(0, 11)) + " " + STR$(JOY(0, 12))
  TEXTAT 0, 5, "Axes (-1000..1000): LX:" + STR$(JOYAXIS(0, 0)) + " LY:" + STR$(JOYAXIS(0, 1))
  TEXTAT 0, 6, "RX:" + STR$(JOYAXIS(0, 2)) + " RY:" + STR$(JOYAXIS(0, 3)) + " LT:" + STR$(JOYAXIS(0, 4)) + " RT:" + STR$(JOYAXIS(0, 5))
  SLEEP 2
LOOP
