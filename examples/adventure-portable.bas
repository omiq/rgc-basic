' MURDER HOUSE - a text adventure by Chris Garrett, 2026, retrogamecoders.com
'
' Structured port of examples/adventure.bas (label-based GOSUB/GOTO) into the
' FUNCTION/DO-LOOP subset the RGC-BASIC->C transpiler accepts. Behaviour is
' preserved 1:1; the GOTO DONEx forward-skips became IF/ELSE, the main loop and
' key-waits became DO/LOOP, and each GOSUB target became a function. One latent
' typo fixed: original printed OBJ$(F-1) (undefined) where OB$(F-1) was meant.
'
' The screens use PETSCII control codes (CHR$ 147 clear, 18/146 reverse, colour
' codes), so the interpreter needs PET charset mode or those bytes corrupt a
' plain terminal (and wedge GET input). Leading # so the C transpiler strips it
' as a directive; the original bare `OPTION CHARSET` parsed as a statement and
' would not transpile.
#OPTION CHARSET pet-lower
' Room descriptions run ~170 chars, so pin the string cap above the 6502
' default (40) or the C target truncates them. Pinned for all targets.
#OPTION maxstr 200

' ===== SETUP (was INIT) — arrays are global, so DIM at top level =====
OC = 2                                   ' OBJECT COUNT
dim OB$(2)
OB$(0) = "MATCHES" : M = 6               ' 6 MATCHES IN INVENTORY TO START
OB$(1) = "KEY"

dim OD$(2)
OD$(0) = "A SMALL BOOK OF PROMOTIONAL MATCHES ADVERTISING PATTY'S BAR AND GRILL, NORTH LAKES"
OD$(1) = "A LARGE AND HEAVY KEY MADE OUT OF BRASS."

RC = 6                                   ' ROOM COUNT
dim LO$(6)
LO$(0) = "INVENTORY"
LO$(1) = "DANK BASEMENT"
LO$(2) = "FURNACE ROOM"
LO$(3) = "SERVICE HATCH"
LO$(4) = "A STORE ROOM?"
LO$(5) = "OUTSIDE THE HOUSE"
LO$(6) = "CRAMPED STAIRWELL"

dim RD$(6)
RD$(0) = ""
RD$(1) = "A CHILLINGLY DAMP, BARE-BRICKED ROOM    {13}WITH POURED CEMENT FLOOR AND TIMBER    {13}BEAMED CEILING. WINDOW FRAMES ARE       {13}BOARDED ALONG ONE WALL."
RD$(2) = "THIS ROOM IS OBVIOUSLY A LATER ADDITION,{13}THROWN TOGETHER WITH DRYWALL, AND JUST {13}LARGE ENOUGH TO SECTION OFF THE FURNACE {13}FROM THE MAIN BASEMENT. YOU SMELL GAS."
RD$(3) = "UP ABOVE THE FURNACE, THIS TINY SPACE   {13}MUST HAVE BEEN BUILT TO ALLOW ACCESS TO{13}HVAC DUCTING. THE SMELL OF GAS IS STRONG {13}HERE, AND THE FURNACE HUMS OMINOUSLY."
RD$(4) = "THE DARK AND DUSTY ROOM IS EMPTY, WITH  {13}A SINGLE LIGHT BULB HANGING FROM THE   {13}CEILING. THERE IS AN OLD WOODEN DOOR ON {13}THE FAR WALL COVERED IN COBWEBS."
RD$(5) = "OUTSIDE THE HOUSE, YOU CAN SEE THE FRONT{13}DOOR AND A PATH LEADING TO THE STREET."
RD$(6) = "A TINY, TWISTY STAIRWELL THAT WAS       {13}PREVIOUSLY OBSCURED BY THE DARK."

dim OL(2)
OL(0) = 0                                ' MATCHES START IN INVENTORY
OL(1) = 6                                ' KEY IS IN THE STAIRWELL

dim EN$(6)
EN$(0) = "NORTH"
EN$(1) = "EAST"
EN$(2) = "SOUTH"
EN$(3) = "WEST"
EN$(4) = "UP"
EN$(5) = "DOWN"

