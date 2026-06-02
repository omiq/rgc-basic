#OPTION PETSCII
screencodes on : background 0
' ** SUPER STAR TREK -- STRUCTURED (STATE-MACHINE) VERSION
' ** BY MIKE MAYFIELD 1974
' ** MODIFIED BY DAVID AHL 1978
' ** CONVERTED TO 40 COLUMNS
' ** BY ELECTRON.GREG 2022-2023
' ** MODIFIED BY CHRIS GARRETT 2025
' ** ( FOR TUTORIAL USE )
' ** SUPPORT ELECTRON.GREG
' ** https://electrongreg.itch.io/
' **
' ** THE WHOLE GAME IS NOW DRIVEN BY ONE STATE LOOP (BELOW). EACH STATE
' ** IS A FUNCTION THAT DOES ITS WORK AND RETURNS THE NEXT STATE, SO
' ** THERE ARE NO GOTOS BETWEEN ROUTINES


ST_QUIT=0 : ST_NEWGAME=1 : ST_NEWQUAD=2 : ST_COMMAND=3 : ST_DEAD=4
ST_GAMEOVER=5 : ST_VICTORY=6 : ST_MISSIONEND=7 : ST_PLAYAGAIN=8
ENTERPRISE_TOKEN$="E  " : KLINGON_TOKEN$="K  " : STARBASE_TOKEN$="B  " : STAR_TOKEN$="*  " : EMPTY_TOKEN$="   "
A1$="NAVSRSLRSPHATORSHEDAMCOMXXXHLP"
InitColours()
' COURSE_VEC(9,2) = nav keypad deltas (course n -> dx, dy); DEVICE_DAMAGE(8) = stardates-to-repair per system
dim G(8,8),COURSE_VEC(9,2),K(3,3),N(3),Z(8,8),DEVICE_DAMAGE(8)

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



' ** ===== ONE-TIME GAME SETUP (NEW GAME / RESTART) ===== **
function SetupGame()
    Z2$=""
    ATAKFLAG=0
    SLSFLAG=0
    N=rnd(-1)
    print chr$(147);
    print HCOL$;"{YELLOW}   --S-U-P-E-R---S-T-A-R---T-R-E-K--"
    print "{WHITE}"
    for N=1 to 5
      print
    next
    print BCOL$;
    print "                    ,------*-------,"
    print "    ,-------------,  '---  -------'"
    print "    '--------{109}{109}--'      / /"
    print "          ,---{109}{109}-------/ /--,"
    print "          '----------------'"
    print DCOL$
    print "    THE USS ENTERPRISE --- NCC-1701"
    for N=1 to 5
      print FCOL$
    next
    CRSTART=1
    Pause()
    RANDOM_SEED=rnd(-TI) : ' ** RANDOM SEED GENERATOR **
    print : print "{CLR}           GENERATING GALAXY";
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
    if STARBASE_COUNT<>1 then X$="S" : X0$=" ARE "
    print
    print "{CLR}{REVERSE ON}YOUR ORDERS ARE AS FOLLOWS:{REVERSE OFF}"
    print
    print "DESTROY THE ";KLINGON_COUNT;" KLINGON WARSHIPS BEFORE"
    print "STARDATE ";STARDATE_START+MISSION_DAYS;". THIS GIVES YOU ";MISSION_DAYS;" DAYS."
    print "THERE";X0$;STARBASE_COUNT;" STARBASE";X$;" IN THE GALAXY"
    print "FOR RESUPPLYING & REPAIRING YOUR SHIP."
    I=rnd(1)
    return ST_NEWQUAD
end function




' ** ===== ENTER A QUADRANT: SET IT UP, PLACE OBJECTS, SHORT SCAN ===== **
function EnterQuadrant()
    Z4=QUADRANT_X
    Z5=QUADRANT_Y
    K3=0 : B3=0 : S3=0
    G5=0
    D4=.5*rnd(1)
    Z(QUADRANT_X,QUADRANT_Y)=G(QUADRANT_X,QUADRANT_Y)
    if QUADRANT_X >= 1 and QUADRANT_X <=8 and QUADRANT_Y>=1 and QUADRANT_Y<=8 then
      QuadrantName()
      print
      if STARDATE_START=STARDATE_CUR then
        print "YOUR MISSION BEGINS WITH YOUR STARSHIP"
        print "IN THE QUADRANT, ";G2$;"."
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
        SRSFLAG=1
        print "ENTERING ";G2$;" QUADRANT..."
      end if
    end if
    ' Decode G(quad): K3/B3/S3 = klingons / starbases / stars in this quadrant
    K3=int(G(QUADRANT_X,QUADRANT_Y)*.01)
    B3=int(G(QUADRANT_X,QUADRANT_Y)*.1)-10*K3
    S3=G(QUADRANT_X,QUADRANT_Y)-100*K3-10*B3
    for I=1 to 3
      K(I,1)=0
      K(I,2)=0
    next I
    for I=1 to 3
      K(I,3)=0
    next I
    QUADRANT_BUFFER$=SPACE_PAD$+SPACE_PAD$+SPACE_PAD$+SPACE_PAD$+SPACE_PAD$+SPACE_PAD$+SPACE_PAD$+left$(SPACE_PAD$,17)
    ' POSITION ENTERPRISE IN QUADRANT, THEN PLACE "K3" KLINGONS, &
    ' "B3" STARBASES, & "S3" STARS ELSE WHERE.
    A$=ENTERPRISE_TOKEN$
    TOKEN_X=SECTOR_X
    TOKEN_Y=SECTOR_Y
    PlaceToken()
    if K3 >= 1 then
      for I=1 to K3
        FindEmpty()
        A$=KLINGON_TOKEN$
        TOKEN_X=RANDOM_X : TOKEN_Y=RANDOM_Y
        PlaceToken()
        K(I,1)=RANDOM_X : K(I,2)=RANDOM_Y : K(I,3)=KLINGON_HP_BASE*(0.5+rnd(1))
      next I
    end if
    if B3 >= 1 then
      FindEmpty()
      A$=STARBASE_TOKEN$
      TOKEN_X=RANDOM_X : B4=RANDOM_X
      TOKEN_Y=RANDOM_Y : B5=RANDOM_Y
      PlaceToken()
    end if
    for I=1 to S3
      FindEmpty()
      A$=STAR_TOKEN$
      TOKEN_X=RANDOM_X : TOKEN_Y=RANDOM_Y
      PlaceToken()
    next I
    return ShortRangeScan()
