' ** SPACE BATTLE COMPUTER GAME PORTABLE VERSION **

' ** STATE MACHINE STATES **
ST_QUIT=0 : ST_NEWGAME=1 : ST_NEWQUAD=2 : ST_COMMAND=3 : ST_END=4
END_DEAD=1 : END_DATE=2 : END_NOPOWER=3 : END_FAIL=4 : END_WIN=5

' ** QUADRANT CELL CODES **
' The short-range grid is an 8x8 integer array QUAD(), not a 192-char string:
' on RAM-tight 6502 targets RGC_STR_MAX caps strings at 40, which truncated
' the old THIS_QUADRANT$ and corrupted the grid. Integer codes are exact,
' small, and need no string runtime.
C_EMPTY=0 : C_SHIP=1 : C_GLONKIN=2 : C_BASE=3 : C_PLANET=4
DIM OBJ_LUT$(5)
OBJ_LUT$(0) = " "
OBJ_LUT$(1) = "E"
OBJ_LUT$(2) = "K"
OBJ_LUT$(3) = "B"
OBJ_LUT$(4) = "*"


' ** COMMAND DICTIONARY **
' -1: not initialized yet (lazy init in DoCommand)
' 0..63: initialized dict slot (allocated by dictnew)
CMD_DICT=-1

' COURSE_VEC(9,2) = nav keypad deltas; DEVICE_DAMAGE(8) = ship systems (labels via DeviceName$)
dim GALAXY(8,8),COURSE_VEC(9,2),K(3,3),VISITED_GALAXY(8,8),DEVICE_DAMAGE(8),QUAD(8,8)

' ** DISTANCE CALCULATION **
' Uses the Pythagorean theorem to calculate the distance between two points.
def FND(D)=sqr((K(I,1)-SECTOR_Y)^2+(K(I,2)-SECTOR_X)^2)

' ** RANDOM NUMBER GENERATOR **
' Generates a random number between 1 and 8.
' R is the random number generator seed.
def FNR(R)=RNDINT(8)


' ** ===== MAIN STATE LOOP ===== **
' ** EACH STATE FUNCTION DOES ITS WORK AND RETURNS THE NEXT STATE. WE
' ** DISPATCH WITH A SELECT CASE AND REPEAT UNTIL A FUNCTION HANDS BACK
' ** ST_QUIT. NO GOTOS HERE AT ALL -- JUST A DO/LOOP + SELECT CASE. **
GameState = ST_NEWGAME
do
  select case GameState
    case ST_NEWGAME
      GameState = SetupGame()
    case ST_NEWQUAD
      GameState = EnterQuadrant()
    case ST_COMMAND
      GameState = DoCommand()
    case ST_END
      GameState = ShowGameEnd()
  end select
loop until GameState = ST_QUIT
end

' ** DISPLAY TITLE SCREEN AND WAIT FOR KEY **
function TitleScreen()
    cls()
    print "-GENERIC SPACE BATTLE COMPUTER GAME-"
    print "(PORTABLE VERSION)"
    pause()
    return

end function

' ** PRINT MISSION ORDERS **
function PrintMissionOrders()
    
    cls()
    print "MISSION:\nENEMY SHIPS: "; GLONKIN_COUNT ;"\nDAYS REMAINING: "; MISSION_DAYS;"\nSPACESTATIONS: "; SPACESTATION_COUNT    
    return
end function

' ** ===== ONE-TIME GAME SETUP (NEW GAME / REPLANETT) ===== **
function SetupGame()
    Z2$=""
    ATAKFLAG=0
    SLSFLAG=0
    N=RNDINT(-1)

    ' ** DISPLAY TITLE SCREEN AND WAIT FOR KEY **
    TitleScreen()
   

    ' ** RANDOM SEED GENERATOR **
    RANDOM_SEED=RNDINT(-1)  
    print "\n          GENERATING MAP";
    SPACE_PAD$="                         "
    DATE_CUR=(RNDINT(20)+19)*100
    GAME_DATE=DATE_CUR
    MISSION_DAYS=24+RNDINT(10)
    D0=0
    SHIP_POWER=3000
    POWER_MAX=SHIP_POWER
    WARHEAD_COUNT=10
    WARHEAD_MAX=WARHEAD_COUNT
    GLONKIN_HP_BASE=200
    SHIELD_UNITS=0
    SPACESTATION_COUNT=2
    GLONKIN_COUNT=0
    X$=""
    X0$=" IS "
    
    ' INITIALIZE STARSHIPS POSITION
    QUADRANT_Y=FNR(1)
    QUADRANT_X=FNR(1)
    SECTOR_Y=FNR(1)
    SECTOR_X=FNR(1)

    ' INITIALIZE COURSE_VEC
    for I=1 to 9
      COURSE_VEC(I,1)=0
      COURSE_VEC(I,2)=0
    next I
    ' Axis: SECTOR_X = COLUMN (horizontal), SECTOR_Y = ROW (vertical). Arrays are
    ' row-first: QUAD(SECTOR_Y,SECTOR_X), G/VISITED_GALAXY(QUADRANT_Y,QUADRANT_X). Move applies
    ' col1->SECTOR_Y(row), col2->SECTOR_X(col). Up = SECTOR_Y-1, East = SECTOR_X+1.
    ' Rose: 1=E 2=NE 3=N 4=NW 5=W 6=SW 7=S 8=SE. Canonical SST table, do not transpose.
    COURSE_VEC(3,1)=-1 : COURSE_VEC(2,1)=-1 : COURSE_VEC(4,1)=-1 : COURSE_VEC(4,2)=-1 : COURSE_VEC(5,2)=-1 : COURSE_VEC(6,2)=-1
    COURSE_VEC(1,2)=1 : COURSE_VEC(2,2)=1 : COURSE_VEC(6,1)=1 : COURSE_VEC(7,1)=1 : COURSE_VEC(8,1)=1 : COURSE_VEC(8,2)=1 : COURSE_VEC(9,2)=1
    
    ' INITIALIZE DEVICE_DAMAGE
    for I=1 to 8
      DEVICE_DAMAGE(I)=0
    next I
    
    ' SETUP WHAT EXISTS IN GALAXY . . .
    ' SECTOR_ENEMIES= # GLONKINS  SECTOR_BASES= # SPACESTATIONS  SECTOR_PLANETS = # PLANETS
    for I=1 to 8
      print ".";
      for J=1 to 8
        SECTOR_ENEMIES=0
        VISITED_GALAXY(I,J)=0
        RAND_ROLL=RNDINT(100)
        select case RAND_ROLL
        case IS > 98
            SECTOR_ENEMIES=3 : GLONKIN_COUNT=GLONKIN_COUNT+3
        case IS > 95
            SECTOR_ENEMIES=2 : GLONKIN_COUNT=GLONKIN_COUNT+2
        case IS > 80
            SECTOR_ENEMIES=1 : GLONKIN_COUNT=GLONKIN_COUNT+1
        case else
            SECTOR_ENEMIES=0
        end select
        SECTOR_BASES=0
        if RNDINT(100)>96 then SECTOR_BASES=1 : SPACESTATION_COUNT=SPACESTATION_COUNT+1
        GALAXY(I,J)=SECTOR_ENEMIES*100+SECTOR_BASES*10+FNR(1)
      next J
    next I

    if GLONKIN_COUNT>MISSION_DAYS then MISSION_DAYS=GLONKIN_COUNT+1

    ' Guarantee at least one SPACESTATION and preserve original balancing tweak.
    if SPACESTATION_COUNT=0 then
      if GALAXY(QUADRANT_Y,QUADRANT_X)<200 then GALAXY(QUADRANT_Y,QUADRANT_X)=GALAXY(QUADRANT_Y,QUADRANT_X)+120 : GLONKIN_COUNT=GLONKIN_COUNT+1
      SPACESTATION_COUNT=1
      GALAXY(QUADRANT_Y,QUADRANT_X)=GALAXY(QUADRANT_Y,QUADRANT_X)+10
      QUADRANT_Y=FNR(1)
      QUADRANT_X=FNR(1)
    end if
    K7=GLONKIN_COUNT
    PrintMissionOrders()
    I=RNDINT(1)
    return ST_NEWQUAD
