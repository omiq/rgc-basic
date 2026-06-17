' ** SUPER STAR TREK PORTABLE VERSION **

' ** STATE MACHINE STATES **
ST_QUIT=0 : ST_NEWGAME=1 : ST_NEWQUAD=2 : ST_COMMAND=3 : ST_DEAD=4
ST_GAMEOVER=5 : ST_VICTORY=6 : ST_MISSIONEND=7 : ST_PLAYAGAIN=8

' ** TOKEN STRINGS **
' Enterprise, Klingon, Starbase, Star, Empty
ENTERPRISE_TOKEN$="E  " : KLINGON_TOKEN$="K  " : STARBASE_TOKEN$="B  " : STAR_TOKEN$="*  " : EMPTY_TOKEN$="   "

' ** COMMAND DICTIONARY **
' -1: not initialized yet (lazy init in DoCommand)
' 0..63: initialized dict slot (allocated by dictnew)
CMD_DICT=-1

' ** INITIALIZE COLOURS USED IN STRING PRINTS **
InitColours()

' COURSE_VEC(9,2) = nav keypad deltas; DEVICE_DAMAGE(8) / DEVICE_NAME$(8) = ship systems
dim G(8,8),COURSE_VEC(9,2),K(3,3),N(3),Z(8,8),DEVICE_DAMAGE(8),DEVICE_NAME$(8)
InitDeviceNames()

' ** DISTANCE CALCULATION **
' Uses the Pythagorean theorem to calculate the distance between two points.
def FND(D)=sqr((K(I,1)-SECTOR_X)^2+(K(I,2)-SECTOR_Y)^2)

' ** RANDOM NUMBER GENERATOR **
' Generates a random number between 1 and 8.
' R is the random number generator seed.
def FNR(R)=int(rnd(R)*7.98+1.01)


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

    print "--S-U-P-E-R---S-T-A-R---T-R-E-K--"
    print "(portable version)"
    pause()
    return

end function

' ** PRINT MISSION ORDERS **
function PrintMissionOrders()
    if STARBASE_COUNT<>1 then X$="S" : X0$=" ARE "
    print
    print "  YOUR ORDERS ARE AS FOLLOWS: "
    print
    print "DESTROY THE ";KLINGON_COUNT;" KLINGON WARSHIPS BEFORE"
    print "STARDATE ";STARDATE_START+MISSION_DAYS;". THIS GIVES YOU ";MISSION_DAYS;" DAYS."
    print "THERE";X0$;STARBASE_COUNT;" STARBASE";X$;" IN THE GALAXY"
    print "FOR RESUPPLYING & REPAIRING YOUR SHIP."
    return
end function

' ** ===== ONE-TIME GAME SETUP (NEW GAME / RESTART) ===== **
function SetupGame()
    Z2$=""
    ATAKFLAG=0
    SLSFLAG=0
    N=rnd(-1)

    ' ** DISPLAY TITLE SCREEN AND WAIT FOR KEY **
    TitleScreen()
    CRSTART=1

    ' ** RANDOM SEED GENERATOR **
    RANDOM_SEED=rnd(-TI)  
    print "\n          GENERATING GALAXY";
    SPACE_PAD$="                         "
    STARDATE_CUR=int(rnd(1)*20+20)*100
    STARDATE_START=STARDATE_CUR
    MISSION_DAYS=25+int(rnd(1)*10)
    D0=0
    SHIP_ENERGY=3000
    ENERGY_MAX=SHIP_ENERGY
    TORPEDO_COUNT=10
    TORPEDO_MAX=TORPEDO_COUNT
    KLINGON_HP_BASE=200
    SHIELD_UNITS=0
    STARBASE_COUNT=2
    KLINGON_COUNT=0
    X$=""
    X0$=" IS "
    
    ' INITIALIZE ENTERPRISES POSITION
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
    ' K3= # KLINGONS  B3= # STARBASES  S3 = # STARS
    for I=1 to 8
      print ".";
      for J=1 to 8
        K3=0
        Z(I,J)=0
        RAND_ROLL=rnd(1)
        select case RAND_ROLL
        case IS > .98
            K3=3 : KLINGON_COUNT=KLINGON_COUNT+3
        case IS > .95
            K3=2 : KLINGON_COUNT=KLINGON_COUNT+2
        case IS > .80
            K3=1 : KLINGON_COUNT=KLINGON_COUNT+1
        case else
            K3=0
        end select
        B3=0
        if rnd(1)>.96 then B3=1 : STARBASE_COUNT=STARBASE_COUNT+1
        G(I,J)=K3*100+B3*10+FNR(1)
      next J
    next I

    if KLINGON_COUNT>MISSION_DAYS then MISSION_DAYS=KLINGON_COUNT+1
    print
    ShowKey() : ' ** KEY TO SRS ICONS **
    ShowCommands() : ' ** USE THESE COMMANDS LIST **
    print
    Pause() : ' ** PAUSE **

    ' Guarantee at least one starbase and preserve original balancing tweak.
    if STARBASE_COUNT=0 then
      if G(QUADRANT_X,QUADRANT_Y)<200 then G(QUADRANT_X,QUADRANT_Y)=G(QUADRANT_X,QUADRANT_Y)+120 : KLINGON_COUNT=KLINGON_COUNT+1
      STARBASE_COUNT=1
      G(QUADRANT_X,QUADRANT_Y)=G(QUADRANT_X,QUADRANT_Y)+10
      QUADRANT_X=FNR(1)
      QUADRANT_Y=FNR(1)
    end if
    K7=KLINGON_COUNT
    PrintMissionOrders()
    I=rnd(1)
    return ST_NEWQUAD
end function