end function




' ** ===== COMMAND PHASE: ENERGY CHECK, PROMPT, DISPATCH ONE COMMAND ===== **
function DoCommand()
    if SHIELD_UNITS+SHIP_ENERGY <= 10 or (SHIP_ENERGY<=10 and DEVICE_DAMAGE(7)<>0) then
      print : print "** FATAL ERROR **"
      print "YOUVE STRANDED YOUR SHIP IN SPACE."
      print "YOU HAVE INSUFFICIENT MANOEUVRING"
      print "ENERGY, & SHIELD CONTROL IS PRESENTLY"
      print "INCAPABLE OF CROSS-CIRCUITING TO"
      print "ENGINE ROOM!!"
      print : Pause()
      return ST_GAMEOVER
    end if
    do
      print
      SRSFLAG=0
      LX=3
      print "{13}{REVERSE ON}{LIGHTBLUE}COMMAND:{REVERSE OFF}{WHITE} ";
      GetInput()
      A$=LII$ : Z2$=A$ : ATAKFLAG=0
      if A$="SLS" then SLSFLAG=1
      if A$="SLS" then 
        print "{CLR}{REVERSE ON}SHORT & LONG RANGE SCAN...{REVERSE OFF}"
        return ShortRangeScan()
      end if
      if A$="KEY" then ShowKey() : ' KEY TO SRS ICONS
      if A$="KEY" then continue do
      COMFLAG=0
      if A$="GAL" and DEVICE_DAMAGE(8)>=0 then A$="COM" : COMFLAG=1
      if DEVICE_DAMAGE(8)<0 and A$="GAL" then 
        print : print "SHIPS COMPUTER DISABLED"
        continue do
      end if
      CMD=0
      for I=1 to 10
        if left$(A$,3)=mid$(A1$,3*I-2,3) then CMD=I
      next I

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
    print : LX=5 : print "COURSE (1-9) :  "; : GetInput()
    C1=val(LII$) : if C1=9 then C1=1
    if C1<1 or C1>=9 then
      background 6: color 1
      print : print "LT. SULU REPORTS, INCORRECT COURSE"
      print "DATA, SIR!";: background 0: print
      return ST_COMMAND
    end if
    X$="8"
    if DEVICE_DAMAGE(1)<0 then X$="0.2"
    SRSFLAG=1
    LX=5
    print "WARP FACTOR (0-";X$;") :  ";
    GetInput()
    NAV_WARP_FACTOR=val(LII$)
    if DEVICE_DAMAGE(1)<0 and NAV_WARP_FACTOR>.2 then
      print : print "WARP ENGINES ARE DAMAGED."
      print "MAXIMUM SPEED = WARP 0.2" : return ST_COMMAND
    end if
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
      print "ENGINES WONT TAKE WARP ";NAV_WARP_FACTOR;"!";: background 0 : return ST_COMMAND
    end if
    ' KLINGONS MOVE/FIRE ON MOVING STARSHIP . . .
    KlingonsMove: for I=1 to K3
      if K(I,3)=0 then continue for
      A$=EMPTY_TOKEN$ : TOKEN_X=K(I,1) : TOKEN_Y=K(I,2) : PlaceToken() : FindEmpty()
      K(I,1)=TOKEN_X : K(I,2)=TOKEN_Y : A$=KLINGON_TOKEN$ : PlaceToken()
    next I
    KlingonsFire()
    if SHIPDEAD then return ST_DEAD
    D1=0 : D6=NAV_WARP_FACTOR : if NAV_WARP_FACTOR>=1 then D6=1
    for I=1 to 8
      if DEVICE_DAMAGE(I)>=0 then continue for
      DEVICE_DAMAGE(I)=DEVICE_DAMAGE(I)+D6
      if DEVICE_DAMAGE(I)>-.1and DEVICE_DAMAGE(I)<0then DEVICE_DAMAGE(I)=-.1 : continue for
      if DEVICE_DAMAGE(I)<0 then continue for
      if D1<>1 then D1=1 : print : print "DAMAGE CONTROL REPORT :   "
      DEVICE_INDEX=I : DeviceName() : print G2$;" REPAIR COMPLETED"
    next I
    if rnd(1)<=.2 then
      DEVICE_INDEX=FNR(1)
      if rnd(1)<.6 then
        DEVICE_DAMAGE(DEVICE_INDEX)=DEVICE_DAMAGE(DEVICE_INDEX)-(rnd(1)*5+1) : print : print "DAMAGE CONTROL REPORTS:"
        DeviceName() : print G2$;" DAMAGED"
      else
        DEVICE_DAMAGE(DEVICE_INDEX)=DEVICE_DAMAGE(DEVICE_INDEX)+rnd(1)*3+1 : print : print "DAMAGE CONTROL REPORTS:"
        DeviceName() : print G2$;" PARTLY REPAIRED"
      end if
    end if
    ' BEGIN MOVING STARSHIP
    A$=EMPTY_TOKEN$ : TOKEN_X=int(SECTOR_X) : TOKEN_Y=int(SECTOR_Y) : PlaceToken()
    X1=COURSE_VEC(C1,1)+(COURSE_VEC(C1+1,1)-COURSE_VEC(C1,1))*(C1-int(C1)) : X=SECTOR_X : Y=SECTOR_Y
    X2=COURSE_VEC(C1,2)+(COURSE_VEC(C1+1,2)-COURSE_VEC(C1,2))*(C1-int(C1)) : Q4=QUADRANT_X : Q5=QUADRANT_Y
    MoveInterrupted=0 : CrossedQuadrant=0
    for I=1 to N : SECTOR_X=SECTOR_X+X1 : SECTOR_Y=SECTOR_Y+X2
        if SECTOR_X<1 or SECTOR_X>=9 or SECTOR_Y<1 or SECTOR_Y>=9 then CrossedQuadrant=1 : exit for
        S8=int(SECTOR_X)*24+int(SECTOR_Y)*3-26 : if mid$(QUADRANT_BUFFER$,S8,2)="  "then continue for
        SECTOR_X=int(SECTOR_X-X1) : SECTOR_Y=int(SECTOR_Y-X2) : print : print "WARP ENGINES SHUT DOWN AT ";
        print "SECTOR ";SECTOR_X;",";SECTOR_Y
        print "DUE TO BAD NAVIGATION"
        SRSFLAG=1
        MoveInterrupted=1
        exit for
    next I
    if CrossedQuadrant=1 then
      X=8*QUADRANT_X+X+N*X1 : Y=8*QUADRANT_Y+Y+N*X2 : QUADRANT_X=int(X/8) : QUADRANT_Y=int(Y/8) : SECTOR_X=int(X-QUADRANT_X*8)
      SECTOR_Y=int(Y-QUADRANT_Y*8) : if SECTOR_X=0 then QUADRANT_X=QUADRANT_X-1 : SECTOR_X=8
      if SECTOR_Y=0 then QUADRANT_Y=QUADRANT_Y-1 : SECTOR_Y=8
      X5=0 : if QUADRANT_X<1 then X5=1 : QUADRANT_X=1 : SECTOR_X=1
      if QUADRANT_X>8 then X5=1 : QUADRANT_X=8 : SECTOR_X=8
      if QUADRANT_Y<1 then X5=1 : QUADRANT_Y=1 : SECTOR_Y=1
      if QUADRANT_Y>8 then X5=1 : QUADRANT_Y=8 : SECTOR_Y=8
      if X5<>0 then
        print : background 6: color 1: print "LT. UHURA REPORTS MESSAGE FROM STARFLEET";
        print " COMMAND:{13}PERMISSION TO ATTEMPT CROSSING OF GALACTIC PERIMETER IS HEREBY{13}{RED}*DENIED*{WHITE}";
        print " - SHUT DOWN YOUR ENGINES.{13}{13} CHIEF ENGINEER SCOTT REPORTS WARP";
        print " ENGINES SHUT DOWN AT SECTOR ";SECTOR_X;",";SECTOR_Y;" OF QUADRANT ";QUADRANT_X;",";QUADRANT_Y;".";:
        background 0: print
        SRSFLAG=1
        print : Pause()
        if STARDATE_CUR>STARDATE_START+MISSION_DAYS then return ST_GAMEOVER
      end if
      if 8*QUADRANT_X+QUADRANT_Y=8*Q4+Q5 then
        A$=ENTERPRISE_TOKEN$ : TOKEN_X=int(SECTOR_X) : TOKEN_Y=int(SECTOR_Y) : PlaceToken() : ManeuverEnergy() : T8=1
        if NAV_WARP_FACTOR<1 then T8=.1*int(10*NAV_WARP_FACTOR)
        STARDATE_CUR=STARDATE_CUR+T8 : if STARDATE_CUR>STARDATE_START+MISSION_DAYS then return ST_GAMEOVER
        return ShortRangeScan()
      end if
      STARDATE_CUR=STARDATE_CUR+1 : ManeuverEnergy() : return ST_NEWQUAD
    end if
    if MoveInterrupted=0 then 
      SECTOR_X=int(SECTOR_X)
      SECTOR_Y=int(SECTOR_Y)
    end if
    A$=ENTERPRISE_TOKEN$ : TOKEN_X=int(SECTOR_X) : TOKEN_Y=int(SECTOR_Y) : PlaceToken() : ManeuverEnergy() : T8=1
    if NAV_WARP_FACTOR<1 then T8=.1*int(10*NAV_WARP_FACTOR)
    STARDATE_CUR=STARDATE_CUR+T8 : if STARDATE_CUR>STARDATE_START+MISSION_DAYS then return ST_GAMEOVER

    ' SEE IF DOCKED, THEN GET COMMAND
    return ShortRangeScan()