end function




' ** ===== ENTER A QUADRANT: SET IT UP, PLACE OBJECTS, SHORT SCAN ===== **
function EnterQuadrant()
    SECTOR_ENEMIES=0 : SECTOR_BASES=0 : SECTOR_PLANETS=0
    VISITED_GALAXY(QUADRANT_Y,QUADRANT_X)=GALAXY(QUADRANT_Y,QUADRANT_X)
    if QUADRANT_Y >= 1 and QUADRANT_Y <=8 and QUADRANT_X>=1 and QUADRANT_X<=8 then
      print

      if GAME_DATE=DATE_CUR then
        print "LOCATION:";
        QN$=QuadrantName$(QUADRANT_Y, QUADRANT_X, 0)
        print QN$;
        SRSFLAG=1
        print
        Pause() : ' ** PAUSE **
        print
      else
        if ATAKFLAG=1 then
          Pause()
          ATAKFLAG=0
          print
        end if
        QN$=QuadrantName$(QUADRANT_Y, QUADRANT_X, 0)
        SRSFLAG=1
        print "ENTERING ";QN$;" ..."
      end if
    end if

    ' Decode GALAXY(quad): SECTOR_ENEMIES/SECTOR_BASES/SECTOR_PLANETS = GLONKINs / SPACESTATIONs / PLANETS in this quadrant.
    ' G encodes the 3 digits K*100+B*10+S. Use INTEGER divide/MOD, not float
    ' tricks (int(G*.01)): on fixed-point targets (cc65) G*.01 loses precision
    ' and G/100 overflows 16.16, mis-decoding the counts -> FindEmpty overfills
    ' the quadrant and spins forever. Integer ops are exact and cheap.
    SECTOR_ENEMIES=GALAXY(QUADRANT_Y,QUADRANT_X)\100
    SECTOR_BASES=(GALAXY(QUADRANT_Y,QUADRANT_X)\10) MOD 10
    SECTOR_PLANETS=GALAXY(QUADRANT_Y,QUADRANT_X) MOD 10
    for I=1 to 3
      K(I,1)=0
      K(I,2)=0
    next I
    for I=1 to 3
      K(I,3)=0
    next I

    ' CLEAR THE QUADRANT CELL GRID
    for I=1 to 8 : for J=1 to 8 : QUAD(I,J)=C_EMPTY : next J : next I

    ' POSITION STARSHIP IN QUADRANT, THEN PLACE "SECTOR_ENEMIES" GLONKINS, &
    ' "SECTOR_BASES" SPACESTATIONS, & "SECTOR_PLANETS" PLANETS ELSE WHERE.
    PlaceToken(C_SHIP, SECTOR_Y, SECTOR_X)

    ' PLACE GLONKINS
    if SECTOR_ENEMIES >= 1 then
      for I=1 to SECTOR_ENEMIES
        FindEmpty()
        PlaceToken(C_GLONKIN, TOKEN_Y, TOKEN_X)
        K(I,1)=TOKEN_Y : K(I,2)=TOKEN_X : K(I,3)=GLONKIN_HP_BASE\2+RNDINT(GLONKIN_HP_BASE)
      next I
    end if

    ' PLACE SPACESTATIONS
    if SECTOR_BASES >= 1 then
      FindEmpty()
      B4=TOKEN_Y : B5=TOKEN_X
      PlaceToken(C_BASE, TOKEN_Y, TOKEN_X)
    end if

    ' PLACE PLANETS
    for I=1 to SECTOR_PLANETS
      FindEmpty()
      PlaceToken(C_PLANET, TOKEN_Y, TOKEN_X)
    next I

    ' DO SHORT RANGE SCAN
    return ShortRangeScan()
end function




' ** ===== COMMAND PHASE: POWER CHECK, PROMPT, DISPATCH ONE COMMAND ===== **
function DoCommand()

    ' INITIALIZE COMMAND DICTIONARY
    if CMD_DICT<0 then InitCommandDict()

    ' CHECK IF SHIP HAS ENOUGH POWER
    if SHIELD_UNITS+SHIP_POWER <= 10 or (SHIP_POWER<=10 and DEVICE_DAMAGE(7)<>0) then
      print "\n** OUT OF POWER **"
      Pause()
      END_REASON=END_NOPOWER : return ST_END
    end if

    ' COMMAND LOOP
    do
      print
      SRSFLAG=0
      A$=Ask$(" COMMAND:  ", 3)
      Z2$=A$ : ATAKFLAG=0
      if A$="SLS" then 
        SLSFLAG=1
        print " SHORT & LONG RANGE SCAN... "
        return ShortRangeScan()
      end if

      if A$="KEY" then 
        ShowKey() : ' KEY TO SRS ICONS
        continue do
      end if

      COMFLAG=0
      if A$="GAL" and DEVICE_DAMAGE(8)>=0 then A$="COM" : COMFLAG=1

      if DEVICE_DAMAGE(8)<0 and A$="GAL" then 
        print "\nSHIPS COMPUTER DISABLED"
        continue do
      end if

      ' GET COMMAND CODE
      K$=left$(A$,3)
      CMD=0

      ' Legal command?
      if dicthas(CMD_DICT, K$) then CMD=dictgetn(CMD_DICT, K$)

      ' EXECUTE COMMAND
      select case CMD
      case 1
          return Nav()
      case 2
          return ShortRangeScan()
      case 3
          return Lrs()
      case 4
          return LASERS()
      case 5
          return WARHEAD()
      case 6
          return Shields()
      case 7
          return Damage()
      case 8
          return Computer()
      case 9
          END_REASON=END_FAIL : return ST_END
      end select
      ShowCommands()
    loop
end function


function NavWarning(MSG$)
  print "WARNING:"+MSG$+"\n" : return
end function


' ** ===== COURSE CONTROL (NAV) ===== **
function Nav()

