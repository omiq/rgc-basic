' ** SUPER PLANET TREK PORTABLE VERSION **

' ** STATE MACHINE STATES **
ST_QUIT=0 : ST_NEWGAME=1 : ST_NEWQUAD=2 : ST_COMMAND=3 : ST_DEAD=4
ST_GAMEOVER=5 : ST_VICTORY=6 : ST_MISSIONEND=7 : ST_PLAYAGAIN=8

' ** QUADRANT CELL CODES **
' The short-range grid is an 8x8 integer array QUAD(), not a 192-char string:
' on RAM-tight 6502 targets RGC_STR_MAX caps strings at 40, which truncated
' the old THIS_QUADRANT$ and corrupted the grid. Integer codes are exact,
' small, and need no string runtime.
C_EMPTY=0 : C_SHIP=1 : C_GLONKIN=2 : C_BASE=3 : C_PLANET=4

' ** COMMAND DICTIONARY **
' -1: not initialized yet (lazy init in DoCommand)
' 0..63: initialized dict slot (allocated by dictnew)
CMD_DICT=-1

' ** INITIALIZE COLOURS USED IN STRING PRINTS **
InitColours()

' COURSE_VEC(9,2) = nav keypad deltas; DEVICE_DAMAGE(8) / DEVICE_NAME$(8) = ship systems
dim G(8,8),COURSE_VEC(9,2),K(3,3),N(3),Z(8,8),DEVICE_DAMAGE(8),DEVICE_NAME$(8),QUAD(8,8)
InitDeviceNames()

' ** DISTANCE CALCULATION **
' Uses the Pythagorean theorem to calculate the distance between two points.
def FND(D)=sqr((K(I,1)-SECTOR_X)^2+(K(I,2)-SECTOR_Y)^2)

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
    case ST_DEAD
      GameState = ShipDestroyed()
    case ST_GAMEOVER
      GameState = ShowGameOver()
    case ST_VICTORY
      GameState = ShowVictory()
    case ST_MISSIONEND
      GameState = ShowMissionEnd()
    case ST_PLAYAGAIN
      GameState = AskPlayAgain()
  end select
loop until GameState = ST_QUIT
end

' ** DISPLAY TITLE SCREEN AND WAIT FOR KEY **
function TitleScreen()

    print "-GENERIC SPACE BATTLE COMPUTER GAME-"
    print "(portable version)"
    pause()
    return

end function

' ** PRINT MISSION ORDERS **
function PrintMissionOrders()
    if SPACESTATION_COUNT<>1 then X$="S" : X0$=" ARE "
    print "MISSION:"
    print "DESTROY THE ";GLONKIN_COUNT;" GLONKIN WARSHIPS"
    print "DATE ";GAME_DATE+MISSION_DAYS;". ";MISSION_DAYS;" DAYS REMAINING."
    print "THERE";X0$;SPACESTATION_COUNT;" SPACESTATION";X$;" AVAILABLE FOR RESUPPLY & REPAIRS"
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
    CRPLANETT=1

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
    QUADRANT_X=FNR(1)
    QUADRANT_Y=FNR(1)
    SECTOR_X=FNR(1)
    SECTOR_Y=FNR(1)

    ' INITIALIZE COURSE_VEC
    for I=1 to 9
      COURSE_VEC(I,1)=0
      COURSE_VEC(I,2)=0
    next I
    COURSE_VEC(3,1)=-1 : COURSE_VEC(2,1)=-1 : COURSE_VEC(4,1)=-1 : COURSE_VEC(4,2)=-1 : COURSE_VEC(5,2)=-1 : COURSE_VEC(6,2)=-1
    COURSE_VEC(1,2)=1 : COURSE_VEC(2,2)=1 : COURSE_VEC(6,1)=1 : COURSE_VEC(7,1)=1 : COURSE_VEC(8,1)=1 : COURSE_VEC(8,2)=1 : COURSE_VEC(9,2)=1
    
    ' INITIALIZE DEVICE_DAMAGE
    for I=1 to 8
      DEVICE_DAMAGE(I)=0
    next I
    
    ' SETUP WHAT EXISTS IN GALAXY . . .
    ' K3= # GLONKINS  B3= # SPACESTATIONS  S3 = # PLANETS
    for I=1 to 8
      print ".";
      for J=1 to 8
        K3=0
        Z(I,J)=0
        RAND_ROLL=RNDINT(100)
        select case RAND_ROLL
        case IS > 98
            K3=3 : GLONKIN_COUNT=GLONKIN_COUNT+3
        case IS > 95
            K3=2 : GLONKIN_COUNT=GLONKIN_COUNT+2
        case IS > 80
            K3=1 : GLONKIN_COUNT=GLONKIN_COUNT+1
        case else
            K3=0
        end select
        B3=0
        if RNDINT(100)>96 then B3=1 : SPACESTATION_COUNT=SPACESTATION_COUNT+1
        G(I,J)=K3*100+B3*10+FNR(1)
      next J
    next I

    if GLONKIN_COUNT>MISSION_DAYS then MISSION_DAYS=GLONKIN_COUNT+1
    print
    ShowKey() : ' ** KEY TO SRS ICONS **
    ShowCommands() : ' ** USE THESE COMMANDS LIST **
    print
    Pause() : ' ** PAUSE **

    ' Guarantee at least one SPACESTATION and preserve original balancing tweak.
    if SPACESTATION_COUNT=0 then
      if G(QUADRANT_X,QUADRANT_Y)<200 then G(QUADRANT_X,QUADRANT_Y)=G(QUADRANT_X,QUADRANT_Y)+120 : GLONKIN_COUNT=GLONKIN_COUNT+1
      SPACESTATION_COUNT=1
      G(QUADRANT_X,QUADRANT_Y)=G(QUADRANT_X,QUADRANT_Y)+10
      QUADRANT_X=FNR(1)
      QUADRANT_Y=FNR(1)
    end if
    K7=GLONKIN_COUNT
    PrintMissionOrders()
    I=RNDINT(1)
    return ST_NEWQUAD