' ** ===== ENTER A QUADRANT: SET IT UP, PLACE OBJECTS, SHORT SCAN ===== **
function EnterQuadrant()
    K3=0 : B3=0 : S3=0
    D4=.5*rnd(1)
    Z(QUADRANT_X,QUADRANT_Y)=G(QUADRANT_X,QUADRANT_Y)
    if QUADRANT_X >= 1 and QUADRANT_X <=8 and QUADRANT_Y>=1 and QUADRANT_Y<=8 then
      print
      if STARDATE_START=STARDATE_CUR then
        print "YOUR MISSION BEGINS WITH YOUR STARSHIP"
        QN$=QuadrantName$(QUADRANT_X, QUADRANT_Y, 0)
        print "IN THE QUADRANT, ";QN$;"."
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
        print "ENTERING ";QN$;" QUADRANT..."
      end if
    end if
    ' Decode G(quad): K3/B3/S3 = klingons / starbases / stars in this quadrant.
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

    ' INITIALIZE THIS_QUADRANT$ WITH 192 SPACES
    THIS_QUADRANT$=STRING$(192, " ")
    
    ' POSITION ENTERPRISE IN QUADRANT, THEN PLACE "K3" KLINGONS, &
    ' "B3" STARBASES, & "S3" STARS ELSE WHERE.
    PlaceToken(ENTERPRISE_TOKEN$, SECTOR_X, SECTOR_Y)

    ' PLACE KLINGONS
    if K3 >= 1 then
      for I=1 to K3
        FindEmpty()
        PlaceToken(KLINGON_TOKEN$, TOKEN_X, TOKEN_Y)
        K(I,1)=TOKEN_X : K(I,2)=TOKEN_Y : K(I,3)=KLINGON_HP_BASE*(0.5+rnd(1))
      next I
    end if

    ' PLACE STARBASES
    if B3 >= 1 then
      FindEmpty()
      B4=TOKEN_X : B5=TOKEN_Y
      PlaceToken(STARBASE_TOKEN$, TOKEN_X, TOKEN_Y)
    end if

    ' PLACE STARS
    for I=1 to S3
      FindEmpty()
      PlaceToken(STAR_TOKEN$, TOKEN_X, TOKEN_Y)
    next I

    ' DO SHORT RANGE SCAN
    return ShortRangeScan()
end function