REM SPLIT FTL AND SUBLIGHT, IE. SECTOR vs SUB-SECTOR MOVEMENT 
NAV_SUBLIGHT_SPEED=0
NAV_FTL_SPEED=0

    ShowDirections()
    C1=AskNumber("COURSE (1-9) :  ", 5)
    if C1=9 then C1=1
    if C1<1 or C1>8 then NavWarning("INCORRECT COURSE") : return ST_COMMAND

    X$="8" : if DEVICE_DAMAGE(1)<0 then X$="1"
    SRSFLAG=1
    
    ask_temp$=Ask$("FTL SPEED (0-"+X$+") :  ", 5)
    if ask_temp$="0" then NavWarning("ENGINES DISABLED"): return ST_COMMAND
    if INSTR(ask_temp$, ".")>0 then 
      NAV_FTL_SPEED=VAL(left$(ask_temp$, INSTR(ask_temp$, ".")-1))
      NAV_SUBLIGHT_SPEED=VAL(right$(ask_temp$, LEN(ask_temp$)-INSTR(ask_temp$, ".")))
      PRINT "NAV_FTL_SPEED: ";(NAV_FTL_SPEED);" NAV_SUBLIGHT_SPEED: ";(NAV_SUBLIGHT_SPEED);
    else
      NAV_FTL_SPEED=VAL(ask_temp$)
    end if


    NAV_WARP_UNITS=NAV_FTL_SPEED*10+NAV_SUBLIGHT_SPEED
    if NAV_WARP_UNITS=0 then return ST_COMMAND
    if NAV_FTL_SPEED>8 or NAV_SUBLIGHT_SPEED>9 or NAV_WARP_UNITS>80 then NavWarning("ENGINES WONT TAKE FTL "+ask_temp$+"!") : return ST_COMMAND
    if DEVICE_DAMAGE(1)<0 and NAV_WARP_UNITS>10 then NavWarning("FTL DAMAGED: MAX SPEED = 1") : return ST_COMMAND
    N=NAV_FTL_SPEED*8+(NAV_SUBLIGHT_SPEED*8+5)\10
    if SHIP_POWER-N<0 then
      NavWarning("INSUFFICIENT POWER FOR FTL "+ask_temp$+"!")
      if SHIELD_UNITS<N-SHIP_POWER or DEVICE_DAMAGE(7)<0 then return ST_COMMAND
      NavWarning("SHIELD POWER DEPLOYED IS "+str$(SHIELD_UNITS)+" UNITS.")
      return ST_COMMAND
    end if

    for I=1 to SECTOR_ENEMIES
      if K(I,3)=0 then continue for
      PlaceToken(C_EMPTY, K(I,1), K(I,2)) : FindEmpty()
      K(I,1)=TOKEN_Y : K(I,2)=TOKEN_X : PlaceToken(C_GLONKIN, K(I,1), K(I,2))
    next I
    GLONKINsFire()
    if SHIPDEAD then END_REASON=END_DEAD : return ST_END

    D1=0 : D6=0 : if NAV_FTL_SPEED>=1 then D6=1
    for I=1 to 8
      if DEVICE_DAMAGE(I)>=0 then continue for
      DEVICE_DAMAGE(I)=DEVICE_DAMAGE(I)+D6
      if DEVICE_DAMAGE(I)<0 then continue for
      if D1=0 then D1=1 : print "\nDAMAGE CONTROL REPORT :   "
      print DeviceName$(I);" REPAIR COMPLETED"
    next I

    if RNDINT(100)<=20 then
      J=FNR(1)
      if RNDINT(100)<60 then
        DEVICE_DAMAGE(J)=DEVICE_DAMAGE(J)-RNDINT(5) : NavWarning("DAMAGED "+DeviceName$(J))
      else
        DEVICE_DAMAGE(J)=DEVICE_DAMAGE(J)+RNDINT(3) : NavWarning("PARTLY REPAIRED "+DeviceName$(J))
      end if

    end if

    PlaceToken(C_EMPTY, SECTOR_Y, SECTOR_X)
    X1=COURSE_VEC(C1,1)+(COURSE_VEC(C1+1,1)-COURSE_VEC(C1,1))*(C1-int(C1))
    X2=COURSE_VEC(C1,2)+(COURSE_VEC(C1+1,2)-COURSE_VEC(C1,2))*(C1-int(C1))
    X=SECTOR_Y : Y=SECTOR_X : Q4=QUADRANT_Y : Q5=QUADRANT_X : CrossedQuadrant=0

    for I=1 to N
      SECTOR_Y=SECTOR_Y+X1 : SECTOR_X=SECTOR_X+X2
      if SECTOR_Y<1 or SECTOR_Y>=9 or SECTOR_X<1 or SECTOR_X>=9 then CrossedQuadrant=1 : exit for
      if CheckSector(C_EMPTY, SECTOR_Y, SECTOR_X)=1 then continue for
      SECTOR_Y=int(SECTOR_Y-X1) : SECTOR_X=int(SECTOR_X-X2)
      NavWarning("FTL SHUTDOWN: SECTOR "+SECTOR_X+","+SECTOR_Y+" BAD NAVIGATION")
      SRSFLAG=1 : exit for
    next I

    if CrossedQuadrant=1 then
      X=8*QUADRANT_Y+X+N*X1 : Y=8*QUADRANT_X+Y+N*X2
      QUADRANT_Y=int(X/8) : QUADRANT_X=int(Y/8)
      SECTOR_Y=int(X-QUADRANT_Y*8) : SECTOR_X=int(Y-QUADRANT_X*8)
      if SECTOR_Y=0 then QUADRANT_Y=QUADRANT_Y-1 : SECTOR_Y=8
      if SECTOR_X=0 then QUADRANT_X=QUADRANT_X-1 : SECTOR_X=8
      X5=0
      if QUADRANT_Y<1 then X5=1 : QUADRANT_Y=1 : SECTOR_Y=1
      if QUADRANT_Y>8 then X5=1 : QUADRANT_Y=8 : SECTOR_Y=8
      if QUADRANT_X<1 then X5=1 : QUADRANT_X=1 : SECTOR_X=1
      if QUADRANT_X>8 then X5=1 : QUADRANT_X=8 : SECTOR_X=8
      if X5<>0 then
        NavWarning("NAV ERROR: SHUTDOWN: "+SECTOR_Y+","+SECTOR_X+" Q "+QUADRANT_Y+","+QUADRANT_X)
        SRSFLAG=1 : Pause()
        if DATE_CUR>GAME_DATE+MISSION_DAYS then END_REASON=END_DATE : return ST_END
      end if
      if 8*QUADRANT_Y+QUADRANT_X<>8*Q4+Q5 then DATE_CUR=DATE_CUR+1 : ManeuverPOWER() : return ST_NEWQUAD
    end if

    SECTOR_Y=int(SECTOR_Y) : SECTOR_X=int(SECTOR_X)
    PlaceToken(C_SHIP, SECTOR_Y, SECTOR_X)
    ManeuverPOWER()
    DATE_CUR=DATE_CUR+1
    if DATE_CUR>GAME_DATE+MISSION_DAYS then END_REASON=END_DATE : return ST_END
    return ShortRangeScan()
