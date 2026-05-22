10 REM dict_adventure_room: build a room "struct" via MAP, then save it.
20 REM Mirrors §Use case 1 of docs/map-type-proposal.md — dicts as
30 REM struct-substitute in the dynamic-typing world.
40 REM
50 REM Builds: a forest-clearing room with exits, NPC, and a derived
60 REM danger value that scales with the player's current health.
70 REM
80 ROOM = DICTNEW()
90 DICTSET ROOM, "name", "Forest clearing"
100 DICTSET ROOM, "desc", "A sunlit glade ringed by pines. A wolf paces nearby."
110 REM Exits as a sub-object (room id keyed by direction).
120 DICTSET ROOM, "exits.north", 5
130 DICTSET ROOM, "exits.east", 7
140 DICTSET ROOM, "exits.south", 3
150 REM Items as an array (autovivified by DICTPUSH).
160 DICTPUSH ROOM, "items", "rope"
170 DICTPUSH ROOM, "items", "lantern"
180 DICTPUSH ROOM, "items", "stale_bread"
190 REM Nested NPC sub-object.
200 DICTSET ROOM, "npc.kind", "wolf"
210 DICTSET ROOM, "npc.health", 18
220 DICTSET ROOM, "npc.hostile", 1
230 REM Computed danger value derived from the player's health.
240 PLAYER_HEALTH = 80
250 DICTSET ROOM, "danger", PLAYER_HEALTH / 4
260 PRINT "ROOM as JSON:"
270 PRINT JSON$(ROOM)
280 PRINT
290 PRINT "name      : "; DICTGET$(ROOM, "name")
300 PRINT "exits.n   : "; DICTGETN(ROOM, "exits.north")
310 PRINT "item[0]   : "; DICTGET$(ROOM, "items[0]")
320 PRINT "npc.kind  : "; DICTGET$(ROOM, "npc.kind")
330 PRINT "danger    : "; DICTGETN(ROOM, "danger")
340 PRINT
350 REM Iterate exits via DICTLEN/DICTKEY$ on a nested object.
360 PRINT "All exits (insertion order):"
370 N = DICTLEN(ROOM, "exits")
380 FOR I = 0 TO N - 1
390 K$ = DICTKEY$(ROOM, "exits", I)
400 PRINT "  "; K$; " -> "; DICTGETN(ROOM, "exits." + K$)
410 NEXT
420 PRINT
430 REM Persist via the existing OPEN/PRINT# IO once you have the JSON.
440 REM    OPEN 1,1,1,"room.json"
450 REM    PRINT#1, JSON$(ROOM)
460 REM    CLOSE 1
470 DICTFREE ROOM
