print chr$(147)
print
print CHR$(5)
for y=0 to 24
print y
next y
locate 0,0
print "Hello, world!"
locate 20,22
print "20,22"
locate 1, 1
print "1,1"
locate 30, 1
print "30,1" 
locate 10, 10
print "10,10!"
locate 1, 10
print "1,10!"
locate 24,24
loop:
get k$
if k$ = "" then goto loop