end function

' MANEUVER POWER S/R **
function ManeuverPOWER()
    SHIP_POWER=SHIP_POWER-N-10
    if SHIP_POWER>=0 then return
    print "\nDIVERTED POWER TO"
    print "COMPLETE THE MANOEUVRE."
    SHIELD_UNITS=SHIELD_UNITS+SHIP_POWER
    SHIP_POWER=0
    if SHIELD_UNITS<=0 then SHIELD_UNITS=0
    return
end function

function disp_quadrant_cell(this_row, this_col)
  if (this_row < 1 or this_row > 8) or (this_col < 1 or this_col > 8) then
    print "=:=:=";
  else
    cell_code = GALAXY(this_row, this_col)
    print str$(cell_code\100) + ":" + str$((cell_code\10)mod10) + ":" + str$(cell_code mod10);
  end if
end function

' ** ===== LONG RANGE SCAN ===== **
function Lrs()

    K1=0
    if DEVICE_DAMAGE(3)<0 then 
      print
      print "LONG RANGE SENSORS DOWN"
      SLSFLAG=0
      return ST_COMMAND
    end if


  ' - GALAXY(8,8) = galactic record (galaxy map) — integer array.
  ' - VISITED_GALAXY(8,8) = explored/known galaxy — integer array.
  ' - QUAD(8,8) = current quadrant cell grid — integer array (old THIS_QUADRANT$ 192-char string)


    ' PRINT LONG RANGE SCAN FOR QUADRANT
    print "\n  LONG RANGE SCAN:  ";QUADRANT_Y;",";QUADRANT_X
  

    ' LONG RANGE SCAN LOOP
    for scan_row = QUADRANT_Y-1 to QUADRANT_Y+1
        disp_quadrant_cell(scan_row, QUADRANT_X-1)
        print " | ";
        disp_quadrant_cell(scan_row, QUADRANT_X)
        print " | ";
        disp_quadrant_cell(scan_row, QUADRANT_X+1)
        print "\n";
    next scan_row

    K1=0 : if SLSFLAG=1 then SLSFLAG=0
    
    return ST_COMMAND
end function


' ** ===== PHASER CONTROL ===== **
function LASERS()
    if DEVICE_DAMAGE(4)<0 then print "\nLASERS DOWN" : return ST_COMMAND
    if SECTOR_ENEMIES<=0 then NoEnemyMsGALAXY() : return ST_COMMAND
    if DEVICE_DAMAGE(8)<0 then print "\nCOMPUTER FAILURE"
    print "\nLASERS LOCKED ON TARGET!  "
    
    do
        print "\nPOWER AVAILABLE = ";SHIP_POWER;" UNITS"
        X=AskNumber("\nNUMBER OF UNITS TO FIRE :  ", 5)
        if X<=0 then return ST_COMMAND
    loop until SHIP_POWER-X>=0

    SHIP_POWER=SHIP_POWER-X
    if DEVICE_DAMAGE(7)<0 then X=X*RNDINT(100)\100

    ' CALCULATE HIT POINTS
    H1=int(X/SECTOR_ENEMIES)

    ' FIRE LASERS
    for I=1 to 3
      if K(I,3)<=0 then continue for
      H=((H1/FND(0))*(200+RNDINT(100)))\100
      if H*20<=3*K(I,3) then
        print "\n MISSED"
        print " AT ";K(I,1);",";K(I,2)
        continue for
      end if

      ' HIT GLONKIN
      K(I,3)=K(I,3)-H 
      print H;" HIT! ";K(I,1);",";K(I,2)
      if K(I,3)>0 then
        print " (SCAN SHOWS ";int(K(I,3));" UNITS REMAINING)"
        continue for
      end if

      ' DESTROY GLONKIN
      print " *** GLONKIN DESTROYED ***"
      SECTOR_ENEMIES=SECTOR_ENEMIES-1 : GLONKIN_COUNT=GLONKIN_COUNT-1 : PlaceToken(C_EMPTY, K(I,1), K(I,2))
      K(I,3)=0 : GALAXY(QUADRANT_Y,QUADRANT_X)=GALAXY(QUADRANT_Y,QUADRANT_X)-100 : VISITED_GALAXY(QUADRANT_Y,QUADRANT_X)=GALAXY(QUADRANT_Y,QUADRANT_X)
      if GLONKIN_COUNT<=0 then END_REASON=END_WIN : return ST_END
    next I

    ' CHECK IF GLONKINS ARE LEFT
    if SECTOR_ENEMIES>0 then Pause()

    ' FIRE BACK AT STARSHIP
    GLONKINsFire()

    ' CHECK IF SHIP IS DEAD
    if SHIPDEAD then END_REASON=END_DEAD : return ST_END

    ' RETURN SUCCESS
    return ST_COMMAND
end function


function TorpedoEndTurn(MSG$)
  if MSG$<>"" then print MSG$
  if SECTOR_ENEMIES<>0 then Pause()
  GLONKINsFire()
  if SHIPDEAD then END_REASON=END_DEAD : return ST_END
  return ST_COMMAND
end function