dim EX$(20)                              ' ROOM EXITS: N E S W U D, 2 chars each
EX$(1) = "000002000000"
EX$(2) = "010004000300"
EX$(3) = "000000000002"
EX$(4) = "020000000000"
EX$(5) = "040000000000"
EX$(6) = "000000020000"

PL = 1                                   ' PLAYER LOCATION
PP = 1                                   ' PLAYER PREVIOUS LOCATION

' ===== WELCOME SCREEN (was WELCOMESCREEN / WAITSTARTKEY) =====
NewScreen()
print "             {REVERSE ON}{PINK}MURDER HOUSE{WHITE}{REVERSE OFF}"
print "         A TEXT ADVENTURE GAME"
print "           BY CHRIS GARRETT"
print "                 2026"
print ""
print "          {LIGHTBLUE}RETROGAMECODERS.COM{WHITE}"
print ""
print " {LIGHTGREEN}PRESS H FOR HELP OR OTHER KEY TO START{WHITE}"
do
  get I$
  I$ = UCASE$(I$)
  if I$ = "H" then Help()
loop while I$ = ""
I$ = ""

' ===== MAIN LOOP (was DISPLAYROOM / GETCOMMAND) =====
do
  ' SHOW ROOM DETAILS
  ClrScr()
  if PL = 0 then PL = PP                  ' LOCATION 0 IS INVENTORY, NOT A ROOM
  PP = PL
  print RV$ + LO$(PL) + RO$
  print ""
  if PL = 5 then YouWin()
  print "OBJECTS VISIBLE:" + LB$
  for I = 0 to OC - 1
    if OL(I) = PL then print ". "; OB$(I)
  next I
  print ""
  print WT$ + "EXITS AVAILABLE:" + LB$
  if MID$(EX$(PL), 1, 2) <> "00" then print ". NORTH"
  if MID$(EX$(PL), 3, 2) <> "00" then print ". EAST"
  if MID$(EX$(PL), 5, 2) <> "00" then print ". SOUTH"
  if MID$(EX$(PL), 7, 2) <> "00" then print ". WEST"
  if MID$(EX$(PL), 9, 2) <> "00" then print ". UP"
  if MID$(EX$(PL), 11, 2) <> "00" then print ". DOWN"

  ' READ A COMMAND
  I$ = ""
  print ""
  print YL$ + "WHAT NOW?" + LB$
  GetLine()
  I$ = UCASE$(I$)
  if LEFT$(I$, 3) = "GO " then FullMove()
  if I$ = "N" then AbrMove()
  if I$ = "E" then AbrMove()
  if I$ = "S" then AbrMove()
  if I$ = "W" then AbrMove()
  if I$ = "U" then AbrMove()
  if I$ = "D" then AbrMove()
  if LEFT$(I$, 1) = "I" then Inventory()
  if LEFT$(I$, 4) = "GET " then GetObject()
  if LEFT$(I$, 5) = "TAKE " then TakeObject()
  if LEFT$(I$, 1) = "H" then Help()
  if LEFT$(I$, 4) = "QUIT" then GameOver()
  if LEFT$(I$, 4) = "EXIT" then GameOver()
  if LEFT$(I$, 5) = "DROP " then DropObject()
  if LEFT$(I$, 8) = "EXAMINE " then ExamineObject()
  if LEFT$(I$, 4) = "LOOK" or LEFT$(I$, 1) = "L" then
    print "" : print RD$(PL) : print "" : WaitKey()
  end if
  if LEFT$(I$, 1) = "Q" then GameOver()
  if LEFT$(I$, 4) = "USE " then UseObject()
loop


' ===== MOVEMENT =====
function FullMove()
  ' FULLY WRITTEN OUT MOVE (E.G. GO SOUTH OR GO S)
  D$ = MID$(I$, 4, 1)
  Moves()
  return
end function

function AbrMove()
  ' ABBREVIATED MOVE (E.G. N)
  D$ = I$
  Moves()
  return
end function