end function




' MANEUVER ENERGY S/R **
function ManeuverEnergy()
    SHIP_ENERGY=SHIP_ENERGY-N-10
    if SHIP_ENERGY>=0 then return
    print : print "SHIELD CONTROL SUPPLIES ENERGY TO"
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
    print : print "{13}{LIGHTBLUE}LONG RANGE SCAN FOR QUADRANT{WHITE} ";QUADRANT_X;",";QUADRANT_Y
    print : O1$=" ┌─────┬─────┬─────┐" : print "{13}{GREEN}";O1$;
    O2$=" ├─────┼─────┼─────┤":O3$=" {173}─────{177}─────{177}─────{189}" 
    print "         ";ECOL$;"#";DCOL$;"#";HCOL$;"#";FCOL$
    for I=QUADRANT_X-1 to QUADRANT_X+1
      N(1)=-1 : N(2)=-2 : N(3)=-3
      for J=QUADRANT_Y-1 to QUADRANT_Y+1
        if I>0 and I<9 and J>0 and J<9 then N(J-QUADRANT_Y+2)=G(I,J) : Z(I,J)=G(I,J)
      next J
      for L=1 to 3
        if K1=2 and L=3 then print "";
        print " {221}";
        print " ";
        if N(L)<0 then
          print "▒▒▒";
          continue for
        end if
        G1$=right$(str$(N(L)+1000),3)
        G2$=ECOL$+mid$(G1$,1,1) : print G2$;
        G2$=DCOL$+mid$(G1$,2,1) : print G2$;
        G2$=HCOL$+mid$(G1$,3,1) : print G2$;FCOL$;
      next L
      print " {221}"; : K1=K1+1
      if K1=1 then print "        . . ."
      if K1=3 then print "      .   .   ."
      if K1=5 then print "    .           ."
      K1=K1+1 : if K1<6 then print O2$;
      if K1=6 then print O3$;
      if K1=2 then print "       .  .  ."
      if K1=4 then print "     .  {CYAN}BASES{GREEN}";
      if K1=4 then print "  ."
      if K1=6 then print "  {PINK}KLINGONS{WHITE}    {YELLOW}STARS{WHITE}"
    next I
    K1=0 : if SLSFLAG=1 then SLSFLAG=0
    return ST_COMMAND
end function


