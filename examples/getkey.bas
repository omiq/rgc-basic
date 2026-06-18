function WaitKey()
  print CY$ + RV$ + "        PRESS A KEY TO CONTINUE         " + RO$
  I$=""
  while I$ = ""
    get I$
    print I$
  wend 
  return I$
end function

  I$=""

WaitKey()
print "you pressed: " + I$