function Moves()
  ' GO TO THE NEW PLAYER LOCATION (PL)
  if D$ = "N" then PL = VAL(MID$(EX$(PL), 1, 2))
  if D$ = "E" then PL = VAL(MID$(EX$(PL), 3, 2))
  if D$ = "S" then PL = VAL(MID$(EX$(PL), 5, 2))
  if D$ = "W" then PL = VAL(MID$(EX$(PL), 7, 2))
  if D$ = "U" then PL = VAL(MID$(EX$(PL), 9, 2))
  if D$ = "D" then PL = VAL(MID$(EX$(PL), 11, 2))
  return
end function


' ===== INVENTORY (fell through into WAITKEY) =====
function Inventory()
  print ""
  print "OBJECTS IN YOUR POSSESSION:"
  for I = 0 to OC - 1
    if OL(I) = 0 then print ". "; OB$(I)
  next I
  print ""
  WaitKey()
  return
end function

function WaitKey()
  print CY$ + RV$ + "        PRESS A KEY TO CONTINUE         " + RO$
  do
    get I$
  loop while I$ = ""
  return
end function


' ===== GET / TAKE (both converge on the shared object-id finder) =====
function GetObject()
  F = -1 : R$ = ""
  R$ = MID$(I$, 5)
  GetObjId()
  return
end function

function TakeObject()
  F = -1 : R$ = ""
  R$ = MID$(I$, 6)
  GetObjId()
  return
end function

function GetObjId()
  for I = 1 to OC
    if OB$(I - 1) = R$ then F = I
  next I
  print ""
  if F = -1 then
    print "CAN'T SEE THAT HERE, CHECK SPELLING AND BE SPECIFIC?"
  else
    if OL(F - 1) = PL then
      OL(F - 1) = 0                       ' OBJECT LOCATION 0 = INVENTORY
      print ""
      print "GOT THE "; OB$(F - 1)
    else
      if OL(F - 1) = 0 then
        print "YOU ALREADY HAVE THAT"
      else
        print "I CAN'T SEE THAT AROUND HERE"
      end if
    end if
  end if
  print ""
  WaitKey()
  return
end function


function DropObject()
  F = -1 : R$ = ""
  R$ = MID$(I$, 6)
  for I = 1 to OC
    if OB$(I - 1) = R$ then F = I
  next I
  print ""
  if F = -1 then
    print "CAN'T SEEM TO FIND THAT, CHECK SPELLING AND BE SPECIFIC?"
  else
    if OL(F - 1) = 0 then
      print "OK, DROPPED!"
      OL(F - 1) = PL
    else
      print "NO CAN DO, ARE YOU SURE YOU HAVE THAT?"
    end if
  end if
  WaitKey()
  return
end function

function ExamineObject()
  F = -1 : R$ = ""
  R$ = MID$(I$, 9)
  for I = 1 to OC
    if OB$(I - 1) = R$ then F = I
  next I
  print ""
  if F = -1 then
    print "CAN'T SEEM TO FIND THAT, CHECK SPELLING AND BE SPECIFIC?"
  else
    if OL(F - 1) = 0 then
      print OD$(F - 1)
    else
      print "NO CAN DO, ARE YOU SURE YOU HAVE THAT?"
    end if
  end if
  WaitKey()
  return
end function

function UseObject()
  F = -1 : R$ = ""
  R$ = MID$(I$, 5)
  for I = 1 to OC
    if OB$(I - 1) = R$ then F = I
  next I
  print ""
  if F = -1 then
    print "CAN'T SEEM TO FIND THAT, CHECK SPELLING AND BE SPECIFIC?"
  else
    if OL(F - 1) = 0 then
      ObjectActions()
    else
      print "NO CAN DO, ARE YOU SURE YOU HAVE THAT?"
    end if
  end if
  WaitKey()
  return
end function