' ** ===== PHASER CONTROL ===== **
function Phasers()
    if DEVICE_DAMAGE(4)<0 then print : print "PHASERS INOPERATIVE" : return ST_COMMAND
    if K3<=0 then NoEnemyMsg() : return ST_COMMAND
    if DEVICE_DAMAGE(8)<0 then print : print "COMPUTER FAILURE HAMPERS ACCURACY"
    print : print "PHASERS LOCKED ON TARGET!  "
    do
    print : print "ENERGY AVAILABLE = ";SHIP_ENERGY;" UNITS"
    LX=5 : print "NUMBER OF UNITS TO FIRE :  "; : GetInput()
    X=val(LII$) : if X<=0 then return ST_COMMAND
    loop until SHIP_ENERGY-X>=0
    SHIP_ENERGY=SHIP_ENERGY-X : if DEVICE_DAMAGE(7)<0 then X=X*rnd(1)
    H1=int(X/K3)
    for I=1 to 3
      if K(I,3)<=0 then continue for
      H=int((H1/FND(0))*(rnd(1)+2))
      if H<=.15*K(I,3) then
        print : print " SENSORS SHOW NO DAMAGE TO ENEMY"
        print " AT ";K(I,1);",";K(I,2)
        continue for
      end if
      K(I,3)=K(I,3)-H : print
      print H;" UNIT HIT KLINGON AT ";K(I,1);",";K(I,2)
      if K(I,3)>0 then
        print " (SENSORS SHOW ";int(K(I,3));" UNITS REMAINING)"
        continue for
      end if
      print " *** KLINGON DESTROYED ***"
      K3=K3-1 : KLINGON_COUNT=KLINGON_COUNT-1 : TOKEN_X=K(I,1) : TOKEN_Y=K(I,2) : A$=EMPTY_TOKEN$ : PlaceToken()
      K(I,3)=0 : G(QUADRANT_X,QUADRANT_Y)=G(QUADRANT_X,QUADRANT_Y)-100 : Z(QUADRANT_X,QUADRANT_Y)=G(QUADRANT_X,QUADRANT_Y)
      if KLINGON_COUNT<=0 then return ST_VICTORY
    next I
    if K3>0 then print : Pause()
    KlingonsFire()
    if SHIPDEAD then return ST_DEAD
    return ST_COMMAND
end function


' ** ===== PHOTON TORPEDO ===== **
function Torpedo()
    if TORPEDO_COUNT<=0 then print : print "ALL PHOTON TORPEDOES EXPENDED" : return ST_COMMAND
    if DEVICE_DAMAGE(5)<0 then print : print "PHOTON TUBES ARE NOT OPERATIONAL" : return ST_COMMAND
    do
      ShowDirections() : ' ** DIRECTION HELPER **
      print : LX=5 : print "PHOTON TORPEDO COURSE (1-9) :  "; : GetInput()
      C1=val(LII$) : if C1=9 then C1=1
      if C1<1 or C1>=9 then
        print : background 6: color 1: print "ENSIGN CHEKOV REPORTS, INCORRECT"
        print "COURSE DATA, SIR!";:background 0: print : return ST_COMMAND
      end if
      X1=COURSE_VEC(C1,1)+(COURSE_VEC(C1+1,1)-COURSE_VEC(C1,1))*(C1-int(C1)) : SHIP_ENERGY=SHIP_ENERGY-2 : TORPEDO_COUNT=TORPEDO_COUNT-1
      X2=COURSE_VEC(C1,2)+(COURSE_VEC(C1+1,2)-COURSE_VEC(C1,2))*(C1-int(C1)) : X=SECTOR_X : Y=SECTOR_Y
      print : print "TORPEDO TRACKING:"
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
        print " ";X3;",";Y3 : A$=EMPTY_TOKEN$ : TOKEN_X=X : TOKEN_Y=Y : CheckSector()
        if Z3<>0 then continue do

        A$=KLINGON_TOKEN$ : TOKEN_X=X : TOKEN_Y=Y : CheckSector()
        if Z3<>0 then
          print " *** KLINGON DESTROYED ***"
          K3=K3-1 : if K3>0 then print : Pause()
          KLINGON_COUNT=KLINGON_COUNT-1 : if KLINGON_COUNT<=0 then return ST_VICTORY
          HitIdx=3
          for I=1 to 3
            if X3=K(I,1) and Y3=K(I,2) then HitIdx=I : exit for
          next I
          K(HitIdx,3)=0
          TOKEN_X=X : TOKEN_Y=Y : A$=EMPTY_TOKEN$ : PlaceToken()
          G(QUADRANT_X,QUADRANT_Y)=K3*100+B3*10+S3 : Z(QUADRANT_X,QUADRANT_Y)=G(QUADRANT_X,QUADRANT_Y) : KlingonsFire()
          if SHIPDEAD then return ST_DEAD
          return ST_COMMAND
        end if

        A$=STAR_TOKEN$ : TOKEN_X=X : TOKEN_Y=Y : CheckSector()
        if Z3<>0 then
          print " ** STAR AT";X3;",";Y3;"ABSORBED TORPEDO **"
          if K3<>0 then print : Pause()
          KlingonsFire()
          if SHIPDEAD then return ST_DEAD
          return ST_COMMAND
        end if

        A$=STARBASE_TOKEN$ : TOKEN_X=X : TOKEN_Y=Y : CheckSector()
        if Z3=0 then
          RetryCourse=1
          exit do
        end if
        print " *** STARBASE DESTROYED ***"
        print : Pause()
        B3=B3-1 : STARBASE_COUNT=STARBASE_COUNT-1
        if STARBASE_COUNT<=0 and KLINGON_COUNT<=STARDATE_CUR-STARDATE_START-MISSION_DAYS then
          print : background 6: color 1: print "THAT DOES IT, CAPTAIN!!  YOU ARE HEREBY"
          print "RELIEVED OF COMMAND AND SENTENCED TO 99"
          print "STARDATES AT HARD LABOUR ON CYGNUS 12!!";:background 0
          return ST_MISSIONEND
        end if
        print : print "STARFLEET COMMAND REVIEWING YOUR RECORD"
        print "TO CONSIDER COURT MARTIAL!" : D0=0
        TOKEN_X=X : TOKEN_Y=Y : A$=EMPTY_TOKEN$ : PlaceToken()
        G(QUADRANT_X,QUADRANT_Y)=K3*100+B3*10+S3 : Z(QUADRANT_X,QUADRANT_Y)=G(QUADRANT_X,QUADRANT_Y) : KlingonsFire()
        if SHIPDEAD then return ST_DEAD
        return ST_COMMAND
      loop
      if RetryCourse=1 then continue do
    loop
end function