' ** ===== WARHEAD ===== **
function WARHEAD()
    if WARHEAD_COUNT<=0 then print "\nALL WARHEADS EXPENDED" : return ST_COMMAND
    if DEVICE_DAMAGE(5)<0 then print "\nWARHEADS ARE NOT OPERATIONAL" : return ST_COMMAND
    do
      ShowDirections() : ' ** DIRECTION HELPER **
      print
      C1=AskNumber("WARHEAD COURSE (1-9) :  ", 5)
      if C1=9 then C1=1
      if C1<1 or C1>=9 then
          print "ALERT:, INCORRECT COURSE DATA";:  return ST_COMMAND
      end if

      ' CALCULATE WARHEAD COURSE
      X1=COURSE_VEC(C1,1)+(COURSE_VEC(C1+1,1)-COURSE_VEC(C1,1))*(C1-int(C1)) : SHIP_POWER=SHIP_POWER-2 : WARHEAD_COUNT=WARHEAD_COUNT-1
      X2=COURSE_VEC(C1,2)+(COURSE_VEC(C1+1,2)-COURSE_VEC(C1,2))*(C1-int(C1)) : X=SECTOR_Y : Y=SECTOR_X
      print "\nWARHEAD TRACKING:"
      RetryCourse=0
      do
        X=X+X1 : Y=Y+X2 : X3=X : Y3=Y
        if X3<1 or X3>8 or Y3<1 or Y3>8 then return TorpedoEndTurn(" ** WARHEAD MISSED **")

        ' PRINT WARHEAD TRACKING
        print " ";X3;",";Y3

        ' CHECK IF SECTOR IS EMPTY
        if CheckSector(C_EMPTY, X, Y)=1 then continue do

        ' CHECK IF SECTOR IS GLONKIN
        if CheckSector(C_GLONKIN, X, Y)=1 then

          ' GLONKIN KILLED
          print " *** GLONKIN DESTROYED ***"
          SECTOR_ENEMIES=SECTOR_ENEMIES-1 : if SECTOR_ENEMIES>0 then Pause()
          GLONKIN_COUNT=GLONKIN_COUNT-1

          ' CHECK IF ALL GLONKINS ARE DESTROYED
          if GLONKIN_COUNT<=0 then END_REASON=END_WIN : return ST_END
          
          ' FIND GLONKIN INDEX
          HitIdx=3
          for I=1 to 3
            if X3=K(I,1) and Y3=K(I,2) then 
                HitIdx=I
                exit for
            end if
          next I

          ' DESTROY GLONKIN
          K(HitIdx,3)=0
          PlaceToken(C_EMPTY, X, Y)

          ' UPDATE QUADRANT DATA
          GALAXY(QUADRANT_Y,QUADRANT_X)=SECTOR_ENEMIES*100+SECTOR_BASES*10+SECTOR_PLANETS : VISITED_GALAXY(QUADRANT_Y,QUADRANT_X)=GALAXY(QUADRANT_Y,QUADRANT_X) : GLONKINsFire()
          
          ' CHECK IF SHIP IS DEAD
          if SHIPDEAD then END_REASON=END_DEAD : return ST_END

          ' RETURN SUCCESS
          return ST_COMMAND
        end if

        if CheckSector(C_PLANET, X, Y)=1 then return TorpedoEndTurn(" ** PLANET AT "+str$(X3)+","+str$(Y3)+" ABSORBED WARHEAD **")

        ' CHECK IF SECTOR IS SPACESTATION
        if CheckSector(C_BASE, X, Y)=0 then
          RetryCourse=1
          exit do
        end if
        print " *** SPACESTATION DESTROYED ***"
        Pause()
        SECTOR_BASES=SECTOR_BASES-1 : SPACESTATION_COUNT=SPACESTATION_COUNT-1

        ' CHECK IF ALL SPACESTATIONS ARE DESTROYED
        if SPACESTATION_COUNT<=0 and GLONKIN_COUNT<=DATE_CUR-GAME_DATE-MISSION_DAYS then
          NavWarning("FAILURE - SPACESTATIONS DESTROYED")
          END_REASON=END_FAIL : return ST_END
        end if

        ' DESTROY SPACESTATION
        print "\nSPACESTATION LOST: FAILURE." : D0=0
        PlaceToken(C_EMPTY, X, Y)

        ' UPDATE QUADRANT DATA
        GALAXY(QUADRANT_Y,QUADRANT_X)=SECTOR_ENEMIES*100+SECTOR_BASES*10+SECTOR_PLANETS : VISITED_GALAXY(QUADRANT_Y,QUADRANT_X)=GALAXY(QUADRANT_Y,QUADRANT_X) : GLONKINsFire()
        if SHIPDEAD then END_REASON=END_DEAD : return ST_END
        return ST_COMMAND
      loop

      ' CHECK IF RETRY COURSE IS NEEDED
      if RetryCourse=1 then continue do
    loop

    ' RETURN SUCCESS
    return ST_COMMAND
end function


' ** ===== SHIELD CONTROL ===== **
function Shields()
    if DEVICE_DAMAGE(7)<0 then print "\nSHIELD CONTROL DOWN" : return ST_COMMAND
    print "\nPOWER AVAILABLE = ";SHIP_POWER+SHIELD_UNITS
    X=AskNumber("\nNUMBER OF UNITS TO SHIELDS :  ", 5)
    
    if X<0 or SHIELD_UNITS=X or X>SHIP_POWER+SHIELD_UNITS then
      if X>SHIP_POWER+SHIELD_UNITS then print "\nSHIELD CONTROL ERROR"
      print "<SHIELDS UNCHANGED>" : return ST_COMMAND
    end if

    SHIP_POWER=SHIP_POWER+SHIELD_UNITS-X : SHIELD_UNITS=X
    print "\nSHIELDS NOW AT ";int(SHIELD_UNITS) : return ST_COMMAND
end function


' ** ===== DAMAGE CONTROL ===== **
function Damage()
    if DEVICE_DAMAGE(6)<0 then
      print "\nDAMAGE CONTROL DOWN"
      if D0=0 then return ST_COMMAND
    end if
    ' CHECK IF DAMAGE CONTROL IS AVAILABLE
    if DEVICE_DAMAGE(6)<0 and D0<>0 then
      ' CALCULATE TIME TO REPAIR
      D3=0 : for I=1 to 8 : if DEVICE_DAMAGE(I)<0 then D3=D3+1
      next I : if D3=0 then return ST_COMMAND
      ' PRINT REPAIR REPORT

      A$=Ask$("\nALERT: ESTIMATED REPAIR ETA: "+D3+" DAYS\nAUTHORISE (Y/N)? ", 1)
      if A$<>"Y" then return ST_COMMAND

      ' REPAIR DEVICES
      for I=1 to 8
        if DEVICE_DAMAGE(I)<0 then DEVICE_DAMAGE(I)=0
      next I
      ' UPDATE DATE
      DATE_CUR=DATE_CUR+D3
    end if

    ' PRINT REPAIR REPORT
    print "\n SYSTEM              STATE OF REPAIR"
    print      " ------------------- -----------------"
    for I=1 to 8
      print " ";DeviceName$(I);left$(SPACE_PAD$,20-len(DeviceName$(I)));
      
      if DEVICE_DAMAGE(I)<0 then print "DAMAGED     ";DEVICE_DAMAGE(I);
      if DEVICE_DAMAGE(I)>=0 then print "OPERATIONAL ";DEVICE_DAMAGE(I);
    next I
    return ST_COMMAND
end function


' ** ===== GLONKINS SHOOT BACK (SETS SHIPDEAD IF SHIELDS FAIL) ===== **
function GLONKINsFire()
    SHIPDEAD=0
    if SECTOR_ENEMIES<=0 then return
    if D0<>0 then print "\nSPACESTATION SHIELDS PROTECT THE STARSHIP"
    if D0<>0 then return

    ' CHECK IF GLONKINS ARE LEFT
    for I=1 to 3
      if K(I,3)<=0 then continue for

      ' CALCULATE HIT POINTS
      H=((K(I,3)/FND(1))*(200+RNDINT(100)))\100 : SHIELD_UNITS=SHIELD_UNITS-H : K(I,3)=K(I,3)\(2+RNDINT(2))
       print H;" UNIT HIT STARSHIP FROM ";K(I,1);",";K(I,2)

      ' CHECK IF SHIELDS ARE DOWN
      if SHIELD_UNITS<=0 then SHIPDEAD=1 : return
      print " <SHIELDS DOWN TO ";SHIELD_UNITS;" UNITS>"
      if H<20 then continue for

      ' CHECK IF HIT IS CRITICAL
      if RNDINT(100)>60 or H*50<=SHIELD_UNITS then continue for

      ' DAMAGE CONTROL REPORT
      J=FNR(1) : DEVICE_DAMAGE(J)=DEVICE_DAMAGE(J)-RNDINT(3)
      print "UPDATE: "+DeviceName$(J)+" DAMAGED BY THE HIT"
    next I
    ATAKFLAG=1
    return
