' RNDINT(N) -- integer random 1..N, no floating point.
' Unlike RND (which returns 0..1 and pulls in fixed-point/float on retro
' targets), RNDINT stays pure integer, so an RNDINT-only program transpiles
' to C with no real-number runtime at all. Use it for dice, coords, picks.

' Seed once: RNDINT(negative) reseeds from the clock, same as RND(-1) would,
' but stays integer so this whole program needs no real-number runtime.
X = RNDINT(-1)

print "FIVE DICE ROLLS (1-6):"
for I = 1 to 5
  print " "; RNDINT(6);
next I
print

print "RANDOM SECTOR (1-8, 1-8):"
print " X="; RNDINT(8); " Y="; RNDINT(8)

' Probability: ~4% chance (1 in 25).
HITS = 0
for I = 1 to 100
  if RNDINT(25) = 1 then HITS = HITS + 1
next I
print "RARE EVENT FIRED "; HITS; " / 100 TIMES"

' Edge cases: N<1 yields 0, N=1 always 1.
print "RNDINT(0)="; RNDINT(0); "  RNDINT(1)="; RNDINT(1)
end
