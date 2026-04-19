' ============================================================
'  GFX game shell - tile map, PNG player/enemy, HUD, INKEY$ loop
'  Map is PETSCII (POKE); actors are 8x8 PNGs drawn on top.
'  Run:  ./basic-gfx examples/gfx_game_shell.bas
'
'  Text cell (C,R) on 40x25 grid  ->  pixel x = C*8, y = R*8
'  Map uses local (PX,PY); screen row = MR+PY, col = MC+PX.
' ============================================================

PRINT CHR$(14)                ' lowercase/uppercase charset

SCR  = 1024
COLR = 55296
MW   = 11
MH   = 9
MC   = 14
MR   = 6
PX   = 5  : PY = 3            ' player
EX   = 5  : EY = 1            ' enemy
C_WALL  = 11
C_FLOOR = 6
C_GOAL  = 13

' --- Map: 0 floor, 1 wall, 2 goal ------------------------------
DIM B(MW * MH - 1)
FOR R = 0 TO MH - 1
  FOR C = 0 TO MW - 1
    READ T
    B(R * MW + C) = T
  NEXT C
NEXT R

DATA 1,1,1,1,1,1,1,1,1,1,1
DATA 1,0,0,0,1,0,0,0,0,0,1
DATA 1,0,1,0,1,0,1,1,1,0,1
DATA 1,0,1,0,0,0,0,0,1,0,1
DATA 1,0,1,1,1,1,1,0,1,0,1
DATA 1,0,0,0,0,0,0,0,0,0,1
DATA 1,0,1,0,1,1,1,0,1,0,1
DATA 1,0,0,0,0,0,0,0,2,0,1
DATA 1,1,1,1,1,1,1,1,1,1,1

GOSUB DrawMap

' Slot 0 = HUD, 1 = player, 2 = enemy (higher z draws on top)
LOADSPRITE 0, "hud_panel.png"
LOADSPRITE 1, "player.png"
LOADSPRITE 2, "enemy.png"
DRAWSPRITE 0, 48, 176, 200, 0, 0, 48, 16

GOSUB DrawEnemy
GOSUB DrawPlayer
PRINT "{HOME}{WHITE}WASD MOVE  ESC QUIT  REACH {LIGHT GREEN}G{WHITE} (GOAL)"

' ================== main loop =============================
DO
  K$ = UCASE$(INKEY$())
  IF K$ = "" THEN
    SLEEP 1
  ELSE
    IF K$ = CHR$(27) THEN EXIT

    QX = PX : QY = PY
    IF K$ = "W" THEN QY = PY - 1
    IF K$ = "S" THEN QY = PY + 1
    IF K$ = "A" THEN QX = PX - 1
    IF K$ = "D" THEN QX = PX + 1

    IF (QX <> PX OR QY <> PY) AND QX >= 0 AND QX < MW AND QY >= 0 AND QY < MH THEN
      IF B(QY * MW + QX) <> 1 THEN
        IF QX = EX AND QY = EY THEN
          PRINT "{HOME}{RED}CAUGHT!{WHITE}"
          EXIT
        END IF
        IF B(QY * MW + QX) = 2 THEN
          PRINT "{HOME}{YELLOW}YOU WIN!{WHITE}"
          EXIT
        END IF
        TC = PX : TR = PY
        GOSUB RestoreTile
        PX = QX : PY = QY
        GOSUB DrawPlayer

        ' Enemy: step toward player (horizontal first, then vertical)
        TC = EX : TR = EY
        GOSUB RestoreTile
        MOVED = 0
        IF EX < PX AND MOVED = 0 THEN
          QX = EX + 1
          IF QX < MW THEN IF B(EY * MW + QX) <> 1 THEN EX = QX : MOVED = 1
        END IF
        IF EX > PX AND MOVED = 0 THEN
          QX = EX - 1
          IF QX >= 0 THEN IF B(EY * MW + QX) <> 1 THEN EX = QX : MOVED = 1
        END IF
        IF EY < PY AND MOVED = 0 THEN
          QY = EY + 1
          IF QY < MH THEN IF B(QY * MW + EX) <> 1 THEN EY = QY : MOVED = 1
        END IF
        IF EY > PY AND MOVED = 0 THEN
          QY = EY - 1
          IF QY >= 0 THEN IF B(QY * MW + EX) <> 1 THEN EY = QY
        END IF
        GOSUB DrawEnemy
        IF EX = PX AND EY = PY THEN
          PRINT "{HOME}{RED}CAUGHT!{WHITE}"
          EXIT
        END IF
      END IF
    END IF
  END IF
LOOP

END

' ==============================================================
'  Subroutines
' ==============================================================

DrawMap:
  FOR R = 0 TO MH - 1
    FOR C = 0 TO MW - 1
      SI = SCR  + (MR + R) * 40 + (MC + C)
      CI = COLR + (MR + R) * 40 + (MC + C)
      T  = B(R * MW + C)
      IF T = 1 THEN POKE SI, 160 : POKE CI, C_WALL
      IF T = 0 THEN POKE SI,  32 : POKE CI, C_FLOOR
      IF T = 2 THEN POKE SI,   7 : POKE CI, C_GOAL
    NEXT C
  NEXT R
RETURN

DrawPlayer:
  ' z = 100 above enemy (90) so both visible when adjacent
  DRAWSPRITE 1, (MC + PX) * 8, (MR + PY) * 8, 100
RETURN

DrawEnemy:
  DRAWSPRITE 2, (MC + EX) * 8, (MR + EY) * 8, 90
RETURN

RestoreTile:
  SI = SCR  + (MR + TR) * 40 + (MC + TC)
  CI = COLR + (MR + TR) * 40 + (MC + TC)
  T  = B(TR * MW + TC)
  IF T = 1 THEN POKE SI, 160 : POKE CI, C_WALL
  IF T = 0 THEN POKE SI,  32 : POKE CI, C_FLOOR
  IF T = 2 THEN POKE SI,   7 : POKE CI, C_GOAL
RETURN