' ** ===== COMMAND PHASE: ENERGY CHECK, PROMPT, DISPATCH ONE COMMAND ===== **
function DoCommand()

    ' INITIALIZE COMMAND DICTIONARY
    if CMD_DICT<0 then InitCommandDict()

    ' CHECK IF SHIP HAS ENOUGH ENERGY
    if SHIELD_UNITS+SHIP_ENERGY <= 10 or (SHIP_ENERGY<=10 and DEVICE_DAMAGE(7)<>0) then
      print "\n** FATAL ERROR **"
      print "YOUVE STRANDED YOUR SHIP IN SPACE."
      print "YOU HAVE INSUFFICIENT MANOEUVRING"
      print "ENERGY, & SHIELD CONTROL IS PRESENTLY"
      print "INCAPABLE OF CROSS-CIRCUITING TO"
      print "ENGINE ROOM!!"
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
          return Phasers()
      case 5
          return Torpedo()
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
      print "\nLT. SULU REPORTS, INCORRECT COURSE"
      print "DATA, SIR!";: background 0: print
      return ST_COMMAND
    end if

    ' GET WARP FACTOR
    X$="8"
    if DEVICE_DAMAGE(1)<0 then X$="0.2"
    SRSFLAG=1
    WF$="WARP FACTOR (0-"+X$+") :  "
    NAV_WARP_FACTOR=AskNumber(WF$, 5)

    ' CHECK IF WARP FACTOR IS POSSIBLE
    if DEVICE_DAMAGE(1)<0 and NAV_WARP_FACTOR>.2 then
      print "\nWARP ENGINES ARE DAMAGED."
      print "MAXIMUM SPEED = WARP 0.2" : return ST_COMMAND
    end if

    ' CHECK IF WARP FACTOR IS ALLOWED
    if NAV_WARP_FACTOR>0 and NAV_WARP_FACTOR<=8 then
      N=int(NAV_WARP_FACTOR*8+.5)
      if SHIP_ENERGY-N<0 then
        print : background 6: color 1:print "ENGINEERING REPORTS INSUFFICIENT ENERGY";
        print "AVAILABLE FOR WARP ";NAV_WARP_FACTOR;"!";: background 0
        if SHIELD_UNITS < N-SHIP_ENERGY or DEVICE_DAMAGE(7) < 0 then return ST_COMMAND
        print :background 6: color 1: print "DEFLECTOR CONTROL ROOM ACKNOWLEDGES"
        S1$=str$(SHIELD_UNITS)
        print "SHIELD ENERGY DEPLOYED IS ";S1$;" UNITS.";: background 0
        return ST_COMMAND
      end if

    else

      if NAV_WARP_FACTOR=0 then return ST_COMMAND
      print : background 6: color 1:print "CHIEF ENGINEER SCOTT REPORTS THE"
      print "ENGINES WONT TAKE WARP ";NAV_WARP_FACTOR;"!";: background 0  
      return ST_COMMAND
    
    end if

    ' KLINGONS MOVE/FIRE ON MOVING STARSHIP . . .
    KlingonsMove: for I=1 to K3
      if K(I,3)=0 then continue for
      PlaceToken(EMPTY_TOKEN$, K(I,1), K(I,2)) : FindEmpty()
      K(I,1)=TOKEN_X : K(I,2)=TOKEN_Y : PlaceToken(KLINGON_TOKEN$, K(I,1), K(I,2))
    next I
    KlingonsFire()

    ' CHECK IF SHIP IS DEAD
    if SHIPDEAD then return ST_DEAD

    ' REPAIRS
    D1=0 : D6=NAV_WARP_FACTOR : if NAV_WARP_FACTOR>=1 then D6=1
    for I=1 to 8
      if DEVICE_DAMAGE(I)>=0 then continue for
      DEVICE_DAMAGE(I)=DEVICE_DAMAGE(I)+D6
      if DEVICE_DAMAGE(I)>-.1and DEVICE_DAMAGE(I)<0then DEVICE_DAMAGE(I)=-.1 : continue for
      if DEVICE_DAMAGE(I)<0 then continue for
      if D1<>1 then D1=1 : print "\nDAMAGE CONTROL REPORT :   "
      print DEVICE_NAME$(I);" REPAIR COMPLETED"
    next I

    ' CHECK IF DEVICE IS DAMAGED
    if rnd(1)<=.2 then
      J=FNR(1)
      if rnd(1)<.6 then
        DEVICE_DAMAGE(J)=DEVICE_DAMAGE(J)-(rnd(1)*5+1) : print "\nDAMAGE CONTROL REPORTS:"
        print DEVICE_NAME$(J);" DAMAGED"
      else
        DEVICE_DAMAGE(J)=DEVICE_DAMAGE(J)+rnd(1)*3+1 : print "\nDAMAGE CONTROL REPORTS:"
        print DEVICE_NAME$(J);" PARTLY REPAIRED"
      end if
    end if

    ' BEGIN MOVING STARSHIP
    PlaceToken(EMPTY_TOKEN$, int(SECTOR_X), int(SECTOR_Y))
    X1=COURSE_VEC(C1,1)+(COURSE_VEC(C1+1,1)-COURSE_VEC(C1,1))*(C1-int(C1)) : X=SECTOR_X : Y=SECTOR_Y
    X2=COURSE_VEC(C1,2)+(COURSE_VEC(C1+1,2)-COURSE_VEC(C1,2))*(C1-int(C1)) : Q4=QUADRANT_X : Q5=QUADRANT_Y
    MoveInterrupted=0 : CrossedQuadrant=0

    ' MOVE STARSHIP
    for I=1 to N : SECTOR_X=SECTOR_X+X1 : SECTOR_Y=SECTOR_Y+X2
        if SECTOR_X<1 or SECTOR_X>=9 or SECTOR_Y<1 or SECTOR_Y>=9 then CrossedQuadrant=1 : exit for
        if CheckSector(EMPTY_TOKEN$, SECTOR_X, SECTOR_Y)=1 then continue for
        SECTOR_X=int(SECTOR_X-X1) : SECTOR_Y=int(SECTOR_Y-X2) : print "\nWARP ENGINES SHUT DOWN AT ";
        print "SECTOR ";SECTOR_X;",";SECTOR_Y
        print "DUE TO BAD NAVIGATION"
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
        print : background 6: color 1: print "LT. UHURA REPORTS MESSAGE FROM STARFLEET";
        print " COMMAND:PERMISSION TO ATTEMPT CROSSING OF GALACTIC PERIMETER IS HEREBY *DENIED* ";
        print " - SHUT DOWN YOUR ENGINES.   CHIEF ENGINEER SCOTT REPORTS WARP";
        print " ENGINES SHUT DOWN AT SECTOR ";SECTOR_X;",";SECTOR_Y;" OF QUADRANT ";QUADRANT_X;",";QUADRANT_Y;".";:
        background 0: print
        SRSFLAG=1
        print : Pause()
        if STARDATE_CUR>STARDATE_START+MISSION_DAYS then return ST_GAMEOVER
      end if

      ' CHECK IF SHIP HAS RETURNED TO ORIGINAL QUADRANT
      if 8*QUADRANT_X+QUADRANT_Y=8*Q4+Q5 then
        PlaceToken(ENTERPRISE_TOKEN$, int(SECTOR_X), int(SECTOR_Y)) : ManeuverEnergy() : T8=1
        if NAV_WARP_FACTOR<1 then T8=.1*int(10*NAV_WARP_FACTOR)
        STARDATE_CUR=STARDATE_CUR+T8 : if STARDATE_CUR>STARDATE_START+MISSION_DAYS then return ST_GAMEOVER
        return ShortRangeScan()
      end if
      STARDATE_CUR=STARDATE_CUR+1 : ManeuverEnergy() : return ST_NEWQUAD
    end if

    ' MOVE STARSHIP
    if MoveInterrupted=0 then 
      SECTOR_X=int(SECTOR_X)
      SECTOR_Y=int(SECTOR_Y)
    end if

    PlaceToken(ENTERPRISE_TOKEN$, int(SECTOR_X), int(SECTOR_Y))
    ManeuverEnergy()
    T8=1
    if NAV_WARP_FACTOR<1 then T8=.1*int(10*NAV_WARP_FACTOR)
    STARDATE_CUR=STARDATE_CUR+T8
    if STARDATE_CUR>STARDATE_START+MISSION_DAYS then return ST_GAMEOVER

    ' SEE IF DOCKED, THEN GET COMMAND
    return ShortRangeScan()
end function

' MANEUVER ENERGY S/R **
function ManeuverEnergy()
    SHIP_ENERGY=SHIP_ENERGY-N-10
    if SHIP_ENERGY>=0 then return
    print "\nSHIELD CONTROL SUPPLIES ENERGY TO"
    print "COMPLETE THE MANOEUVRE."
    SHIELD_UNITS=SHIELD_UNITS+SHIP_ENERGY
    SHIP_ENERGY=0
    if SHIELD_UNITS<=0 then SHIELD_UNITS=0
    return
end function