end function




' ** ===== ENTER A QUADRANT: SET IT UP, PLACE OBJECTS, SHORT SCAN ===== **
function EnterQuadrant()
    K3=0 : B3=0 : S3=0
    Z(QUADRANT_X,QUADRANT_Y)=G(QUADRANT_X,QUADRANT_Y)
    if QUADRANT_X >= 1 and QUADRANT_X <=8 and QUADRANT_Y>=1 and QUADRANT_Y<=8 then
      print
      if GAME_DATE=DATE_CUR then
        print "LOCATION:";
        QN$=QuadrantName$(QUADRANT_X, QUADRANT_Y, 0)
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
        QN$=QuadrantName$(QUADRANT_X, QUADRANT_Y, 0)
        SRSFLAG=1
        print "ENTERING ";QN$;" ..."
      end if
    end if
    ' Decode G(quad): K3/B3/S3 = GLONKINs / SPACESTATIONs / PLANETS in this quadrant.
    ' G encodes the 3 digits K*100+B*10+S. Use INTEGER divide/MOD, not float
    ' tricks (int(G*.01)): on fixed-point targets (cc65) G*.01 loses precision
    ' and G/100 overflows 16.16, mis-decoding the counts -> FindEmpty overfills
    ' the quadrant and spins forever. Integer ops are exact and cheap.
    K3=G(QUADRANT_X,QUADRANT_Y)\100
    B3=(G(QUADRANT_X,QUADRANT_Y)\10) MOD 10
    S3=G(QUADRANT_X,QUADRANT_Y) MOD 10
    for I=1 to 3
      K(I,1)=0
      K(I,2)=0
    next I
    for I=1 to 3
      K(I,3)=0
    next I

    ' CLEAR THE QUADRANT CELL GRID
    for I=1 to 8 : for J=1 to 8 : QUAD(I,J)=C_EMPTY : next J : next I

    ' POSITION STARSHIP IN QUADRANT, THEN PLACE "K3" GLONKINS, &
    ' "B3" SPACESTATIONS, & "S3" PLANETS ELSE WHERE.
    PlaceToken(C_SHIP, SECTOR_X, SECTOR_Y)

    ' PLACE GLONKINS
    if K3 >= 1 then
      for I=1 to K3
        FindEmpty()
        PlaceToken(C_GLONKIN, TOKEN_X, TOKEN_Y)
        K(I,1)=TOKEN_X : K(I,2)=TOKEN_Y : K(I,3)=GLONKIN_HP_BASE\2+RNDINT(GLONKIN_HP_BASE)
      next I
    end if

    ' PLACE SPACESTATIONS
    if B3 >= 1 then
      FindEmpty()
      B4=TOKEN_X : B5=TOKEN_Y
      PlaceToken(C_BASE, TOKEN_X, TOKEN_Y)
    end if

    ' PLACE PLANETS
    for I=1 to S3
      FindEmpty()
      PlaceToken(C_PLANET, TOKEN_X, TOKEN_Y)
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
      print : Pause()
      return ST_GAMEOVER
    end if

    ' COMMAND LOOP
    do
      print
      SRSFLAG=0
      A$=Ask$(" COMMAND:  ", 3)
      Z2$=A$ : ATAKFLAG=0
      if A$="SLS" then SLSFLAG=1
      if A$="SLS" then 
        print " SHORT & LONG RANGE SCAN... "
        return ShortRangeScan()
      end if

      if A$="KEY" then ShowKey() : ' KEY TO SRS ICONS
      if A$="KEY" then continue do
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
          return ST_MISSIONEND
      end select
      ShowCommands()
    loop
end function




