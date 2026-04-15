REM ISMOUSEOVERSPRITE demo -- hover, click, and drag the sprite.
REM Requires the gfx build (basic-gfx) or canvas WASM.
REM More responsive than the mouse.bas demo.

SCREEN 1
LOADSPRITE 0, "boing.png"
SPRITEMODULATE 0, 255, 255, 255, 255, 0.10 : REM SHRINK THE SPRITE
SX = 100
SY = 100

REM --- drag state ---
DRAGGING = 0
OFFX = 0
OFFY = 0
CLS : REM CLEAR THE SCREEN

DO
    
    DRAWSPRITE 0, SX, SY

    MX = GETMOUSEX()
    MY = GETMOUSEY()

    REM --- begin drag on press-while-over ---
    IF DRAGGING = 0 AND ISMOUSEOVERSPRITE(0) AND ISMOUSEBUTTONPRESSED(0) THEN
        DRAGGING = 1
        OFFX = MX - SX
        OFFY = MY - SY
    END IF

    REM --- track while held ---
    IF DRAGGING = 1 AND ISMOUSEBUTTONDOWN(0) THEN
        SX = MX - OFFX
        SY = MY - OFFY
    END IF

    REM --- release ends drag ---
    IF DRAGGING = 1 AND ISMOUSEBUTTONRELEASED(0) THEN
        DRAGGING = 0
    END IF

    LOCATE 1, 1
    IF DRAGGING = 1 THEN
        PRINT "DRAGGING -- release to drop    ";
    ELSE
        IF ISMOUSEOVERSPRITE(0) THEN
            PRINT "click and hold to drag         ";
        ELSE
            PRINT "move mouse over the sprite     ";
        END IF
    END IF

    SLEEP 1
LOOP

