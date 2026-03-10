print "press a key"


LOOP:
get i$
if i$ = "" then goto LOOP
print "you pressed: " + i$


print "what is your name?"
input name$
print "hello, " + name$
