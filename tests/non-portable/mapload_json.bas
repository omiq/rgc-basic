REM Should fail: MAPLOAD + OBJLOAD — JSON parser too big for retro 64K.
DIM MAP_BG(1023)
DIM MAP_OBJ_TYPE$(15)
MAPLOAD "level1.json"
OBJLOAD "level1.hard.objects.json"
END