' ** ===== LONG RANGE SCAN ===== **
function Lrs()
    K1=0
    if DEVICE_DAMAGE(3)<0 then 
      print
      print "LONG RANGE SENSORS ARE INOPERABLE"
      SLSFLAG=0
      return ST_COMMAND
    end if

    ' PRINT LONG RANGE SCAN FOR QUADRANT
    print "\n  LONG RANGE SCAN FOR QUADRANT  ";QUADRANT_X;",";QUADRANT_Y
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
        CH$=ECOL$+mid$(G1$,1,1) : print CH$;
        CH$=DCOL$+mid$(G1$,2,1) : print CH$;
        CH$=HCOL$+mid$(G1$,3,1) : print CH$;FCOL$;
      
      next L
      print " |"; : K1=K1+1
      if K1=1 then print "        . . ."
      if K1=3 then print "      .   .   ."
      if K1=5 then print "    .           ."
      K1=K1+1
      if K1<6 then print O2$;
      if K1=6 then print O3$;
      if K1=2 then print "       .  .  ."
      if K1=4 then print "     .  BASES";
      if K1=4 then print "  ."
      if K1=6 then print " KLINGONS      STARS "
    next I

    K1=0 : if SLSFLAG=1 then SLSFLAG=0
    
    return ST_COMMAND
end function


' ** ===== PHASER CONTROL ===== **
function Phasers()
    if DEVICE_DAMAGE(4)<0 then print "\nPHASERS INOPERATIVE" : return ST_COMMAND
    if K3<=0 then NoEnemyMsg() : return ST_COMMAND
    if DEVICE_DAMAGE(8)<0 then print "\nCOMPUTER FAILURE HAMPERS ACCURACY"
    print "\nPHASERS LOCKED ON TARGET!  "
    
    do
        print "\nENERGY AVAILABLE = ";SHIP_ENERGY;" UNITS"
        X=AskNumber("\nNUMBER OF UNITS TO FIRE :  ", 5)
        if X<=0 then return ST_COMMAND
    loop until SHIP_ENERGY-X>=0

    SHIP_ENERGY=SHIP_ENERGY-X
    if DEVICE_DAMAGE(7)<0 then X=X*rnd(1)

    ' CALCULATE HIT POINTS
    H1=int(X/K3)

    ' FIRE PHASERS
    for I=1 to 3
      if K(I,3)<=0 then continue for
      H=int((H1/FND(0))*(rnd(1)+2))
      if H<=.15*K(I,3) then
        print "\n SENSORS SHOW NO DAMAGE TO ENEMY"
        print " AT ";K(I,1);",";K(I,2)
        continue for
      end if

      ' HIT KLINGON
      K(I,3)=K(I,3)-H : print
      print H;" UNIT HIT KLINGON AT ";K(I,1);",";K(I,2)
      if K(I,3)>0 then
        print " (SENSORS SHOW ";int(K(I,3));" UNITS REMAINING)"
        continue for
      end if

      ' DESTROY KLINGON
      print " *** KLINGON DESTROYED ***"
      K3=K3-1 : KLINGON_COUNT=KLINGON_COUNT-1 : PlaceToken(EMPTY_TOKEN$, K(I,1), K(I,2))
      K(I,3)=0 : G(QUADRANT_X,QUADRANT_Y)=G(QUADRANT_X,QUADRANT_Y)-100 : Z(QUADRANT_X,QUADRANT_Y)=G(QUADRANT_X,QUADRANT_Y)
      if KLINGON_COUNT<=0 then return ST_VICTORY
    next I

    ' CHECK IF KLINGONS ARE LEFT
    if K3>0 then print : Pause()

    ' FIRE BACK AT ENTERPRISE
    KlingonsFire()

    ' CHECK IF SHIP IS DEAD
    if SHIPDEAD then return ST_DEAD

    ' RETURN SUCCESS
    return ST_COMMAND
end function