' ** ===== COURSE CONTROL (NAV) ===== **
function Nav()
    ShowDirections() : ' ** DIRECTION HELPER **
    print
    C1=AskNumber("COURSE (1-9) :  ", 5)
    if C1=9 then C1=1

    ' CHECK IF COURSE IS VALID
    if C1<1 or C1>=9 then
      background 6: color 1
      print "\nINCORRECT COURSE"
      print "DATA";: background 0: print
      return ST_COMMAND
    end if

    ' GET FTL SPEED
    X$="8"
    if DEVICE_DAMAGE(1)<0 then X$="1"
    SRSFLAG=1
    WF$="FTL SPEED (0-"+X$+") :  "
    NAV_FTL_SPEED=AskNumber(WF$, 5)

    ' CHECK IF FTL SPEED IS POSSIBLE
    if DEVICE_DAMAGE(1)<0 and NAV_FTL_SPEED>1 then
      print "\nFTL ENGINES ARE DAMAGED."
      print "MAXIMUM SPEED = FTL 1" : return ST_COMMAND
    end if

    ' CHECK IF FTL SPEED IS ALLOWED
    if NAV_FTL_SPEED>0 and NAV_FTL_SPEED<=8 then
      N=NAV_FTL_SPEED*8
      if SHIP_POWER-N<0 then
        print : background 6: color 1:print "WARNING: INSUFFICIENT POWER";
        print "AVAILABLE FOR FTL ";NAV_FTL_SPEED;"!";: background 0
        if SHIELD_UNITS < N-SHIP_POWER or DEVICE_DAMAGE(7) < 0 then return ST_COMMAND
        print :background 6: color 1: print "SHIELDS CONTROL ROOM ACKNOWLEDGES"
        S1$=str$(SHIELD_UNITS)
        print "SHIELD POWER DEPLOYED IS ";S1$;" UNITS.";: background 0
        return ST_COMMAND
      end if

    else

      if NAV_FTL_SPEED=0 then return ST_COMMAND
      print : background 6: color 1:print "WARNING:"
      print "ENGINES WONT TAKE FTL ";NAV_FTL_SPEED;"!";: background 0  
      return ST_COMMAND
    
    end if

    ' GLONKINS MOVE/FIRE ON MOVING PLANETSHIP . . .
    GLONKINsMove: for I=1 to K3
      if K(I,3)=0 then continue for
      PlaceToken(C_EMPTY, K(I,1), K(I,2)) : FindEmpty()
      K(I,1)=TOKEN_X : K(I,2)=TOKEN_Y : PlaceToken(C_GLONKIN, K(I,1), K(I,2))
    next I
    GLONKINsFire()

    ' CHECK IF SHIP IS DEAD
    if SHIPDEAD then return ST_DEAD

    ' REPAIRS
    D1=0 : D6=0 : if NAV_FTL_SPEED>=1 then D6=1
    for I=1 to 8
      if DEVICE_DAMAGE(I)>=0 then continue for
      DEVICE_DAMAGE(I)=DEVICE_DAMAGE(I)+D6
      if DEVICE_DAMAGE(I)<0 then continue for
      if D1<>1 then D1=1 : print "\nDAMAGE CONTROL REPORT :   "
      print DEVICE_NAME$(I);" REPAIR COMPLETED"
    next I

    ' CHECK IF DEVICE IS DAMAGED
    if RNDINT(100)<=20 then
      J=FNR(1)
      if RNDINT(100)<60 then
        DEVICE_DAMAGE(J)=DEVICE_DAMAGE(J)-RNDINT(5) : print "\nUPDATE::"
        print DEVICE_NAME$(J);" DAMAGED"
      else
        DEVICE_DAMAGE(J)=DEVICE_DAMAGE(J)+RNDINT(3) : print "\nUPDATE::"
        print DEVICE_NAME$(J);" PARTLY REPAIRED"
      end if
    end if

    ' BEGIN MOVING PLANETSHIP
    PlaceToken(C_EMPTY, int(SECTOR_X), int(SECTOR_Y))
    X1=COURSE_VEC(C1,1)+(COURSE_VEC(C1+1,1)-COURSE_VEC(C1,1))*(C1-int(C1)) : X=SECTOR_X : Y=SECTOR_Y
    X2=COURSE_VEC(C1,2)+(COURSE_VEC(C1+1,2)-COURSE_VEC(C1,2))*(C1-int(C1)) : Q4=QUADRANT_X : Q5=QUADRANT_Y
    MoveInterrupted=0 : CrossedQuadrant=0

    ' MOVE PLANETSHIP
    for I=1 to N : SECTOR_X=SECTOR_X+X1 : SECTOR_Y=SECTOR_Y+X2
        if SECTOR_X<1 or SECTOR_X>=9 or SECTOR_Y<1 or SECTOR_Y>=9 then CrossedQuadrant=1 : exit for
        if CheckSector(C_EMPTY, SECTOR_X, SECTOR_Y)=1 then continue for
        SECTOR_X=int(SECTOR_X-X1) : SECTOR_Y=int(SECTOR_Y-X2) : print "\nFTL SHUTDOWN: ";
        print "SECTOR ";SECTOR_X;",";SECTOR_Y
        print "BAD NAVIGATION"
        SRSFLAG=1
        MoveInterrupted=1
        exit for
    next I

    ' CHECK IF SHIP HAS CROSSED QUADRANT
    if CrossedQuadrant=1 then
      X=8*QUADRANT_X+X+N*X1 : Y=8*QUADRANT_Y+Y+N*X2 : QUADRANT_X=int(X/8) : QUADRANT_Y=int(Y/8) : SECTOR_X=int(X-QUADRANT_X*8)
      SECTOR_Y=int(Y-QUADRANT_Y*8) : if SECTOR_X=0 then QUADRANT_X=QUADRANT_X-1 : SECTOR_X=8
      if SECTOR_Y=0 then QUADRANT_Y=QUADRANT_Y-1 : SECTOR_Y=8
      X5=0 : if QUADRANT_X<1 then X5=1 : QUADRANT_X=1 : SECTOR_X=1
      if QUADRANT_X>8 then X5=1 : QUADRANT_X=8 : SECTOR_X=8
      if QUADRANT_Y<1 then X5=1 : QUADRANT_Y=1 : SECTOR_Y=1
      if QUADRANT_Y>8 then X5=1 : QUADRANT_Y=8 : SECTOR_Y=8

      ' CHECK IF SHIP HAS CROSSED QUADRANT
      if X5<>0 then
        print : background 6: color 1: print "NAV ERROR:."
        print "SHUTDOWN: ";SECTOR_X;",";SECTOR_Y;" Q ";QUADRANT_X;",";QUADRANT_Y;:
        background 0: print
        SRSFLAG=1
        print : Pause()
        if DATE_CUR>GAME_DATE+MISSION_DAYS then return ST_GAMEOVER
      end if

      ' CHECK IF SHIP HAS RETURNED TO ORIGINAL QUADRANT
      if 8*QUADRANT_X+QUADRANT_Y=8*Q4+Q5 then
        PlaceToken(C_SHIP, int(SECTOR_X), int(SECTOR_Y)) : ManeuverPOWER() : T8=1
        DATE_CUR=DATE_CUR+T8 : if DATE_CUR>GAME_DATE+MISSION_DAYS then return ST_GAMEOVER
        return ShortRangeScan()
      end if
      DATE_CUR=DATE_CUR+1 : ManeuverPOWER() : return ST_NEWQUAD
    end if

    ' MOVE PLANETSHIP
    if MoveInterrupted=0 then 
      SECTOR_X=int(SECTOR_X)
      SECTOR_Y=int(SECTOR_Y)
    end if

    PlaceToken(C_SHIP, int(SECTOR_X), int(SECTOR_Y))
    ManeuverPOWER()
    T8=1
    DATE_CUR=DATE_CUR+T8
    if DATE_CUR>GAME_DATE+MISSION_DAYS then return ST_GAMEOVER

    ' SEE IF DOCKED, THEN GET COMMAND
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