' ** ===== SHIELD CONTROL ===== **
function Shields()
    if DEVICE_DAMAGE(7)<0 then print : print "SHIELD CONTROL INOPERABLE" : return ST_COMMAND
    print : print "ENERGY AVAILABLE = ";SHIP_ENERGY+SHIELD_UNITS
    LX=5 : print "NUMBER OF UNITS TO SHIELDS :  "; : GetInput()
    X=val(LII$)
    if X<0 or SHIELD_UNITS=X then print "<SHIELDS UNCHANGED>" : return ST_COMMAND
    if X>SHIP_ENERGY+SHIELD_UNITS then
      print :  background 6: color 1: print "SHIELD CONTROL REPORTS THIS IS NOT THE"
      print "FEDERATION TREASURY."
      print "<SHIELDS UNCHANGED>";:background 0: print : return ST_COMMAND
    end if
    SHIP_ENERGY=SHIP_ENERGY+SHIELD_UNITS-X : SHIELD_UNITS=X : print :background 6: color 1: print "DEFLECTOR CONTROL ROOM REPORT:"
    print "SHIELDS NOW AT ";int(SHIELD_UNITS);" UNITS PER"
    print "YOUR COMMAND.";:background 0: print : return ST_COMMAND
end function


' ** ===== DAMAGE CONTROL ===== **
function Damage()
    if DEVICE_DAMAGE(6)<0 then
      print : print "DAMAGE CONTROL REPORT NOT AVAILABLE"
      if D0=0 then return ST_COMMAND
    end if
    do
      if DEVICE_DAMAGE(6)<0 and D0<>0 then
        D3=0 : for I=1 to 8 : if DEVICE_DAMAGE(I)<0 then D3=D3+.1
        next I : if D3=0 then return ST_COMMAND
        D3=D3+D4 : if D3>=1 then D3=.9
        print : print "TECHNICIANS STANDING BY TO EFFECT"
        print "REPAIRS TO YOUR SHIP;"
        print "ESTIMATED TIME TO REPAIR: "
        print .01*int(100*D3);" STARDATES"
        LX=1 : print : print "AUTHORISE THE REPAIR ORDER (Y/N)? "; : GetInput()
        A$=LII$
        if A$<>"Y" then return ST_COMMAND
        for I=1 to 8 : if DEVICE_DAMAGE(I)<0 then DEVICE_DAMAGE(I)=0
        next I : STARDATE_CUR=STARDATE_CUR+D3+.1
      end if
      print : print " SYSTEM              STATE OF REPAIR"
      print      " ------------------- -----------------"
      for DEVICE_INDEX=1 to 8
        DeviceName() : print " ";G2$;left$(SPACE_PAD$,20-len(G2$));
        D2=int(DEVICE_DAMAGE(DEVICE_INDEX)*100)*.01
        if D2<0 then print CCOL$;"DAMAGED     ";D2;FCOL$
        if D2>0 then print "OPERATIONAL ";D2
        if D2=0 then print "OPERATIONAL ";D2
      next DEVICE_INDEX
      if D0=0 then exit do
    loop
    return ST_COMMAND
end function


' ** ===== KLINGONS SHOOT BACK (SETS SHIPDEAD IF SHIELDS FAIL) ===== **
function KlingonsFire()
    SHIPDEAD=0
    if K3<=0 then return
    if D0<>0 then print : print "STARBASE SHIELDS PROTECT THE ENTERPRISE"
    if D0<>0 then return
    for I=1 to 3
      if K(I,3)<=0 then continue for
      H=int((K(I,3)/FND(1))*(2+rnd(1))) : SHIELD_UNITS=SHIELD_UNITS-H : K(I,3)=K(I,3)/(3+rnd(0))
      print : print H;" UNIT HIT ENTERPRISE FROM ";K(I,1);",";K(I,2)
      if SHIELD_UNITS<=0 then SHIPDEAD=1 : return
      print " <SHIELDS DOWN TO ";SHIELD_UNITS;" UNITS>"
      if H<20 then continue for
      if rnd(1)>.6 or H/SHIELD_UNITS<=.02 then continue for
      DEVICE_INDEX=FNR(1) : DEVICE_DAMAGE(DEVICE_INDEX)=DEVICE_DAMAGE(DEVICE_INDEX)-H/SHIELD_UNITS-.5*rnd(1) : DeviceName()
      print : background 6: color 1: print "DAMAGE CONTROL REPORTS :  "
      print G2$;" DAMAGED BY THE HIT";:background 0: print
    next I
    ATAKFLAG=1
    return
end function


' ** ===== END-OF-GAME STATES ===== **
function ShowGameOver()
    print : print "IT IS STARDATE ";STARDATE_CUR
    return ST_MISSIONEND
end function


function ShipDestroyed()
    print : Pause()
    print : print "{RED}THE ENTERPRISE HAS BEEN DESTROYED.{WHITE}"
    print chr$(13);"THE FEDERATION WILL BE CONQUERED"
    return ST_GAMEOVER
end function


function ShowMissionEnd()
    print : print "THERE WERE ";KLINGON_COUNT;" KLINGON BATTLE CRUISERS"
    print "LEFT AT THE END OF YOUR MISSION."
    return ST_PLAYAGAIN
end function


function AskPlayAgain()
    if STARBASE_COUNT=0 then return ST_QUIT
    print : print "THE FEDERATION IS IN NEED OF A NEW"
    print "STARSHIP COMMANDER FOR ANOTHER MISSION."
    print : print "... IF THERE IS A VOLUNTEER,"
    LX=3 : print "STEP FORWARD AND ENTER AYE :  "; : GetInput()
    A$=LII$ : if A$="AYE" then return ST_NEWGAME
    return ST_QUIT
end function


function ShowVictory()
    print : Pause()
    print : print "CONGRATULATIONS, CAPTAIN! THE LAST"
    print "KLINGON BATTLE CRUISER MENACING THE"
    print "FEDERATION HAS BEEN DESTROYED."
    print : print "YOUR EFFICIENCY RATING IS";
    print int(1000*(K7/(STARDATE_CUR-STARDATE_START))^2)
    return ST_PLAYAGAIN
end function