' ** ===== PHOTON TORPEDO ===== **
function Torpedo()
    if TORPEDO_COUNT<=0 then print "\nALL PHOTON TORPEDOES EXPENDED" : return ST_COMMAND
    if DEVICE_DAMAGE(5)<0 then print "\nPHOTON TUBES ARE NOT OPERATIONAL" : return ST_COMMAND
    do
      ShowDirections() : ' ** DIRECTION HELPER **
      print
      C1=AskNumber("PHOTON TORPEDO COURSE (1-9) :  ", 5)
      if C1=9 then C1=1
      if C1<1 or C1>=9 then
        print : background 6: color 1: print "ENSIGN CHEKOV REPORTS, INCORRECT"
        print "COURSE DATA, SIR!";:background 0: print : return ST_COMMAND
      end if

      ' CALCULATE TORPEDO COURSE
      X1=COURSE_VEC(C1,1)+(COURSE_VEC(C1+1,1)-COURSE_VEC(C1,1))*(C1-int(C1)) : SHIP_ENERGY=SHIP_ENERGY-2 : TORPEDO_COUNT=TORPEDO_COUNT-1
      X2=COURSE_VEC(C1,2)+(COURSE_VEC(C1+1,2)-COURSE_VEC(C1,2))*(C1-int(C1)) : X=SECTOR_X : Y=SECTOR_Y
      print "\nTORPEDO TRACKING:"
      RetryCourse=0
      do
        X=X+X1 : Y=Y+X2 : X3=int(X+.5) : Y3=int(Y+.5)
        if X3<1 or X3>8 or Y3<1 or Y3>8 then
          print " ** TORPEDO MISSED **"
          if K3<>0 then print : Pause()
          KlingonsFire()
          if SHIPDEAD then return ST_DEAD
          return ST_COMMAND
        end if

        ' PRINT TORPEDO TRACKING
        print " ";X3;",";Y3

        ' CHECK IF SECTOR IS EMPTY
        if CheckSector(EMPTY_TOKEN$, X, Y)=1 then continue do

        ' CHECK IF SECTOR IS KLINGON
        if CheckSector(KLINGON_TOKEN$, X, Y)=1 then

          ' KLINGON KILLED
          print " *** KLINGON DESTROYED ***"
          K3=K3-1 : if K3>0 then print : Pause()
          KLINGON_COUNT=KLINGON_COUNT-1

          ' CHECK IF ALL KLINGONS ARE DESTROYED
          if KLINGON_COUNT<=0 then return ST_VICTORY
          
          ' FIND KLINGON INDEX
          HitIdx=3
          for I=1 to 3
            if X3=K(I,1) and Y3=K(I,2) then 
                HitIdx=I
                exit for
            end if
          next I

          ' DESTROY KLINGON
          K(HitIdx,3)=0
          PlaceToken(EMPTY_TOKEN$, X, Y)

          ' UPDATE QUADRANT DATA
          G(QUADRANT_X,QUADRANT_Y)=K3*100+B3*10+S3 : Z(QUADRANT_X,QUADRANT_Y)=G(QUADRANT_X,QUADRANT_Y) : KlingonsFire()
          
          ' CHECK IF SHIP IS DEAD
          if SHIPDEAD then return ST_DEAD

          ' RETURN SUCCESS
          return ST_COMMAND
        end if

        ' CHECK IF SECTOR IS STAR
        if CheckSector(STAR_TOKEN$, X, Y)=1 then
          print " ** STAR AT";X3;",";Y3;"ABSORBED TORPEDO **"
          if K3<>0 then print : Pause()
          KlingonsFire()
          if SHIPDEAD then return ST_DEAD
          return ST_COMMAND
        end if

        ' CHECK IF SECTOR IS STARBASE
        if CheckSector(STARBASE_TOKEN$, X, Y)=0 then
          RetryCourse=1
          exit do
        end if
        print " *** STARBASE DESTROYED ***"
        print : Pause()
        B3=B3-1 : STARBASE_COUNT=STARBASE_COUNT-1

        ' CHECK IF ALL STARBASES ARE DESTROYED
        if STARBASE_COUNT<=0 and KLINGON_COUNT<=STARDATE_CUR-STARDATE_START-MISSION_DAYS then
          print : background 6: color 1: print "THAT DOES IT, CAPTAIN!!  YOU ARE HEREBY"
          print "RELIEVED OF COMMAND AND SENTENCED TO 99"
          print "STARDATES AT HARD LABOUR ON CYGNUS 12!!";:background 0
          return ST_MISSIONEND
        end if

        ' DESTROY STARBASE
        print "\nSTARFLEET COMMAND REVIEWING YOUR RECORD"
        print "TO CONSIDER COURT MARTIAL!" : D0=0
        PlaceToken(EMPTY_TOKEN$, X, Y)

        ' UPDATE QUADRANT DATA
        G(QUADRANT_X,QUADRANT_Y)=K3*100+B3*10+S3 : Z(QUADRANT_X,QUADRANT_Y)=G(QUADRANT_X,QUADRANT_Y) : KlingonsFire()
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
    if DEVICE_DAMAGE(7)<0 then print "\nSHIELD CONTROL INOPERABLE" : return ST_COMMAND
    print "\nENERGY AVAILABLE = ";SHIP_ENERGY+SHIELD_UNITS
    X=AskNumber("\nNUMBER OF UNITS TO SHIELDS :  ", 5)
    if X<0 or SHIELD_UNITS=X then print "<SHIELDS UNCHANGED>" : return ST_COMMAND

    ' CHECK IF SHIELD ENERGY IS AVAILABLE
    if X>SHIP_ENERGY+SHIELD_UNITS then
      print :  background 6: color 1: print "SHIELD CONTROL REPORTS THIS IS NOT THE"
      print "FEDERATION TREASURY."
      print "<SHIELDS UNCHANGED>";:background 0: print : return ST_COMMAND
    end if

    ' UPDATE SHIELD ENERGY
    SHIP_ENERGY=SHIP_ENERGY+SHIELD_UNITS-X : SHIELD_UNITS=X : print :background 6: color 1: print "DEFLECTOR CONTROL ROOM REPORT:"
    print "SHIELDS NOW AT ";int(SHIELD_UNITS);" UNITS PER"
    print "YOUR COMMAND.";:background 0: print : return ST_COMMAND
end function


' ** ===== DAMAGE CONTROL ===== **
function Damage()
    if DEVICE_DAMAGE(6)<0 then
      print "\nDAMAGE CONTROL REPORT NOT AVAILABLE"
      if D0=0 then return ST_COMMAND
    end if
    do
      ' CHECK IF DAMAGE CONTROL IS AVAILABLE
      if DEVICE_DAMAGE(6)<0 and D0<>0 then
        ' CALCULATE TIME TO REPAIR
        D3=0 : for I=1 to 8 : if DEVICE_DAMAGE(I)<0 then D3=D3+.1
        next I : if D3=0 then return ST_COMMAND
        D3=D3+D4
        ' CHECK IF TIME TO REPAIR IS MAXIMUM
        if D3>=1 then D3=.9
        ' PRINT REPAIR REPORT
        print "\nTECHNICIANS STANDING BY TO EFFECT"
        print "REPAIRS TO YOUR SHIP;"
        print "ESTIMATED TIME TO REPAIR: "
        print .01*int(100*D3);" STARDATES"
        A$=Ask$("\nAUTHORISE THE REPAIR ORDER (Y/N)? ", 1)
        if A$<>"Y" then return ST_COMMAND

        ' REPAIR DEVICES
        for I=1 to 8
          if DEVICE_DAMAGE(I)<0 then DEVICE_DAMAGE(I)=0
        next I
        ' UPDATE STARDATE
        STARDATE_CUR=STARDATE_CUR+D3+.1
      end if

      ' PRINT REPAIR REPORT
      print "\n SYSTEM              STATE OF REPAIR"
      print      " ------------------- -----------------"
      for I=1 to 8
        print " ";DEVICE_NAME$(I);left$(SPACE_PAD$,20-len(DEVICE_NAME$(I)));
        D2=int(DEVICE_DAMAGE(I)*100)*.01
        if D2<0 then print CCOL$;"DAMAGED     ";D2;FCOL$
        if D2>0 then print "OPERATIONAL ";D2
        if D2=0 then print "OPERATIONAL ";D2
      next I
      if D0=0 then exit do
    loop
    return ST_COMMAND