' ** ===== LONG RANGE SCAN ===== **
function Lrs()
    K1=0
    if DEVICE_DAMAGE(3)<0 then 
      print
      print "LONG RANGE SENSORS DOWN"
      SLSFLAG=0
      return ST_COMMAND
    end if

    ' PRINT LONG RANGE SCAN FOR QUADRANT
    print "\n  LONG RANGE SCAN:  ";QUADRANT_X;",";QUADRANT_Y
    print : O1$=" +-----+-----+-----+" : print O1$;
    O2$=" +-----+-----+-----+"
    O3$=" +-----+-----+-----+"
    print "         ";ECOL$;"#";DCOL$;"#";HCOL$;"#";FCOL$

    ' LONG RANGE SCAN LOOP
    for I=QUADRANT_X-1 to QUADRANT_X+1
      N(1)=-1 : N(2)=-2 : N(3)=-3

      for J=QUADRANT_Y-1 to QUADRANT_Y+1
        if I>0 and I<9 and J>0 and J<9 then N(J-QUADRANT_Y+2)=G(I,J) : Z(I,J)=G(I,J)
      next J
      
      for L=1 to 3
      
        if K1=2 and L=3 then print "";
        print " |";
        print " ";
      
        if N(L)<0 then
          print "▒▒▒";
          continue for
        end if
      
        G1$=right$(str$(N(L)+1000),3)
        print ECOL$;mid$(G1$,1,1);
        print DCOL$;mid$(G1$,2,1);
        print HCOL$;mid$(G1$,3,1);FCOL$;
      
      next L
      print " |"; : K1=K1+1
      if K1=1 then print "        . . ."
      if K1=3 then print "      .   .   ."
      if K1=5 then print "    .           ."
      K1=K1+1
      if K1<6 then print O2$;
      if K1=6 then print O3$;
      if K1=2 then print "       .  .  ."
      if K1=4 then print "     .STATION";
      if K1=4 then print "  ."
      if K1=6 then print " GLONKINS      PLANETS "
    next I

    K1=0 : if SLSFLAG=1 then SLSFLAG=0
    
    return ST_COMMAND
end function


' ** ===== PHASER CONTROL ===== **
function LASERS()
    if DEVICE_DAMAGE(4)<0 then print "\nLASERS DOWN" : return ST_COMMAND
    if K3<=0 then NoEnemyMsg() : return ST_COMMAND
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
    H1=int(X/K3)

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
      K(I,3)=K(I,3)-H : print
      print H;" HIT! ";K(I,1);",";K(I,2)
      if K(I,3)>0 then
        print " (SCAN SHOWS ";int(K(I,3));" UNITS REMAINING)"
        continue for
      end if

      ' DESTROY GLONKIN
      print " *** GLONKIN DESTROYED ***"
      K3=K3-1 : GLONKIN_COUNT=GLONKIN_COUNT-1 : PlaceToken(C_EMPTY, K(I,1), K(I,2))
      K(I,3)=0 : G(QUADRANT_X,QUADRANT_Y)=G(QUADRANT_X,QUADRANT_Y)-100 : Z(QUADRANT_X,QUADRANT_Y)=G(QUADRANT_X,QUADRANT_Y)
      if GLONKIN_COUNT<=0 then return ST_VICTORY
    next I

    ' CHECK IF GLONKINS ARE LEFT
    if K3>0 then print : Pause()

    ' FIRE BACK AT STARSHIP
    GLONKINsFire()

    ' CHECK IF SHIP IS DEAD
    if SHIPDEAD then return ST_DEAD

    ' RETURN SUCCESS
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
        print : background 6: color 1: print "ALERT:, INCORRECT"
        print "COURSE DATA";:background 0: print : return ST_COMMAND
      end if

      ' CALCULATE WARHEAD COURSE
      X1=COURSE_VEC(C1,1)+(COURSE_VEC(C1+1,1)-COURSE_VEC(C1,1))*(C1-int(C1)) : SHIP_POWER=SHIP_POWER-2 : WARHEAD_COUNT=WARHEAD_COUNT-1
      X2=COURSE_VEC(C1,2)+(COURSE_VEC(C1+1,2)-COURSE_VEC(C1,2))*(C1-int(C1)) : X=SECTOR_X : Y=SECTOR_Y
      print "\nWARHEAD TRACKING:"
      RetryCourse=0
      do
        X=X+X1 : Y=Y+X2 : X3=int(X) : Y3=int(Y)
        if X3<1 or X3>8 or Y3<1 or Y3>8 then
          print " ** WARHEAD MISSED **"
          if K3<>0 then print : Pause()
          GLONKINsFire()
          if SHIPDEAD then return ST_DEAD
          return ST_COMMAND
        end if

        ' PRINT WARHEAD TRACKING
        print " ";X3;",";Y3

        ' CHECK IF SECTOR IS EMPTY
        if CheckSector(C_EMPTY, X, Y)=1 then continue do

        ' CHECK IF SECTOR IS GLONKIN
        if CheckSector(C_GLONKIN, X, Y)=1 then

          ' GLONKIN KILLED
          print " *** GLONKIN DESTROYED ***"
          K3=K3-1 : if K3>0 then print : Pause()
          GLONKIN_COUNT=GLONKIN_COUNT-1

          ' CHECK IF ALL GLONKINS ARE DESTROYED
          if GLONKIN_COUNT<=0 then return ST_VICTORY
          
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
          G(QUADRANT_X,QUADRANT_Y)=K3*100+B3*10+S3 : Z(QUADRANT_X,QUADRANT_Y)=G(QUADRANT_X,QUADRANT_Y) : GLONKINsFire()
          
          ' CHECK IF SHIP IS DEAD
          if SHIPDEAD then return ST_DEAD

          ' RETURN SUCCESS
          return ST_COMMAND
        end if

        ' CHECK IF SECTOR IS PLANET
        if CheckSector(C_PLANET, X, Y)=1 then
          print " ** PLANET AT";X3;",";Y3;"ABSORBED WARHEAD **"
          if K3<>0 then print : Pause()
          GLONKINsFire()
          if SHIPDEAD then return ST_DEAD
          return ST_COMMAND
        end if

        ' CHECK IF SECTOR IS SPACESTATION
        if CheckSector(C_BASE, X, Y)=0 then
          RetryCourse=1
          exit do
        end if
        print " *** SPACESTATION DESTROYED ***"
        print : Pause()
        B3=B3-1 : SPACESTATION_COUNT=SPACESTATION_COUNT-1

        ' CHECK IF ALL SPACESTATIONS ARE DESTROYED
        if SPACESTATION_COUNT<=0 and GLONKIN_COUNT<=DATE_CUR-GAME_DATE-MISSION_DAYS then
          print : background 6: color 1: print "FAILURE.";:background 0
          return ST_MISSIONEND
        end if

        ' DESTROY SPACESTATION
        print "\nSPACESTATION LOST: FAILURE." : D0=0
        PlaceToken(C_EMPTY, X, Y)

        ' UPDATE QUADRANT DATA
        G(QUADRANT_X,QUADRANT_Y)=K3*100+B3*10+S3 : Z(QUADRANT_X,QUADRANT_Y)=G(QUADRANT_X,QUADRANT_Y) : GLONKINsFire()
        if SHIPDEAD then return ST_DEAD
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
    if X<0 or SHIELD_UNITS=X then print "<SHIELDS UNCHANGED>" : return ST_COMMAND

    ' CHECK IF SHIELD POWER IS AVAILABLE
    if X>SHIP_POWER+SHIELD_UNITS then
      print :  background 6: color 1: print "SHIELD CONTROL ERROR"
      print "<SHIELDS UNCHANGED>";:background 0: print : return ST_COMMAND
    end if

    ' UPDATE SHIELD POWER
    SHIP_POWER=SHIP_POWER+SHIELD_UNITS-X : SHIELD_UNITS=X : print :background 6: color 1: print "ALERT:"
    print "SHIELDS NOW AT ";int(SHIELD_UNITS);" UNITS PER"
    print "YOUR COMMAND.";:background 0: print : return ST_COMMAND
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
      print "\nALERT:"
      print "ESTIMATED REPAIR ETA: "
      print D3;" DAYS"
      A$=Ask$("\nAUTHORISE (Y/N)? ", 1)
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
      print " ";DEVICE_NAME$(I);left$(SPACE_PAD$,20-len(DEVICE_NAME$(I)));
      D2=DEVICE_DAMAGE(I)
      if D2<0 then print CCOL$;"DAMAGED     ";D2;FCOL$
      if D2>0 then print "OPERATIONAL ";D2
      if D2=0 then print "OPERATIONAL ";D2
    next I
    return ST_COMMAND