' ** ===== SHORT RANGE SCAN & SUMMARY (SLS CHAINS INTO LRS) ===== **
function ShortRangeScan()
    if ATAKFLAG=1 then
      print
      Pause()
    end if
    if DEVICE_DAMAGE(2)<0 then
      print
      print "*** SHORT RANGE SENSORS ARE OUT ***"
      if SLSFLAG=1 then return Lrs()
      return ST_COMMAND
    end if
    if SRSFLAG=0 then
      print
      print "{LIGHTBLUE}SHORT RANGE SCAN + SUMMARY DATA{WHITE}"
    end if
    SRSFLAG=0
    ATAKFLAG=0
    Docked=0
    for I=SECTOR_X-1 to SECTOR_X+1
      for J=SECTOR_Y-1 to SECTOR_Y+1
        if int(I+.5)<1 or int(I+.5)>8 or int(J+.5)<1 or int(J+.5)>8 then continue for
        A$=STARBASE_TOKEN$
        TOKEN_X=I
        TOKEN_Y=J
        CheckSector()
        if Z3=1 then
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
      D0=0
      if K3>0 then C$="RED"
      if K3=0 then
        C$="GREEN"
        if SHIP_ENERGY<ENERGY_MAX*.1 then C$="AMBER"
      end if
    end if
    if K3>0 then
      print
      print CCOL$;"COMBAT AREA  ";
      print "** CONDITION RED **";FCOL$
    end if
    LOW$=" LOW!"
    print
    print "   {YELLOW}1 2 3 4 5 6 7 8"
    print "  {GREEN}{176}─{178}─{178}─{178}─{178}─{178}─{178}─{178}─┐{WHITE} {LIGHTBLUE}STARDATE{YELLOW}  ";int(STARDATE_CUR*10)*.1
    for I=1 to 8
      I$=right$(str$(I),1)
      print "{YELLOW}";I$;" {GREEN}{125}{WHITE}"; : ' BORDER
      J1=(I-1)*24+1
      J2=(I-1)*24+22
      for J = J1 to J2 step 3
        Z3$=mid$(QUADRANT_BUFFER$,J,3)
        if Z3$="   " then print " ";
        if Z3$<>"   " then print left$(Z3$,1);
        print "{GREEN}{125}{WHITE}";
      next J
      select case I
      case 1
        print " {LIGHTBLUE}DAYS LEFT{YELLOW} ";.1*int((STARDATE_START+MISSION_DAYS-STARDATE_CUR)*10);
      case 2
        print " {LIGHTBLUE}CONDITION{YELLOW} "; : print C$;
      case 3
        print " {LIGHTBLUE}QUADRANT  {YELLOW}";QUADRANT_X;",";QUADRANT_Y;
      case 4
        print " {LIGHTBLUE}SECTOR    {YELLOW}";SECTOR_X;",";SECTOR_Y;
      case 5
        print " {LIGHTBLUE}TORPEDOES {YELLOW}";int(TORPEDO_COUNT);
      case 6
        print " {LIGHTBLUE}ENERGY    {YELLOW}";int(SHIP_ENERGY+SHIELD_UNITS);
      case 7
        print " {LIGHTBLUE}SHIELDS   {YELLOW}";int(SHIELD_UNITS);
        if SHIELD_UNITS<201 and K3>0 then print LOW$;
      case 8
        print " {LIGHTBLUE}KLINGONS  {YELLOW}";int(KLINGON_COUNT);
      end select
      print
    next I
    print "  {GREEN}{173}─{177}─{177}─{177}─{177}─{177}─{177}─{177}─{189}{WHITE}";
    MW=SHIP_ENERGY/8
    MW=MW*10
    MW=int(MW)
    MW=MW/10
    if MW>8 then MW=8
    if DEVICE_DAMAGE(1)<0 and MW>0.2 then MW=0.2
    print " {LIGHTBLUE}MAX WARP{YELLOW}  ";MW
    if SLSFLAG=1 then return Lrs()
    return ST_COMMAND
end function


' ** ===== LIBRARY COMPUTER ===== **
function Computer()
    if DEVICE_DAMAGE(8)<0 then print : print "SHIPS COMPUTER DISABLED" : return ST_COMMAND
    print : print "FUNCTIONS AVAILABLE FROM COMPUTER:" : print
    print " 0 - CUMULATIVE GALACTIC RECORD"
    print " 1 - STATUS & DAMAGE REPORT"
    print " 2 - PHOTON TORPEDO TARGETING DATA"
    print " 3 - STARBASE NAV DATA"
    print " 4 - DIRECTION/DISTANCE CALCULATOR"
    print " 5 - GALAXY REGION NAME MAP"
    print : LX=1 : print chr$(13);"COMPUTER ACTIVE & AWAITING COMMAND :  ";
    if COMFLAG=1 then
      print "0"
      A=0
      A1=A
    else
      GetInput()
      A=val(LII$) : A1=A : if A<0 or A>5 then return ST_COMMAND
      if LII$="" then return ST_COMMAND
    end if
    select case A
    case 0
      H8=1 : G5=0 : A=0 : A1=0
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


function ComputerGalacticRecord()
    ' GALFLAG marks the highlighted current quadrant separator slot.
    GALFLAG=0
    if G5=0 then
      print
      print "{CLR}{REVERSE ON}COMPUTER RECORD OF GALAXY FOR "
      print "QUADRANT ";QUADRANT_X;",";QUADRANT_Y
      print "{REVERSE OFF}"
      print chr$(13);
      print "   ";
    end if
    for J=1 to 8
      J$=str$(J)
      J$=right$(J$,1)
      if A1=5 then RomanNumeral() : continue for
      if J=QUADRANT_Y then print " {WHITE}";J$;"{GREEN}  ";
      if J<>QUADRANT_Y then print " {GREEN}";J;"{GREEN}  ";
    next J
    print
    O1$="  ┌───┬───┬───┬───┬───┬───┬───┬───┐"
    O2$="  ├───┼───┼───┼───┼───┼───┼───┼───┤"
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
          if I=QUADRANT_X and J=QUADRANT_Y then print "{221}"; : GALFLAG=1
          if not (I=QUADRANT_X and (J=QUADRANT_Y or J-1=QUADRANT_Y)) then print "{221}";
          if Z(I,J)=0 then print "   "; : continue for
          G1$=right$(str$(Z(I,J)+1000),3)
          G2$=ECOL$+mid$(G1$,1,1) : print G2$;
          G2$=DCOL$+mid$(G1$,2,1) : print G2$;
          G2$=HCOL$+mid$(G1$,3,1) : print G2$;FCOL$;
          if GALFLAG=1 then print "{221}"; : GALFLAG=0
        next J
      end if
      if RowIsRegion=1 then
        J=9
        Z4=I : Z5=1 : QuadrantName() : J0=int(11-.5*len(G2$))
        print "{221}";
        print tab(J0);G2$;
        print tab(18);"{221}";
        Z5=5 : QuadrantName() : J0=int(27-.5*len(G2$))
        print tab(J0);G2$; : print tab(34);"{221}";
      end if
      if A=0 and J=9 and QUADRANT_X=I and QUADRANT_Y=8 then print
      if not (A=0 and J=9 and QUADRANT_X=I and QUADRANT_Y=8) then if A=0 then print "{221}"
      if A=5 then print
      if I<8 then print O2$
    next I
    print "  {173}{45}{178}─{177}───{177}───{177}───{177}───{177}───{177}───{177}───{189}"
    A1=0
    return ST_COMMAND