function ObjectActions()
  ' MATCHES (F=1) IN THE SERVICE HATCH (PL=3) = BOOM
  if F = 1 and PL = 3 then
    print "BOOM! THE FURNACE EXPLODES, FILLING THE ROOM WITH FIRE AND SMOKE!"
    WaitKey()
    GameOver()
  end if
  ' MATCHES IN THE FURNACE ROOM (PL=2) = LIGHT IT, OPENS A NEW EXIT
  if F = 1 and PL = 2 then
    print "SUDDENLY THE FURNACE ROARS TO LIFE, FILLING THE ROOM WITH HEAT AND LIGHT!"
    EX$(2) = "010604000300"
    M = M - 1
    if M <= 0 then
      print "YOU ARE OUT OF MATCHES"
      OL(F - 1) = -1
      return
    end if
  end if
  if F = 1 and PL <> 2 then
    print "YOU STRIKE A MATCH AND LIGHT IT, ILLUMINATING THE ROOM FOR A MOMENT."
    M = M - 1
    if M <= 0 then
      print "YOU ARE OUT OF MATCHES"
      OL(F - 1) = -1
    end if
  end if
  if F = 2 and PL = 4 then
    print "CLICK! THE DOOR HAS UNLOCKED!"
    EX$(4) = "020005000000"
    OL(F - 1) = -1
  end if
  if F = 2 and PL <> 4 then
    print "YOU TRY TO USE THE KEY, BUT IT DOESN'T FIT ANY LOCKS HERE."
  end if
  return
end function


' ===== SCREENS =====
function Help()
  NewScreen()
  print "YOU HAVE WOKEN UP IN A DARK AND DAMP    {13}BASEMENT, WITH NO MEMORY OF HOW YOU GOT HERE."
  print ""
  print "YOUR HEAD IS POUNDING AND YOU FEEL      {13}DISORIENTED. YOU NEED TO FIND A WAY OUT."
  print ""
  print "ENTER THE COMMAND YOU WANT TO USE:"
  print "{13}  NORTH, SOUTH, EAST, WEST, UP, DOWN"
  print "  (N, S, E, W, U, D)"
  print ""
  print "  GET <OBJECT>, TAKE <OBJECT>"
  print "  DROP <OBJECT>"
  print "  EXAMINE <OBJECT>"
  print "  L, LOOK"
  print "  I, INVENTORY"
  print "  H, HELP"
  print "  Q, QUIT, EXIT"
  print ""
  print ""
  WaitKey()
  return
end function

function YouWin()
  NewScreen()
  print "CONGRATULATIONS! YOU HAVE ESCAPED{13}"
  print "          {REVERSE ON}{PINK}THE MURDER HOUSE!{WHITE}{REVERSE OFF}"
  print ""
  print "NOW YOU KNOW WHERE THE EXIT IS FEEL"
  print "FREE TO GO BACK IN AND EXPLORE, JUST"
  print "DO NOT HANG AROUND TOO LONG!"
  print ""
  WaitKey()
  ClrScr()
  return
end function

' NewScreen sets the colour codes then falls through to ClrScr (as in the
' original): the first welcome screen is what primes LB$/WT$/YL$ etc.
function NewScreen()
  LB$ = CHR$(154) : WT$ = CHR$(5)         ' LIGHT BLUE, WHITE
  YL$ = CHR$(158) : CY$ = CHR$(159)       ' YELLOW, CYAN
  RV$ = CHR$(18) : RO$ = CHR$(146)        ' REVERSE ON, REVERSE OFF
  BL$ = CHR$(13) + CHR$(187) + CHR$(32)
  ClrScr()
  return
end function

function ClrScr()
  ' WHITE, CLEAR SCREEN, CURSOR HOME (trailing ; suppresses the newline)
  print WT$ : print CHR$(147) : print CHR$(19);
  return
end function

' Line reader into the global I$ (the transpiler has no INPUT statement, and a
' GET-based reader is portable to the C target). Enter ends; CHR$(20)/CHR$(8)
' backspace; other chars echo.
function GetLine()
  I$ = ""
  do
    get Y$
    if Y$ <> "" then
      if ASC(Y$) = 13 then
        print ""
        return
      end if
      if ASC(Y$) = 20 or ASC(Y$) = 8 then
        if len(I$) > 0 then
          I$ = LEFT$(I$, len(I$) - 1)
          print Y$;
        end if
      else
        I$ = I$ + Y$
        print Y$;
      end if
    end if
  loop
end function

function GameOver()
  ClrScr()
  print "GOODBYE!"
  end
end function