end function


' ** ===== GLONKINS SHOOT BACK (SETS SHIPDEAD IF SHIELDS FAIL) ===== **
function GLONKINsFire()
    SHIPDEAD=0
    if K3<=0 then return
    if D0<>0 then print "\nSPACESTATION SHIELDS PROTECT THE STARSHIP"
    if D0<>0 then return

    ' CHECK IF GLONKINS ARE LEFT
    for I=1 to 3
      if K(I,3)<=0 then continue for

      ' CALCULATE HIT POINTS
      H=((K(I,3)/FND(1))*(200+RNDINT(100)))\100 : SHIELD_UNITS=SHIELD_UNITS-H : K(I,3)=K(I,3)\(2+RNDINT(2))
      print : print H;" UNIT HIT STARSHIP FROM ";K(I,1);",";K(I,2)

      ' CHECK IF SHIELDS ARE DOWN
      if SHIELD_UNITS<=0 then SHIPDEAD=1 : return
      print " <SHIELDS DOWN TO ";SHIELD_UNITS;" UNITS>"
      if H<20 then continue for

      ' CHECK IF HIT IS CRITICAL
      if RNDINT(100)>60 or H*50<=SHIELD_UNITS then continue for

      ' DAMAGE CONTROL REPORT
      J=FNR(1) : DEVICE_DAMAGE(J)=DEVICE_DAMAGE(J)-RNDINT(3)
      print : background 6: color 1: print "UPDATE: :  "
      print DEVICE_NAME$(J);" DAMAGED BY THE HIT";:background 0: print
    next I
    ATAKFLAG=1
    return
end function


' ** ===== END-OF-GAME STATES ===== **
function ShowGameOver()
    print "\nIT IS DATE ";DATE_CUR
    return ST_MISSIONEND
end function


' ** ===== SHIP DESTROYED ===== **
function ShipDestroyed()
    print : Pause()
    print "\n THE STARSHIP HAS BEEN DESTROYED. "
    print chr$(13);"THE EARTH WILL BE CONQUERED"
    return ST_GAMEOVER
end function


' ** ===== SHOW MISSION END ===== **
function ShowMissionEnd()
    print "\nTHERE WERE ";GLONKIN_COUNT;" GLONKIN BATTLE CRUISERS"
    print "LEFT AT THE END OF YOUR MISSION."
    return ST_PLAYAGAIN
end function


' ** ===== ASK PLAY AGAIN ===== **
function AskPlayAgain()
    if SPACESTATION_COUNT=0 then return ST_QUIT
    print "\nGAME OVER"
    A$=Ask$("\nPLAY AGAIN (YES/NO) :  ", 3)
    if A$="YES" then return ST_NEWGAME
    return ST_QUIT
end function