end function


function ComputerGalaxyMap()
    H8=0
    G5=1
    A=5
    A1=5
    print : print "{CLR}{REVERSE ON}THE GALAXY:{REVERSE OFF}" : print : print "   ";
    return ComputerGalacticRecord()
end function


function ComputerStatusReport()
    print : print "{CLR}{REVERSE ON}STATUS REPORT:{REVERSE OFF}";chr$(13) : X$="" : if KLINGON_COUNT>1 then X$="S"
    print : print " KLINGONS LEFT :";KLINGON_COUNT
    print " ENERGY        :";int(SHIP_ENERGY+SHIELD_UNITS)
    print " TORPEDOES     :";int(TORPEDO_COUNT)
    print : print "{13} MISSION MUST BE COMPLETED IN ";.1*int((STARDATE_START+MISSION_DAYS-STARDATE_CUR)*10)
    print " STARDATES"
    X$="S" : if STARBASE_COUNT<2then X$=""
    if STARBASE_COUNT<1 then
      print : print "{13}YOUR STUPIDITY HAS LEFT YOU ON YOUR OWN"
      print "IN THE GALAXY -- YOU HAVE NO STARBASES"
      print "LEFT!" : return Damage()
    end if
    print : print "{13} THE FEDERATION IS MAINTAINING ";STARBASE_COUNT
    print " STARBASE";X$;" IN THE GALAXY"; chr$(13)
    return Damage()
end function


function ComputerNavCalcKlingon()
    if K3<=0 then NoEnemyMsg() : return ST_COMMAND
    X$="" : if K3>1then X$="S"
    print : print "FROM ENTERPRISE TO KLINGON SHIP";
    print X$
    H8=0 : A1=2
    for I=1 to 3
      if K(I,3)<=0 then continue for
      CALC_TARGET_Y=K(I,1) : X=K(I,2)
      C1=SECTOR_X : A=SECTOR_Y : ComputerCalcCompute()
    next I
    return ST_COMMAND
end function


function ComputerCalculator()
    H8=1 : A1=4
    print : print "DIRECTION/DISTANCE CALCULATOR:"
    print : print "YOU ARE AT QUADRANT ";QUADRANT_X;",";QUADRANT_Y
    print "             SECTOR ";SECTOR_X;",";SECTOR_Y
    print : LX=4 : print "ENTER INITIAL COORDINATES (Y) :  "; : GetInput()
    C1=val(LII$) : if C1=0 then print : print "CALCULATION ABORTED!" : return ST_COMMAND
    LX=4 : print "ENTER INITIAL COORDINATES (X) :  "; : GetInput()
    A=val(LII$) : if A=0 then print : print "CALCULATION ABORTED!" : return ST_COMMAND
    print : LX=4 : print "ENTER FINAL COORDINATES   (Y) :  "; : GetInput()
    CALC_TARGET_Y=val(LII$) : if CALC_TARGET_Y=0 then print : print "CALCULATION ABORTED!" : return ST_COMMAND
    print : LX=4 : print "ENTER FINAL COORDINATES   (X) :  "; : GetInput()
    X=val(LII$) : if X=0 then print : print "CALCULATION ABORTED!" : return ST_COMMAND
    if C1=CALC_TARGET_Y and A=X then print : print "NO RESULTS POSSIBLE!" : return ST_COMMAND
    return ComputerCalcCompute()
end function


function ComputerBaseNav()
    H8=0 : A1=3
    if B3<>0 then print : print "FROM ENTERPRISE TO STARBASE" : CALC_TARGET_Y=B4 : X=B5 : C1=SECTOR_X : A=SECTOR_Y : ComputerCalcCompute() : return ST_COMMAND
    print : print "MR. SPOCK REPORTS, SENSORS SHOW NO"
    print "STARBASES IN THIS QUADRANT." : return ST_COMMAND
end function


function ComputerCalcCompute()
    X=X-A : A=C1-CALC_TARGET_Y
    if X>=0 then
      if A<0 then
        C1=7
        if abs(A)>=abs(X) then
          print : print " DIRECTION =";
          D2=C1+(abs(X)/abs(A))
        else
          print : print " DIRECTION =";
          D2=C1+(((abs(X)-abs(A))+abs(X))/abs(X))
        end if
      else
        if X>0 or A>0 then C1=1
        if A=0 then C1=5
        if abs(A)<=abs(X) then
          print : print " DIRECTION =";
          D2=C1+(abs(A)/abs(X))
        else
          print : print " DIRECTION =";
          D2=C1+(((abs(A)-abs(X))+abs(A))/abs(A))
        end if
      end if
    else
      if A>0 then
        C1=3
        if abs(A)>=abs(X) then
          print : print " DIRECTION =";
          D2=C1+(abs(X)/abs(A))
        else
          print : print " DIRECTION =";
          D2=C1+(((abs(X)-abs(A))+abs(X))/abs(X))
        end if
      else
        C1=5
        if abs(A)<=abs(X) then
          print : print " DIRECTION =";
          D2=C1+(abs(A)/abs(X))
        else
          print : print " DIRECTION =";
          D2=C1+(((abs(A)-abs(X))+abs(A))/abs(A))
        end if
      end if
    end if
    D2=D2*1000 : D2=D2+0.5 : D2=int(D2) : D2=D2/1000
    print D2
    print " DISTANCE  =";
    D2=sqr(X^2+A^2)
    if A1=3 or A1=2 then D2=D2/10
    D2=D2*1000 : D2=D2+0.5 : D2=int(D2) : D2=D2/1000
    print D2
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
    ' ** RETRY UNTIL CHECKSECTOR REPORTS THE SQUARE IS EMPTY (Z3<>0) **
    do
        A$=EMPTY_TOKEN$
        RANDOM_X=FNR(1) : RANDOM_Y=FNR(1) : TOKEN_X=RANDOM_X : TOKEN_Y=RANDOM_Y
        CheckSector()
    loop until Z3<>0
    return
