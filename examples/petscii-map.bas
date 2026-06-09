OPTION PETSCII
R = RND(-TI)
dim side$(6)
side$(1)=chr$(242) ' T
side$(2)=chr$(238) ' \
side$(3)=chr$(125) ' |
side$(4)=chr$(123) ' +
side$(5)=chr$(18)+chr$(32)+chr$(146) 'room
side$(6)=chr$(18)+chr$(32)+chr$(146) 'room

for R=1 to 6
 ' print side$(R)
next R

print

dim roll(25)
for R=1 to 25
  roll(R)=INT(RND(0) * 6)+1
next R

for R=1 to 25 step 5
	print side$(roll(R));side$(roll(R+1));side$(roll(R+2));side$(roll(R+3));side$(roll(R+4))
next R