' ** ===== SHOW VICTORY ===== **
function ShowVictory()
    print : Pause()
    print "\nCONGRATULATIONS, YOU SAVED THE EARTH!"
    print "\nSCORE:";
    EL=DATE_CUR-GAME_DATE : if EL<1 then EL=1
    print int(1000*(K7/EL)^2)
    return ST_PLAYAGAIN
end function


' ** ===== SHORT RANGE SCAN & SUMMARY (SLS CHAINS INTO LRS) ===== **
function ShortRangeScan()
    if ATAKFLAG=1 then
      print
      Pause()
    end if

    ' CHECK IF SHORT RANGE SENSORS ARE OUT
    if DEVICE_DAMAGE(2)<0 then
      print
      print "*** SHORT RANGE SENSORS DAMAGED ***"
      if SLSFLAG=1 then return Lrs()
      return ST_COMMAND
    end if

    ' PRINT SHORT RANGE SCAN + SUMMARY DATA
    if SRSFLAG=0 then
      print
      print " SHORT RANGE SCAN + SUMMARY "
    end if
    SRSFLAG=0
    ATAKFLAG=0
    Docked=0

    ' CHECK IF SHIP IS DOCKED
    for I=SECTOR_X-1 to SECTOR_X+1
      for J=SECTOR_Y-1 to SECTOR_Y+1
        if I<1 or I>8 or J<1 or J>8 then continue for
        if CheckSector(C_BASE, I, J)=1 then
          Docked=1
          exit for
        end if
      next J
      if Docked=1 then
        exit for
      end if
    next I
    if Docked=1 then
      D0=1
      C$="DOCKED"
      SHIP_POWER=POWER_MAX
      WARHEAD_COUNT=WARHEAD_MAX
      print
      print "SHIELDS DROPPED FOR DOCKING "
      SHIELD_UNITS=0
    else

      ' OTHERWISE ...
      D0=0

      ' CHECK IF COMBAT AREA IS RED
      if K3>0 then C$="RED"

      ' COMBAT AREA IS GREEN
      if K3=0 then
        C$="GREEN"
        if SHIP_POWER<POWER_MAX\10 then C$="AMBER"
      end if
    end if

    ' COMBAT!
    if K3>0 then
      print
      print CCOL$;"COMBAT AREA  ";
      print "** CONDITION RED **";FCOL$
    end if

    LOW$=" LOW!"
    print
    print "    1 2 3 4 5 6 7 8"
    print "   +-+-+-+-+-+-+-+-- DATE  ";DATE_CUR
    
    ' PRINT QUADRANT
    for I=1 to 8
      I$=right$(str$(I),1)
      print " ";I$;" |"; : ' BORDER

      ' PRINT QUADRANT CELLS (integer cell code -> glyph)
      for J = 1 to 8
        CELLCODE=QUAD(I,J)
        if CELLCODE=C_EMPTY then print " ";
        if CELLCODE=C_SHIP then print "E";
        if CELLCODE=C_GLONKIN then print "K";
        if CELLCODE=C_BASE then print "B";
        if CELLCODE=C_PLANET then print "*";
        print "|";
      next J

      ' PRINT SUMMARY DATA
      select case I
      case 1
        print " DAYS LEFT ";GAME_DATE+MISSION_DAYS-DATE_CUR;
      case 2
        print " CONDITION "; : print C$;
      case 3
        print " QUADRANT  ";QUADRANT_X;",";QUADRANT_Y;
      case 4
        print " SECTOR    ";SECTOR_X;",";SECTOR_Y;
      case 5
        print " WARHEADES ";int(WARHEAD_COUNT);
      case 6
        print " POWER    ";int(SHIP_POWER+SHIELD_UNITS);
      case 7
        print " SHIELDS   ";int(SHIELD_UNITS);
        if SHIELD_UNITS<201 and K3>0 then print LOW$;
      case 8
        print " ENEMIES  ";int(GLONKIN_COUNT);
      end select
      print
    next I

    ' PRINT MAX FTL
    print "   +-+-+-+-+-+-+-+-+";
    MW=SHIP_POWER\8
    if MW>8 then MW=8
    if DEVICE_DAMAGE(1)<0 then MW=1
    print " MAX FTL  ";MW
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
    print "\nCOMMANDS AVAILABLE:" : print
    print " 0 - CUMULATIVE LOG"
    print " 1 - STATUS & DAMAGE REPORT"
    print " 2 - WARHEAD TARGETING DATA"
    print " 3 - SPACESTATION NAV DATA"
    print " 4 - DIRECTION/DISTANCE CALCULATOR"
    print " 5 - SYSTEM REGION MAP"
    ' CHECK IF COMPUTER IS ACTIVE
    if COMFLAG=1 then
      print "0"
      A=0
      A1=A
    else
      A=AskNumber(chr$(13)+"ENTER COMMAND :  ", 1)
      A1=A : if A<0 or A>5 then return ST_COMMAND
      if LII$="" then return ST_COMMAND
    end if

    ' EXECUTE COMMAND
    select case A
    case 0
      H8=1 : A=0 : A1=0
      return ComputerGalacticRecord()
    case 1
      return ComputerStatusReport()
    case 2
      return ComputerNavCalcGLONKIN()
    case 3
      return ComputerBaseNav()
    case 4
      return ComputerCalculator()
    case 5
      return ComputerGalaxyMap()
    end select
    return ST_COMMAND
end function