end function


' INSERT IN STRING ARRAY FOR QUADRANT
function PlaceToken()
    S8 = int(TOKEN_Y-0.5) * 3 + int(TOKEN_X-0.5) * 24 + 1
    if len(A$)<>3 then print "TOKEN LENGTH ERROR: ";A$;" LEN=";len(A$) : stop
    if S8=1then QUADRANT_BUFFER$=A$+right$(QUADRANT_BUFFER$,189) : return
    if S8=190then QUADRANT_BUFFER$=left$(QUADRANT_BUFFER$,189)+A$ : return
    QUADRANT_BUFFER$=left$(QUADRANT_BUFFER$,S8-1)+A$+right$(QUADRANT_BUFFER$,190-S8) : return
end function


' printS DEVICE NAME -- SELECT CASE LOOKUP, NO GOTOS
function DeviceName()
    select case DEVICE_INDEX
    case 1
        G2$="WARP ENGINES"
    case 2
        G2$="SHORT RANGE SENSORS"
    case 3
        G2$="LONG RANGE SENSORS"
    case 4
        G2$="PHASER CONTROL"
    case 5
        G2$="PHOTON TUBES"
    case 6
        G2$="DAMAGE CONTROL"
    case 7
        G2$="SHIELD CONTROL"
    case 8
        G2$="LIBRARY-COMPUTER"
    end select
    return
end function


' STRING COMPARISON IN QUADRANT ARRAY
function CheckSector()
    TOKEN_X=int(TOKEN_X+.5) : 
    TOKEN_Y=int(TOKEN_Y+.5) : 
    S8=(TOKEN_Y-1)*3+(TOKEN_X-1)*24+1
    Z3=0
    if mid$(QUADRANT_BUFFER$,S8,3)<>A$ then return
    Z3=1 : return
end function


' QUADRANT NAME IN G2$ FROM Z4,Z5 (=Q1,Q2)
' CALL WITH G5=1 TO GET REGION NAME ONLY
function QuadrantName()
    ' ** REGIONS 1-4 OF EACH ROW USE THE FIRST NAME, 5-8 THE SECOND **
    select case Z4
    case 1
        G2$="ANTARES" : if Z5>4 then G2$="SIRIUS"
    case 2
        G2$="RIGEL" : if Z5>4 then G2$="DENEB"
    case 3
        G2$="PROCYON" : if Z5>4 then G2$="CAPELLA"
    case 4
        G2$="VEGA" : if Z5>4 then G2$="BETELGEUSE"
    case 5
        G2$="CANOPUS" : if Z5>4 then G2$="ALDEBARAN"
    case 6
        G2$="ALTAIR" : if Z5>4 then G2$="REGULUS"
    case 7
        G2$="SAGITTARIUS" : if Z5>4 then G2$="ARCTURUS"
    case 8
        G2$="POLLUX" : if Z5>4 then G2$="SPICA"
    end select
    if G5=1 then return
    select case Z5
    case 1, 5
        G2$=G2$+" I"
    case 2, 6
        G2$=G2$+" II"
    case 3, 7
        G2$=G2$+" III"
    case 4, 8
        G2$=G2$+" IV"
    end select
    return
end function


' ** GET INPUT **
' GET CHARACTERS UNTIL RETURN IS PRESSED
' THEN RETURN 
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
          print "{CLR}"
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
    LX=0 : print "{REVERSE ON}{LIGHTBLUE}":print CR$:print "{REVERSE OFF}{WHITE}"
    GetInput()
    CRSTART=0
    return
end function

' ** KEY TO SRS ICONS **
function ShowKey()
    print : print "{13}KEY TO SHORT RANGE SCANNER ICONS:" : print
    print " {CYAN}E{WHITE} = THE USS ENTERPRISE"
    print " {CYAN}B{WHITE} = FEDERATION STARBASE"
    print " {CYAN}*{WHITE} = STAR"
    print " {CYAN}K{WHITE} = KLINGON BATTLE CRUISER"
    return
end function

' ** LIST OF COMMANDS **
function ShowCommands()
    print : print "{13}USE THESE COMMANDS:" : print
    print " {CYAN}NAV{WHITE} - TO SET COURSE"
    print " {CYAN}SRS{WHITE} - FOR SHORT RANGE SCAN"
    print " {CYAN}LRS{WHITE} - FOR LONG RANGE SCAN"
    print " {CYAN}SLS{WHITE} - FOR SHORT & LONG RANGE SCAN"
    print " {CYAN}PHA{WHITE} - TO FIRE PHASERS"
    print " {CYAN}TOR{WHITE} - TO FIRE PHOTON TORPEDOES"
    print " {CYAN}SHE{WHITE} - TO RAISE OR LOWER SHIELDS"
    print " {CYAN}DAM{WHITE} - FOR DAMAGE CONTROL REPORTS"
    print " {CYAN}COM{WHITE} - TO CALL ON LIBRARY-COMPUTER"
    print " {CYAN}KEY{WHITE} - DISPLAY KEY TO SRS ICONS"
    print " {CYAN}HLP{WHITE} - THIS LIST OF COMMANDS"
    print " {CYAN}XXX{WHITE} - TO RESIGN YOUR COMMAND"
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

' ** COLOURS FOR IN-GAME **
function InitColours()
    ACOL$="{BLACK}" 
    BCOL$="{WHITE}" 
    CCOL$="{RED}" 
    DCOL$="{CYAN}" 
    ECOL$="{PINK}" 
    FCOL$="{GREEN}" 
    GCOL$="{BLUE}" 
    HCOL$="{YELLOW}" 
    ICOL$="{ORANGE}"
    return
end function