end function


' ** ===== END-OF-GAME ===== **
function ShowGameEnd()
    if END_REASON=END_DEAD or END_REASON=END_WIN then Pause()
    if END_REASON=END_DEAD then print "\nTHE STARSHIP HAS BEEN DESTROYED.\nTHE EARTH WILL BE CONQUERED"
    if END_REASON=END_DATE then print "\nMISSION TIME EXPIRED. DATE ";DATE_CUR
    if END_REASON=END_WIN then print "\nCONGRATULATIONS, YOU SAVED THE EARTH!"
    if END_REASON=END_FAIL then print "\nMISSION FAILED."
    print "\nGLONKINS LEFT: ";GLONKIN_COUNT
    print "DATE: ";DATE_CUR
    if END_REASON=END_WIN then
      EL=DATE_CUR-GAME_DATE : if EL<1 then EL=1
      print "SCORE: ";int(1000*(K7/EL)^2)
    end if
    if SPACESTATION_COUNT=0 then return ST_QUIT
    print "\nGAME OVER"
    A$=Ask$("\nPLAY AGAIN (YES/NO) :  ", 3)
    if A$="YES" then return ST_NEWGAME
    return ST_QUIT
end function


' ** ===== SHORT RANGE SCAN & SUMMARY (SLS CHAINS INTO LRS) ===== **
function ShortRangeScan()
    if ATAKFLAG=1 then
      
      Pause()
    end if

    ' CHECK IF SHORT RANGE SENSORS ARE OUT
    if DEVICE_DAMAGE(2)<0 then
      
      print "\n*** SHORT RANGE SENSORS DAMAGED ***"
      if SLSFLAG=1 then return Lrs()
      return ST_COMMAND
    end if

    ' PRINT SHORT RANGE SCAN + SUMMARY DATA
    if SRSFLAG=0 then
      
      print "\n SHORT RANGE SCAN + SUMMARY "
    end if
    SRSFLAG=0
    ATAKFLAG=0
    Docked=0


  for S_ROW=1 TO 8
   
   print OBJ_LUT$(QUAD(S_ROW, 1)); ":";
   print OBJ_LUT$(QUAD(S_ROW, 2)); ":";
   print OBJ_LUT$(QUAD(S_ROW, 3)); ":";
   print OBJ_LUT$(QUAD(S_ROW, 4)); ":";
   print OBJ_LUT$(QUAD(S_ROW, 5)); ":";
   print OBJ_LUT$(QUAD(S_ROW, 6)); ":";
   print OBJ_LUT$(QUAD(S_ROW, 7)); ":";
   print OBJ_LUT$(QUAD(S_ROW, 8)); "\n";
   
  next S_ROW


    ' ' CHECK IF SHIP IS DOCKED
    ' for S_ROW=SECTOR_Y-1 to SECTOR_Y+1
    '   for S_COL=SECTOR_X-1 to SECTOR_X+1
    '     if S_ROW<1 or S_ROW>8 or S_COL<1 or S_COL>8 then continue for
    '     if CheckSector(C_BASE, S_ROW, S_COL)=1 then
    '       Docked=1
    '       exit for
    '     end if
    '   next S_COL
    '   if Docked=1 then
    '     exit for
    '   end if
    ' next S_ROW

    ' if Docked=1 then
    '   D0=1
    '   C$="DOCKED"
    '   SHIP_POWER=POWER_MAX
    '   WARHEAD_COUNT=WARHEAD_MAX
    '   print
    '   print "SHIELDS DROPPED FOR DOCKING "
    '   SHIELD_UNITS=0
    ' else

    '   ' OTHERWISE ...
    '   D0=0

    '   ' CHECK IF COMBAT AREA IS RED
    '   if SECTOR_ENEMIES>0 then C$="RED"

    '   ' COMBAT AREA IS GREEN
    '   if SECTOR_ENEMIES=0 then
    '     C$="GREEN"
    '     if SHIP_POWER<POWER_MAX\10 then C$="AMBER"
    '   end if
    ' end if

    ' ' COMBAT!
    ' if SECTOR_ENEMIES>0 then
    '   print "[[ BATTLE STATIONS ]]";FCOL$
    ' end if

    ' LOW$=" LOW!"
    ' print
    ' print "    1 2 3 4 5 6 7 8"
    ' print "   +-+-+-+-+-+-+-+-- DATE  ";DATE_CUR
    
    ' ' PRINT QUADRANT
    ' for I=1 to 8
    '   I$=right$(str$(I),1)
    '   print " ";I$;" |"; : ' BORDER

    '   ' PRINT QUADRANT CELLS (integer cell code -> glyph)
    '   for J = 1 to 8
    '     CELLCODE=QUAD(I,J)
    '     if CELLCODE=C_EMPTY then print " ";
    '     if CELLCODE=C_SHIP then print "E";
    '     if CELLCODE=C_GLONKIN then print "K";
    '     if CELLCODE=C_BASE then print "B";
    '     if CELLCODE=C_PLANET then print "*";
    '     print "|";
    '   next J

    '   ' PRINT SUMMARY DATA
    '   select case I
    '   case 1
    '     print " DAYS LEFT ";GAME_DATE+MISSION_DAYS-DATE_CUR;
    '   case 2
    '     print " CONDITION "; : print C$;
    '   case 3
    '     print " QUADRANT  ";QUADRANT_Y;",";QUADRANT_X;
    '   case 4
    '     print " SECTOR    ";SECTOR_Y;",";SECTOR_X;
    '   case 5
    '     print " WARHEADES ";int(WARHEAD_COUNT);
    '   case 6
    '     print " POWER    ";int(SHIP_POWER+SHIELD_UNITS);
    '   case 7
    '     print " SHIELDS   ";int(SHIELD_UNITS);
    '     if SHIELD_UNITS<201 and SECTOR_ENEMIES>0 then print LOW$;
    '   case 8
    '     print " ENEMIES  ";int(GLONKIN_COUNT);
    '   end select
    '   print
    ' next I

    ' ' PRINT MAX FTL
    ' print "   +-+-+-+-+-+-+-+-+";
    ' MW=SHIP_POWER\8
    ' if MW>8 then MW=8
    ' if DEVICE_DAMAGE(1)<0 then MW=1
    ' print " MAX FTL  ";MW
    if SLSFLAG=1 then return Lrs()
    return ST_COMMAND
end function