end function


' ** ===== KLINGONS SHOOT BACK (SETS SHIPDEAD IF SHIELDS FAIL) ===== **
function KlingonsFire()
    SHIPDEAD=0
    if K3<=0 then return
    if D0<>0 then print "\nSTARBASE SHIELDS PROTECT THE ENTERPRISE"
    if D0<>0 then return

    ' CHECK IF KLINGONS ARE LEFT
    for I=1 to 3
      if K(I,3)<=0 then continue for

      ' CALCULATE HIT POINTS
      H=int((K(I,3)/FND(1))*(2+rnd(1))) : SHIELD_UNITS=SHIELD_UNITS-H : K(I,3)=K(I,3)/(3+rnd(0))
      print : print H;" UNIT HIT ENTERPRISE FROM ";K(I,1);",";K(I,2)

      ' CHECK IF SHIELDS ARE DOWN
      if SHIELD_UNITS<=0 then SHIPDEAD=1 : return
      print " <SHIELDS DOWN TO ";SHIELD_UNITS;" UNITS>"
      if H<20 then continue for

      ' CHECK IF HIT IS CRITICAL
      if rnd(1)>.6 or H/SHIELD_UNITS<=.02 then continue for

      ' DAMAGE CONTROL REPORT
      J=FNR(1) : DEVICE_DAMAGE(J)=DEVICE_DAMAGE(J)-H/SHIELD_UNITS-.5*rnd(1)
      print : background 6: color 1: print "DAMAGE CONTROL REPORTS :  "
      print DEVICE_NAME$(J);" DAMAGED BY THE HIT";:background 0: print
    next I
    ATAKFLAG=1
    return
end function


' ** ===== END-OF-GAME STATES ===== **
function ShowGameOver()
    print "\nIT IS STARDATE ";STARDATE_CUR
    return ST_MISSIONEND
end function


' ** ===== SHIP DESTROYED ===== **
function ShipDestroyed()
    print : Pause()
    print "\n THE ENTERPRISE HAS BEEN DESTROYED. "
    print chr$(13);"THE FEDERATION WILL BE CONQUERED"
    return ST_GAMEOVER
end function


' ** ===== SHOW MISSION END ===== **
function ShowMissionEnd()
    print "\nTHERE WERE ";KLINGON_COUNT;" KLINGON BATTLE CRUISERS"
    print "LEFT AT THE END OF YOUR MISSION."
    return ST_PLAYAGAIN
end function


' ** ===== ASK PLAY AGAIN ===== **
function AskPlayAgain()
    if STARBASE_COUNT=0 then return ST_QUIT
    print "\nTHE FEDERATION IS IN NEED OF A NEW"
    print "STARSHIP COMMANDER FOR ANOTHER MISSION."
    print "\n... IF THERE IS A VOLUNTEER,"
    A$=Ask$("\nSTEP FORWARD AND ENTER AYE :  ", 3)
    if A$="AYE" then return ST_NEWGAME
    return ST_QUIT
end function


' ** ===== SHOW VICTORY ===== **
function ShowVictory()
    print : Pause()
    print "\nCONGRATULATIONS, CAPTAIN! THE LAST"
    print "KLINGON BATTLE CRUISER MENACING THE"
    print "FEDERATION HAS BEEN DESTROYED."
    print "\nYOUR EFFICIENCY RATING IS";
    print int(1000*(K7/(STARDATE_CUR-STARDATE_START))^2)
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
      print "*** SHORT RANGE SENSORS ARE OUT ***"
      if SLSFLAG=1 then return Lrs()
      return ST_COMMAND
    end if

    ' PRINT SHORT RANGE SCAN + SUMMARY DATA
    if SRSFLAG=0 then
      print
      print " SHORT RANGE SCAN + SUMMARY DATA "
    end if
    SRSFLAG=0
    ATAKFLAG=0
    Docked=0

    ' CHECK IF SHIP IS DOCKED
    for I=SECTOR_X-1 to SECTOR_X+1
      for J=SECTOR_Y-1 to SECTOR_Y+1
        if int(I+.5)<1 or int(I+.5)>8 or int(J+.5)<1 or int(J+.5)>8 then continue for
        if CheckSector(STARBASE_TOKEN$, I, J)=1 then
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
      SHIP_ENERGY=ENERGY_MAX
      TORPEDO_COUNT=TORPEDO_MAX
      print
      print "SHIELDS DROPPED FOR DOCKING PURPOSES"
      SHIELD_UNITS=0
    else

      ' OTHERWISE ...
      D0=0

      ' CHECK IF COMBAT AREA IS RED
      if K3>0 then C$="RED"

      ' COMBAT AREA IS GREEN
      if K3=0 then
        C$="GREEN"
        if SHIP_ENERGY<ENERGY_MAX*.1 then C$="AMBER"
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
    print "   +-+-+-+-+-+-+-+-- STARDATE  ";int(STARDATE_CUR*10)*.1
    
    ' PRINT QUADRANT
    for I=1 to 8
      I$=right$(str$(I),1)
      print " ";I$;" |"; : ' BORDER

      ' PRINT QUADRANT CELLS
      J1=(I-1)*24+1
      J2=(I-1)*24+22
      for J = J1 to J2 step 3
        CELL$=mid$(THIS_QUADRANT$,J,3)
        if CELL$="   " then print " ";
        if CELL$<>"   " then print left$(CELL$,1);
        print "|";
      next J

      ' PRINT SUMMARY DATA
      select case I
      case 1
        print " DAYS LEFT ";.1*int((STARDATE_START+MISSION_DAYS-STARDATE_CUR)*10);
      case 2
        print " CONDITION "; : print C$;
      case 3
        print " QUADRANT  ";QUADRANT_X;",";QUADRANT_Y;
      case 4
        print " SECTOR    ";SECTOR_X;",";SECTOR_Y;
      case 5
        print " TORPEDOES ";int(TORPEDO_COUNT);
      case 6
        print " ENERGY    ";int(SHIP_ENERGY+SHIELD_UNITS);
      case 7
        print " SHIELDS   ";int(SHIELD_UNITS);
        if SHIELD_UNITS<201 and K3>0 then print LOW$;
      case 8
        print " KLINGONS  ";int(KLINGON_COUNT);
      end select
      print
    next I

    ' PRINT MAX WARP
    print "   +-+-+-+-+-+-+-+-+";
    MW=SHIP_ENERGY/8
    MW=MW*10
    MW=int(MW)
    MW=MW/10
    if MW>8 then MW=8
    if DEVICE_DAMAGE(1)<0 and MW>0.2 then MW=0.2
    print " MAX WARP  ";MW
    if SLSFLAG=1 then return Lrs()
    return ST_COMMAND