' ** ===== COMPUTER GALACTIC RECORD ===== **
function ComputerGalacticRecord()
    ' GALFLAG marks the highlighted current quadrant separator slot.
    GALFLAG=0


    if A<>5 then
      print
      print "  COMPUTER LOG "
      print "QUADRANT ";QUADRANT_X;",";QUADRANT_Y
      print " \n"
      print "   ";
    end if


    for J=1 to 8
      J$=str$(J)
      J$=right$(J$,1)
      if A1=5 then RomanNumeral() : continue for
      if J=QUADRANT_Y then print "  ";J$;" ";
      if J<>QUADRANT_Y then print "  ";J;" ";
    next J


    print
    O1$="  +---+---+---+---+---+---+---+----"
    O2$="  +---+---+---+---+---+---+---+---+"
    print O1$

    for I=1 to 8
      I$=str$(I)
      I$=right$(I$,1)
      if I=QUADRANT_X then print " ";I$;"";

      RowIsRegion=0
      if A1=5 and I=QUADRANT_X then RowIsRegion=1
      if I<>QUADRANT_X then print " ";I$; : if H8=0 then RowIsRegion=1

      if RowIsRegion=0 then
        for J=1 to 8
          if I=QUADRANT_X and J=QUADRANT_Y then print "|"; : GALFLAG=1
          if not (I=QUADRANT_X and (J=QUADRANT_Y or J-1=QUADRANT_Y)) then print "|";
          if Z(I,J)=0 then print "   "; : continue for
          G1$=right$(str$(Z(I,J)+1000),3)
          print ECOL$;mid$(G1$,1,1);
          print DCOL$;mid$(G1$,2,1);
          print HCOL$;mid$(G1$,3,1);FCOL$;
          if GALFLAG=1 then print "|"; : GALFLAG=0
        next J
      end if

      if RowIsRegion=1 then
        J=9
        QN$=QuadrantName$(I, 1, 1) : J0=11-len(QN$)\2
        print "|";
        print tab(J0);QN$;
        print tab(18);"|";
        QN$=QuadrantName$(I, 5, 1) : J0=27-len(QN$)\2
        print tab(J0);QN$; : print tab(34);"|";
      end if

      if A=0 and J=9 and QUADRANT_X=I and QUADRANT_Y=8 then print
      if not (A=0 and J=9 and QUADRANT_X=I and QUADRANT_Y=8) then if A=0 then print "|"
      if A=5 then print
      if I<8 then print O2$
    next I

    ' PRINT GALACTIC RECORD FOOTER
    print "  +---+---+---+---+---+---+---+---+"
    A1=0
    return ST_COMMAND
end function


' ** ===== COMPUTER GALAXY MAP ===== **
function ComputerGalaxyMap()
    H8=0
    A=5
    A1=5
    print "  THE KNOWN REGION: \n\n   ";
    return ComputerGalacticRecord()
end function

' ** ===== COMPUTER BASE NAV ===== **
function ComputerBaseNav()
    H8=0 : A1=3
    if B3<>0 then
      print "\nFROM STARSHIP TO SPACESTATION"
      return ComputerCalcCompute(SECTOR_Y, SECTOR_X, B4, B5, 10)
    end if
    print "\nWARNING:NO"
    print "SPACESTATIONS IN THIS AREA." : return ST_COMMAND
end function


' ** ===== COMPUTER STATUS REPORT ===== **
function ComputerStatusReport()

    print "  STATUS REPORT: \n"
    
    if GLONKIN_COUNT>1 then 
        X$="S"
    else
        X$=""
    end if

    print "\n GLONKINS LEFT :";GLONKIN_COUNT
    print " POWER        :";int(SHIP_POWER+SHIELD_UNITS)
    print " WARHEADES     :";int(WARHEAD_COUNT)
    print "\n  MISSION MUST BE COMPLETED IN ";GAME_DATE+MISSION_DAYS-DATE_CUR
    print " DAYS"

    ' MULTIPLE SPACESTATIONS
    if SPACESTATION_COUNT<2 then 
        X$=""
    else
        X$="S"
    end if

    ' CHECK IF ANY SPACESTATIONS ARE LEFT
    if SPACESTATION_COUNT<1 then
      print "\n NO SPACESTATIONS"
      print "LEFT!" : return Damage()
    end if

    print "\n  EARTH FLEET IS MAINTAINING ";SPACESTATION_COUNT
    print " SPACESTATION";X$;" IN THE REGION"; chr$(13)
    return Damage()
end function


' ** ===== COMPUTER NAV CALC GLONKIN ===== **
function ComputerNavCalcGLONKIN()
    if K3<=0 then NoEnemyMsg() : return ST_COMMAND
    if K3>1 then 
        X$="S"
    else
        X$=""
    end if
    print "\nFROM STARSHIP TO GLONKIN SHIP";X$
    for I=1 to 3
      if K(I,3)<=0 then continue for
      ComputerCalcCompute(SECTOR_Y, SECTOR_X, K(I,1), K(I,2), 10)
    next I
    return ST_COMMAND
end function


' ** ===== COMPUTER CALCULATOR ===== **
function ComputerCalculator()

    print "\nDIRECTION/DISTANCE CALCULATOR:"
    print "\nYOU ARE AT QUADRANT ";QUADRANT_X;",";QUADRANT_Y
    print "             SECTOR ";SECTOR_X;",";SECTOR_Y

    FROM_Y=AskNumber("\nENTER INITIAL COORDINATES (Y) :  ", 4)
    if FROM_Y=0 then print "\nCALCULATION ABORTED!" : return ST_COMMAND

    FROM_X=AskNumber("\nENTER INITIAL COORDINATES (X) :  ", 4)
    if FROM_X=0 then print "\nCALCULATION ABORTED!" : return ST_COMMAND

    TO_Y=AskNumber("\nENTER FINAL COORDINATES   (Y) :  ", 4)
    if TO_Y=0 then print "\nCALCULATION ABORTED!" : return ST_COMMAND

    TO_X=AskNumber("\nENTER FINAL COORDINATES   (X) :  ", 4)
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
function NoEnemyMsg()
    print : background 6: color 1: print "ALERT:"
    print "SHOW NO ENEMY SHIPS IN THIS REGION";:background 0: print
    return
end function


