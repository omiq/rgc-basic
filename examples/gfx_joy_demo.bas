10 REM Gamepad poll demo (basic-gfx only; requires a connected controller)
20 SCREEN 0
30 TEXTAT 0,0,"JOY(port,btn) DPAD: 2-5  Face: 9-12  JOYAXIS(port,0-5)"
40 TEXTAT 0,2,"Port 0  BTN2:"+STR$(JOY(0,2))+" BTN3:"+STR$(JOY(0,3))+" BTN4:"+STR$(JOY(0,4))+" BTN5:"+STR$(JOY(0,5))
50 TEXTAT 0,3,"Face 9-12: "+STR$(JOY(0,9))+" "+STR$(JOY(0,10))+" "+STR$(JOY(0,11))+" "+STR$(JOY(0,12))
60 TEXTAT 0,5,"Axes (-1000..1000): LX:"+STR$(JOYAXIS(0,0))+" LY:"+STR$(JOYAXIS(0,1))
70 TEXTAT 0,6,"RX:"+STR$(JOYAXIS(0,2))+" RY:"+STR$(JOYAXIS(0,3))+" LT:"+STR$(JOYAXIS(0,4))+" RT:"+STR$(JOYAXIS(0,5))
80 SLEEP 2
90 GOTO 30