end function


' ** ===== LIBRARY COMPUTER ===== **
function Computer()

    ' CHECK COMPUTER IS AVAILABLE
    if DEVICE_DAMAGE(8)<0 then 
        print "\nSHIPS COMPUTER DISABLED"
        return ST_COMMAND
    end if

    ' PRINT FUNCTIONS AVAILABLE FROM COMPUTER
    print "\nFUNCTIONS AVAILABLE FROM COMPUTER:" : print
    print " 0 - CUMULATIVE GALACTIC RECORD"
    print " 1 - STATUS & DAMAGE REPORT"
    print " 2 - PHOTON TORPEDO TARGETING DATA"
    print " 3 - STARBASE NAV DATA"
    print " 4 - DIRECTION/DISTANCE CALCULATOR"
    print " 5 - GALAXY REGION NAME MAP"
    ' CHECK IF COMPUTER IS ACTIVE
    if COMFLAG=1 then
      print "0"
      A=0
      A1=A
    else
      A=AskNumber(chr$(13)+"COMPUTER ACTIVE & AWAITING COMMAND :  ", 1)
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
      return ComputerNavCalcKlingon()
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
      print "  COMPUTER RECORD OF GALAXY FOR "
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
          CH$=ECOL$+mid$(G1$,1,1) : print CH$;
          CH$=DCOL$+mid$(G1$,2,1) : print CH$;
          CH$=HCOL$+mid$(G1$,3,1) : print CH$;FCOL$;
          if GALFLAG=1 then print "|"; : GALFLAG=0
        next J
      end if

      if RowIsRegion=1 then
        J=9
        QN$=QuadrantName$(I, 1, 1) : J0=int(11-.5*len(QN$))
        print "|";
        print tab(J0);QN$;
        print tab(18);"|";
        QN$=QuadrantName$(I, 5, 1) : J0=int(27-.5*len(QN$))
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
    print "  THE GALAXY: \n\n   ";
    return ComputerGalacticRecord()
end function

' ** ===== COMPUTER BASE NAV ===== **
function ComputerBaseNav()
    H8=0 : A1=3
    if B3<>0 then
      print "\nFROM ENTERPRISE TO STARBASE"
      return ComputerCalcCompute(SECTOR_Y, SECTOR_X, B4, B5, 10)
    end if
    print "\nMR. SPOCK REPORTS, SENSORS SHOW NO"
    print "STARBASES IN THIS QUADRANT." : return ST_COMMAND
end function


' ** ===== COMPUTER STATUS REPORT ===== **
function ComputerStatusReport()

    print "  STATUS REPORT: \n"
    
    if KLINGON_COUNT>1 then 
        X$="S"
    else
        X$=""
    end if

    print "\n KLINGONS LEFT :";KLINGON_COUNT
    print " ENERGY        :";int(SHIP_ENERGY+SHIELD_UNITS)
    print " TORPEDOES     :";int(TORPEDO_COUNT)
    print "\n  MISSION MUST BE COMPLETED IN ";.1*int((STARDATE_START+MISSION_DAYS-STARDATE_CUR)*10)
    print " STARDATES"

    ' MULTIPLE STARBASES
    if STARBASE_COUNT<2 then 
        X$=""
    else
        X$="S"
    end if

    ' CHECK IF ANY STARBASES ARE LEFT
    if STARBASE_COUNT<1 then
      print "\n YOUR STUPIDITY HAS LEFT YOU ON YOUR OWN"
      print "IN THE GALAXY -- YOU HAVE NO STARBASES"
      print "LEFT!" : return Damage()
    end if

    print "\n  THE FEDERATION IS MAINTAINING ";STARBASE_COUNT
    print " STARBASE";X$;" IN THE GALAXY"; chr$(13)
    return Damage()
end function