' FIND EMPTY PLACE IN QUADRANT (FOR THINGS)
function FindEmpty()
    ' ** RETRY UNTIL SQUARE IS EMPTY (THREE SPACES) **
    do
        RANDOM_X=FNR(1) : RANDOM_Y=FNR(1)
    loop until CheckSector(C_EMPTY, RANDOM_X, RANDOM_Y)=1
    TOKEN_X=int(RANDOM_X)
    TOKEN_Y=int(RANDOM_Y)
    return
end function


' SET SECTOR (TOKEN_X, TOKEN_Y) TO CELL CODE in the quadrant grid
function PlaceToken(CELLCODE, TOKEN_X, TOKEN_Y)
    QX=int(TOKEN_X) : QY=int(TOKEN_Y)
    QUAD(QX,QY)=CELLCODE
    return
end function

' RETURN 1 IF SECTOR (TOKEN_X, TOKEN_Y) HOLDS CELL CODE, ELSE 0
function CheckSector(CELLCODE, TOKEN_X, TOKEN_Y)
    QX=int(TOKEN_X) : QY=int(TOKEN_Y)
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
    if REGION_ONLY then return NAME$
    select case QY
    case 1, 5
        return NAME$+" I"
    case 2, 6
        return NAME$+" II"
    case 3, 7
        return NAME$+" III"
    case 4, 8
        return NAME$+" IV"
    end select
    return NAME$
end function


' PRINT CAPTION$, READ UP TO MAX_LEN CHARS; RETURN TYPED LINE (LII$ ALSO SET)
function Ask$(CAPTION$, MAX_LEN)
    LX=MAX_LEN
    print CAPTION$;
    GetInput()
    return LII$
end function

function AskNumber(CAPTION$, MAX_LEN)
    Ask$(CAPTION$, MAX_LEN)
    return val(LII$)
end function


' ** GET INPUT **
' GET CHARACTERS UNTIL RETURN IS PRESSED
function GetInput()
    ' ** LX = MAX INPUT  LII$ = OUTPUT STRING **
    ' ** ACCEPTS A-Z/0-9/PUNCT + SPACE, CHR$(20)=BACKSPACE, ENTER ENDS **
    LII$=""
    do 
        get Y$
        Y$=ucase$(Y$)
        if Y$="" then continue do
        if asc(Y$)=0 then Y$=chr$(13)

        if asc(Y$)=13 and LX=0 then
          print " "
          print FCOL$
          return
        end if
        if asc(Y$)=13 then print : print FCOL$ : return

        if asc(Y$)=20 and len(LII$)<1 then continue do
        if Y$=chr$(20) then Y$="" : LII$=left$(LII$,(len(LII$)-1))

        if asc(Y$)<>32 and (asc(Y$)<46 or asc(Y$)>90) then continue do

        if len(LII$)<LX then print Y$;
        if len(LII$)<LX then LII$=LII$+Y$
    loop
end function

' ** PAUSE WITHOUT CR**
function Pause()
    if CRPLANETT=1 then CR$="PRESS RETURN TO BEGIN"
    if CRPLANETT=0 then CR$="PRESS RETURN TO CONTINUE"
    LX=0 : print "  ":print CR$:print "  "
    GetInput()
    CRPLANETT=0
    return
end function

' ** KEY TO SRS ICONS **
function ShowKey()
    print "\n KEY TO SHORT RANGE SCANNER ICONS:" : print
    print "  E  = EARTH FLEET STARSHIP"
    print "  B  = EARTH SPACESTATION"
    print "  *  = PLANET"
    print "  K  = GLONKIN BATTLE CRUISER"
    return
end function

' ** LIST OF COMMANDS **
function ShowCommands()
    print "\n USE THESE COMMANDS:" : print
    print "  NAV  - TO SET COURSE"
    print "  SRS  - FOR SHORT RANGE SCAN"
    print "  LRS  - FOR LONG RANGE SCAN"
    print "  SLS  - FOR SHORT & LONG RANGE SCAN"
    print "  PHA  - TO FIRE LASERS"
    print "  TOR  - TO FIRE WARHEADS"
    print "  SHE  - TO RAISE OR LOWER SHIELDS"
    print "  DAM  - DAMAGE REPORT"
    print "  COM  - QUERY COMPUTER"
    print "  KEY  - DISPLAY KEY TO SRS ICONS"
    print "  HLP  - THIS LIST OF COMMANDS"
    print "  XXX  - TO RESIGN YOUR COMMAND"
    return
end function

' ** DIRECTION HELPER **
function ShowDirections()
    print ""
    print " ENTER A NUMBER       4  3  2"
    print " BETWEEN 1 AND 9       . . ."
    print "                        ..."
    print "                    5 ---*--- 1"
    print "                        ..."
    print "                       . . ."
    print "                      6  7  8"
    return
end function

' ** GALAXY MAP ROMAN NUMERALS **
function RomanNumeral()
    print "";
    select case J
    case 1, 5
        print " I ";;
    case 2, 6
        print "II ";
    case 3, 7
        print "III";
    case 4, 8
        print "IV ";
    end select
    print " "; : return
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


function InitDeviceNames()
    DEVICE_NAME$(1)="FTL DRIVE"
    DEVICE_NAME$(2)="SHORT RANGE SENSORS"
    DEVICE_NAME$(3)="LONG RANGE SENSORS"
    DEVICE_NAME$(4)="LASER TARGETING"
    DEVICE_NAME$(5)="WARHEADS"
    DEVICE_NAME$(6)="DAMAGE CONTROL"
    DEVICE_NAME$(7)="SHIELDS"
    DEVICE_NAME$(8)="SHIP COMPUTER"
    return
end function


' ** COLOURS FOR IN-GAME **
function InitColours()
    ACOL$="" 
    BCOL$="" 
    CCOL$="" 
    DCOL$="" 
    ECOL$="" 
    FCOL$="" 
    GCOL$="" 
    HCOL$="" 
    ICOL$=""
    return
end function