' ** ===== LIBRARY COMPUTER ===== **
function Computer()

    ' CHECK COMPUTER IS AVAILABLE
    if DEVICE_DAMAGE(8)<0 then 
        print "\nCOMPUTER DISABLED"
        return ST_COMMAND
    end if

    ' PRINT FUNCTIONS AVAILABLE FROM COMPUTER
    print "\nCOMMANDS AVAILABLE:" 
    print " 0 - CUMULATIVE LOG"
    print " 1 - STATUS & DAMAGE REPORT"
    print " 2 - WARHEAD TARGETING DATA"
    print " 3 - SPACESTATION NAV DATA"
    print " 4 - DIRECTION/DISTANCE CALCULATOR"
    print " 5 - SYSTEM REGION MAP"
    ' CHECK IF COMPUTER IS ACTIVE
    COM_CMD=0
    if COMFLAG=1 then
      print "0"
    else
      COM_CMD=AskNumber("\nENTER COMMAND :  ", 1)
      if COM_CMD<0 or COM_CMD>5 then return ST_COMMAND
      if LII$="" then return ST_COMMAND
    end if

    select case COM_CMD
    case 0
      return ComputerGalacticLog()
    case 1
      return ComputerStatusReport()
    case 2
      return ComputerNavCalcGLONKIN()
    case 3
      return ComputerBaseNav()
    case 4
      return ComputerCalculator()
    case 5
      return ComputerGalaxyRegionMap()
    end select
    return ST_COMMAND
end function


function PrintGalaxyCell(GV)
  print (GV\100);((GV\10)mod10);(GV mod10);
  return
end function


function PrintGalaxyDataRow(MAP_ROW)
  GALFLAG=0
  for J=1 to 8
    if MAP_ROW=QUADRANT_Y and J=QUADRANT_X then print "|"; : GALFLAG=1
    if not (MAP_ROW=QUADRANT_Y and (J=QUADRANT_X or J-1=QUADRANT_X)) then print "|";
    if VISITED_GALAXY(MAP_ROW,J)=0 then print "   "; : continue for
    PrintGalaxyCell(VISITED_GALAXY(MAP_ROW,J))
    if GALFLAG=1 then print "|"; : GALFLAG=0
  next J
  return
end function


function PrintRegionRow(MAP_ROW)
  QN$=QuadrantName$(MAP_ROW, 1, 1) : J0=11-len(QN$)\2
  print "|";
  print tab(J0);QN$;
  print tab(18);"|";
  QN$=QuadrantName$(MAP_ROW, 5, 1) : J0=27-len(QN$)\2
  print tab(J0);QN$; : print tab(34);"|";
  return
end function


' ** ===== COMPUTER CUMULATIVE GALACTIC LOG (CMD 0) ===== **
function ComputerGalacticLog()
  print "  COMPUTER LOG FOR QUADRANT ";QUADRANT_Y;",";QUADRANT_X;"\n"
  for J=1 to 8
    print "  ";J;" ";
  next J
  print "\n  +---+---+---+---+---+---+---+----"
  for I=1 to 8
    print " ";I;
    if I=QUADRANT_Y then print "";
    PrintGalaxyDataRow(I)
    if I=QUADRANT_Y and QUADRANT_X=8 then
      print
    else
      print "|"
    end if
    if I<8 then print "  +---+---+---+---+---+---+---+----"
  next I
  print "  +---+---+---+---+---+---+---+---+"
  return ST_COMMAND
end function


' ** ===== COMPUTER REGION MAP (CMD 5) ===== **
function ComputerGalaxyRegionMap()
  print "  THE KNOWN REGION: \n\n   ";
  for J=1 to 8
    print "  ";J;" ";
  next J
  print "\n  +---+---+---+---+---+---+---+----"
  for I=1 to 8
    print " ";I;
    if I=QUADRANT_Y then print "";
    PrintRegionRow(I)
    print
    if I<8 then print "  +---+---+---+---+---+---+---+----"
  next I
  print "  +---+---+---+---+---+---+---+---+"
  return ST_COMMAND
end function


' ** ===== COMPUTER BASE NAV ===== **
function ComputerBaseNav()
    if SECTOR_BASES<>0 then
      print "\nFROM STARSHIP TO SPACESTATION"
      return ComputerCalcCompute(SECTOR_X, SECTOR_Y, B4, B5, 10)
    end if
    print "\nWARNING:NO"
    print "SPACESTATIONS NEARBY." : return ST_COMMAND
end function


' ** ===== COMPUTER STATUS REPORT ===== **
function ComputerStatusReport()

    print " STATUS REPORT: \n"
    print " ENEMIES LEFT : ";GLONKIN_COUNT
    print " POWER        : ";SHIP_POWER+SHIELD_UNITS
    print " WARHEADS     : ";WARHEAD_COUNT
    print " DAYS LEFT    : ";GAME_DATE+MISSION_DAYS-DATE_CUR   
    print " SPACESTATIONS: ";SPACESTATION_COUNT

    return Damage()
end function


' ** ===== COMPUTER NAV CALC GLONKIN ===== **
function ComputerNavCalcGLONKIN()
    if SECTOR_ENEMIES<=0 then NoEnemyMsGALAXY() : return ST_COMMAND
    
    print "\nFROM STARSHIP TO ENEMY "
    for I=1 to 3
      if K(I,3)<=0 then continue for
      ComputerCalcCompute(SECTOR_X, SECTOR_Y, K(I,1), K(I,2), 10)
    next I
    return ST_COMMAND
end function


' ** ===== COMPUTER CALCULATOR ===== **
function ComputerCalculator()

    print "\nCALCULATOR:"
    print "\nLOCATION: ";QUADRANT_Y;",";QUADRANT_X
    print "             SECTOR ";SECTOR_Y;",";SECTOR_X

    FROM_Y=AskNumber("\nFROM (Y) :  ", 4)
    if FROM_Y=0 then print "\nCALCULATION ABORTED!" : return ST_COMMAND

    FROM_X=AskNumber("\nFROM (X) :  ", 4)
    if FROM_X=0 then print "\nCALCULATION ABORTED!" : return ST_COMMAND

    TO_Y=AskNumber("\nTO (Y) :  ", 4)
    if TO_Y=0 then print "\nCALCULATION ABORTED!" : return ST_COMMAND

    TO_X=AskNumber("\nTO (X) :  ", 4)
    if TO_X=0 then print "\nCALCULATION ABORTED!" : return ST_COMMAND

    if FROM_Y=TO_Y and FROM_X=TO_X then
      print "\nNO RESULTS POSSIBLE!"
      return ST_COMMAND
    end if

    return ComputerCalcCompute(FROM_Y, FROM_X, TO_Y, TO_X, 1)
end function