' ** ===== COMPUTER NAV CALC KLINGON ===== **
function ComputerNavCalcKlingon()
    if K3<=0 then NoEnemyMsg() : return ST_COMMAND
    if K3>1 then 
        X$="S"
    else
        X$=""
    end if
    print "\nFROM ENTERPRISE TO KLINGON SHIP";X$
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
        START_DIRECTION=7
        if abs(DY)>=abs(DX) then
          print "\n DIRECTION =";
          DIRECTION=START_DIRECTION+(abs(DX)/abs(DY))
        else
          print "\n DIRECTION =";
          DIRECTION=START_DIRECTION+(((abs(DX)-abs(DY))+abs(DX))/abs(DX))
        end if
      else
        if DX>0 or DY>0 then START_DIRECTION=1
        if DY=0 then START_DIRECTION=5
        if abs(DY)<=abs(DX) then
          print "\n DIRECTION =";
          DIRECTION=START_DIRECTION+(abs(DY)/abs(DX))
        else
          print "\n DIRECTION =";
          DIRECTION=START_DIRECTION+(((abs(DY)-abs(DX))+abs(DY))/abs(DY))
        end if
      end if
    else
      if DY>0 then
        START_DIRECTION=3
        if abs(DY)>=abs(DX) then
          print "\n DIRECTION =";
          DIRECTION=START_DIRECTION+(abs(DX)/abs(DY))
        else
          print "\n DIRECTION =";
          DIRECTION=START_DIRECTION+(((abs(DX)-abs(DY))+abs(DX))/abs(DX))
        end if
      else
        START_DIRECTION=5
        if abs(DY)<=abs(DX) then
          print "\n DIRECTION =";
          DIRECTION=START_DIRECTION+(abs(DY)/abs(DX))
        else
          print "\n DIRECTION =";
          DIRECTION=START_DIRECTION+(((abs(DY)-abs(DX))+abs(DY))/abs(DY))
        end if
      end if
    end if
    DIRECTION=DIRECTION*1000 : DIRECTION=DIRECTION+0.5 : DIRECTION=int(DIRECTION) : DIRECTION=DIRECTION/1000
    print DIRECTION
    print " DISTANCE  =";
    DIST=sqr(DX^2+DY^2)
    if DIST_DIV>1 then DIST=DIST/DIST_DIV
    DIST=DIST*1000 : DIST=DIST+0.5 : DIST=int(DIST) : DIST=DIST/1000
    print DIST
    return ST_COMMAND
end function


' ** ===== SHARED MESSAGE: NO ENEMY IN QUADRANT ===== **
function NoEnemyMsg()
    print : background 6: color 1: print "SCIENCE OFFICER SPOCK REPORTS SENSORS"
    print "SHOW NO ENEMY SHIPS IN THIS QUADRANT";:background 0: print
    return
end function


' FIND EMPTY PLACE IN QUADRANT (FOR THINGS)
function FindEmpty()
    ' ** RETRY UNTIL SQUARE IS EMPTY (THREE SPACES) **
    do
        RANDOM_X=FNR(1) : RANDOM_Y=FNR(1)
    loop until CheckSector(EMPTY_TOKEN$, RANDOM_X, RANDOM_Y)=1
    TOKEN_X=int(RANDOM_X+.5)
    TOKEN_Y=int(RANDOM_Y+.5)
    return
end function


' INSERT TOKEN$ AT SECTOR (TOKEN_X, TOKEN_Y) IN THIS_QUADRANT$
function PlaceToken(TOKEN$, TOKEN_X, TOKEN_Y)
    SECTOR_POS=SectorIndex(TOKEN_X, TOKEN_Y)

    if len(TOKEN$)<>3 then
      print "TOKEN LENGTH ERROR: ";TOKEN$;" LEN=";len(TOKEN$)
      stop
    end if

    if SECTOR_POS=1 then
        THIS_QUADRANT$=TOKEN$+right$(THIS_QUADRANT$,189)
    else if SECTOR_POS=190 then
        THIS_QUADRANT$=left$(THIS_QUADRANT$,189)+TOKEN$
    else
        THIS_QUADRANT$=left$(THIS_QUADRANT$,SECTOR_POS-1)+TOKEN$+right$(THIS_QUADRANT$,190-SECTOR_POS)
    end if
    return
end function


' 1-BASED START INDEX IN THIS_QUADRANT$ FOR SECTOR (SX, SY); 3 CHARS PER CELL
function SectorIndex(SX, SY)
    TX=int(SX+.5)
    TY=int(SY+.5)
    return (TY-1)*3+(TX-1)*24+1
end function

' RETURN 1 IF TOKEN$ OCCUPIES SECTOR (TOKEN_X, TOKEN_Y), ELSE 0
function CheckSector(TOKEN$, TOKEN_X, TOKEN_Y)
    if mid$(THIS_QUADRANT$, SectorIndex(TOKEN_X, TOKEN_Y), 3)<>TOKEN$ then return 0
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
    if CRSTART=1 then CR$="PRESS RETURN TO BEGIN"
    if CRSTART=0 then CR$="PRESS RETURN TO CONTINUE"
    LX=0 : print "  ":print CR$:print "  "
    GetInput()
    CRSTART=0
    return
end function

' ** KEY TO SRS ICONS **
function ShowKey()
    print "\n KEY TO SHORT RANGE SCANNER ICONS:" : print
    print "  E  = THE USS ENTERPRISE"
    print "  B  = FEDERATION STARBASE"
    print "  *  = STAR"
    print "  K  = KLINGON BATTLE CRUISER"
    return
end function

' ** LIST OF COMMANDS **
function ShowCommands()
    print "\n USE THESE COMMANDS:" : print
    print "  NAV  - TO SET COURSE"
    print "  SRS  - FOR SHORT RANGE SCAN"
    print "  LRS  - FOR LONG RANGE SCAN"
    print "  SLS  - FOR SHORT & LONG RANGE SCAN"
    print "  PHA  - TO FIRE PHASERS"
    print "  TOR  - TO FIRE PHOTON TORPEDOES"
    print "  SHE  - TO RAISE OR LOWER SHIELDS"
    print "  DAM  - FOR DAMAGE CONTROL REPORTS"
    print "  COM  - TO CALL ON LIBRARY-COMPUTER"
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
    print " DECIMALS MAY BE    5 ---*--- 1"
    print " USED (EG. 8.57)        ..."
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

    ' Lazy once-per-run: DoCommand calls this; CMD_DICT starts -1 (no slot yet).
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
    DEVICE_NAME$(1)="WARP ENGINES"
    DEVICE_NAME$(2)="SHORT RANGE SENSORS"
    DEVICE_NAME$(3)="LONG RANGE SENSORS"
    DEVICE_NAME$(4)="PHASER CONTROL"
    DEVICE_NAME$(5)="PHOTON TUBES"
    DEVICE_NAME$(6)="DAMAGE CONTROL"
    DEVICE_NAME$(7)="SHIELD CONTROL"
    DEVICE_NAME$(8)="LIBRARY-COMPUTER"
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