' FROM/TO = sector Y,X; DIST_DIV=1 (calculator) or 10 (ship/base nav in-sector)
function ComputerCalcCompute(FROM_Y, FROM_X, TO_Y, TO_X, DIST_DIV)
    DX=TO_X-FROM_X
    DY=FROM_Y-TO_Y
    if DX>=0 then
      if DY<0 then
        PLANETT_DIRECTION=7
        if abs(DY)>=abs(DX) then
          print "\n DIRECTION =";
          DIRECTION=PLANETT_DIRECTION+(abs(DX)/abs(DY))
        else
          print "\n DIRECTION =";
          DIRECTION=PLANETT_DIRECTION+(((abs(DX)-abs(DY))+abs(DX))/abs(DX))
        end if
      else
        if DX>0 or DY>0 then PLANETT_DIRECTION=1
        if DY=0 then PLANETT_DIRECTION=5
        if abs(DY)<=abs(DX) then
          print "\n DIRECTION =";
          DIRECTION=PLANETT_DIRECTION+(abs(DY)/abs(DX))
        else
          print "\n DIRECTION =";
          DIRECTION=PLANETT_DIRECTION+(((abs(DY)-abs(DX))+abs(DY))/abs(DY))
        end if
      end if
    else
      if DY>0 then
        PLANETT_DIRECTION=3
        if abs(DY)>=abs(DX) then
          print "\n DIRECTION =";
          DIRECTION=PLANETT_DIRECTION+(abs(DX)/abs(DY))
        else
          print "\n DIRECTION =";
          DIRECTION=PLANETT_DIRECTION+(((abs(DX)-abs(DY))+abs(DX))/abs(DX))
        end if
      else
        PLANETT_DIRECTION=5
        if abs(DY)<=abs(DX) then
          print "\n DIRECTION =";
          DIRECTION=PLANETT_DIRECTION+(abs(DY)/abs(DX))
        else
          print "\n DIRECTION =";
          DIRECTION=PLANETT_DIRECTION+(((abs(DY)-abs(DX))+abs(DY))/abs(DY))
        end if
      end if
    end if
    ' DIRECTION is an integer 1..9 in integer mode (no sub-point rounding)
    print DIRECTION
    print " DISTANCE  =";
    DIST=sqr(DX^2+DY^2)
    if DIST_DIV>1 then DIST=DIST/DIST_DIV
    ' DIST is an integer distance (isqrt) in integer mode
    print DIST
    return ST_COMMAND
end function


' ** ===== SHARED MESSAGE: NO ENEMY IN QUADRANT ===== **
function NoEnemyMsGALAXY()
    print "ALERT: NO ENEMY SHIPS DETECTED"
    return
end function


' FIND EMPTY PLACE IN QUADRANT (FOR THINGS)
function FindEmpty()
    ' ** RETRY UNTIL SQUARE IS EMPTY (THREE SPACES) **
    do
        RANDOM_X=FNR(1) : RANDOM_Y=FNR(1)
    loop until CheckSector(C_EMPTY, RANDOM_X, RANDOM_Y)=1
    TOKEN_Y=int(RANDOM_X)
    TOKEN_X=int(RANDOM_Y)
    return
end function


' SET SECTOR (TOKEN_Y, TOKEN_X) TO CELL CODE in the quadrant grid
function PlaceToken(CELLCODE, TOKEN_Y, TOKEN_X)
    QX=int(TOKEN_Y) : QY=int(TOKEN_X)
    QUAD(QX,QY)=CELLCODE
    return
end function

' RETURN 1 IF SECTOR (TOKEN_Y, TOKEN_X) HOLDS CELL CODE, ELSE 0
function CheckSector(CELLCODE, TOKEN_Y, TOKEN_X)
    QX=int(TOKEN_Y) : QY=int(TOKEN_X)
    if QUAD(QX,QY)<>CELLCODE then return 0
    return 1
end function


' REGION_ONLY=1: constellation name only (galaxy map row); 0: add quadrant I..IV
function QuadrantName$(QX, QY, REGION_ONLY)
    select case QX
    case 1
        NAME$="ANTARES" : if QY>4 then NAME$="SIRIUS"
    case 2
        NAME$="RIGEL" : if QY>4 then NAME$="DENEB"
    case 3
        NAME$="PROCYON" : if QY>4 then NAME$="CAPELLA"
    case 4
        NAME$="VEGA" : if QY>4 then NAME$="BETELGEUSE"
    case 5
        NAME$="CANOPUS" : if QY>4 then NAME$="ALDEBARAN"
    case 6
        NAME$="ALTAIR" : if QY>4 then NAME$="REGULUS"
    case 7
        NAME$="SAGITTARIUS" : if QY>4 then NAME$="ARCTURUS"
    case 8
        NAME$="POLLUX" : if QY>4 then NAME$="SPICA"
    end select
   
    return NAME$
end function


' PRINT CAPTION$, READ UP TO MAX_LEN CHARS; RETURN TYPED LINE (LII$ ALSO SET)
function Ask$(CAPTION$, MAX_LEN)
    print CAPTION$;
    input LII$
    return UCASE$(left$(LII$, MAX_LEN))
end function

function AskNumber(CAPTION$, MAX_LEN)
    LII$=Ask$(CAPTION$, MAX_LEN)
    return val(LII$)
end function


' ** PAUSE WITHOUT CR**
function Pause()

  PRINT "\nPRESS A KEY TO CONTINUE"
  Y$=""
  while Y$=""
    get Y$
  wend

  return
end function

' ** KEY TO SRS ICONS **
function ShowKey()
    cls()
    print "\n KEY TO SHORT RANGE SCANNER ICONS:" 
    print "  E  = EARTH FLEET STARSHIP"
    print "  B  = EARTH SPACESTATION"
    print "  *  = PLANET"
    print "  K  = GLONKIN BATTLE CRUISER"
    pause()
    return
end function

' ** LIST OF COMMANDS **
function ShowCommands()
    cls()
    print "\n USE THESE COMMANDS:" 
    print "  NAV  - SET COURSE"
    print "  SRS  - SHORT RANGE SCAN"
    print "  LRS  - LONG RANGE SCAN"
    print "  SLS  - SHORT+LONG SCAN"
    print "  PHA  - FIRE LASERS"
    print "  TOR  - FIRE WARHEADS"
    print "  SHE  - SHIELDS"
    print "  DAM  - DAMAGE REPORT"
    print "  COM  - COMPUTER"
    print "  KEY  - SRS ICONS"
    print "  HLP  - HELP"
    print "  XXX  - QUIT"
    pause()
    return
end function

' ** DIRECTION HELPER **
function ShowDirections()
    print "\nENTER A NUMBER\nBETWEEN 1 AND 9"
    print "  4  3  2\n   . . .\n    ...\n5 ---*--- 1\n    ...\n   . . .\n  6  7  8"
    return
end function

' ** THREE-LETTER COMMAND CODES -> CMD (1..10) FOR DoCommand SELECT CASE **
function InitCommandDict()

    ' Lazy once-per-run: DoCommand calls this; CMD_DICT PLANETts -1 (no slot yet).
    if CMD_DICT>=0 then return

    ' Fill the dictionary with the command codes.
    CMD_DICT=dictnew()
    dictset CMD_DICT, "NAV", 1
    dictset CMD_DICT, "SRS", 2
    dictset CMD_DICT, "LRS", 3
    dictset CMD_DICT, "PHA", 4
    dictset CMD_DICT, "TOR", 5
    dictset CMD_DICT, "SHE", 6
    dictset CMD_DICT, "DAM", 7
    dictset CMD_DICT, "COM", 8
    dictset CMD_DICT, "XXX", 9
    dictset CMD_DICT, "HLP", 10
    return
end function


function DeviceName$(I)
  select case I
  case 1: return "FTL"
  case 2: return "SRS"
  case 3: return "LRS"
  case 4: return "LASERS"
  case 5: return "WARHEADS"
  case 6: return "DAMAGE"
  case 7: return "SHIELDS"
  case 8: return "COMPUTER"
  end select
  return "?"
end function



