10 REM map_adventure_room: build a room "struct" via MAP, then save it.
20 REM Mirrors §Use case 1 of docs/map-type-proposal.md — dicts as
30 REM struct-substitute in the dynamic-typing world.
40 REM
50 REM Builds: a forest-clearing room with exits, NPC, and a derived
60 REM danger value that scales with the player's current health.
70 REM
80 ROOM = MAPNEW()
90 MAPSET ROOM, "name", "Forest clearing"
100 MAPSET ROOM, "desc", "A sunlit glade ringed by pines. A wolf paces nearby."
110 REM Exits as a sub-object (room id keyed by direction).
120 MAPSET ROOM, "exits.north", 5
130 MAPSET ROOM, "exits.east", 7
140 MAPSET ROOM, "exits.south", 3
150 REM Items as an array (autovivified by MAPPUSH).
160 MAPPUSH ROOM, "items", "rope"
170 MAPPUSH ROOM, "items", "lantern"
180 MAPPUSH ROOM, "items", "stale_bread"
190 REM Nested NPC sub-object.
200 MAPSET ROOM, "npc.kind", "wolf"
210 MAPSET ROOM, "npc.health", 18
220 MAPSET ROOM, "npc.hostile", 1
230 REM Computed danger value derived from the player's health.
240 PLAYER_HEALTH = 80
250 MAPSET ROOM, "danger", PLAYER_HEALTH / 4
260 PRINT "ROOM as JSON:"
270 PRINT JSON$(ROOM)
280 PRINT
290 PRINT "name      : "; MAPGET$(ROOM, "name")
300 PRINT "exits.n   : "; MAPGETN(ROOM, "exits.north")
310 PRINT "item[0]   : "; MAPGET$(ROOM, "items[0]")
320 PRINT "npc.kind  : "; MAPGET$(ROOM, "npc.kind")
330 PRINT "danger    : "; MAPGETN(ROOM, "danger")
340 PRINT
350 REM Iterate exits via MAPLEN/MAPKEY$ on a nested object.
360 PRINT "All exits (insertion order):"
370 N = MAPLEN(ROOM, "exits")
380 FOR I = 0 TO N - 1
390 K$ = MAPKEY$(ROOM, "exits", I)
400 PRINT "  "; K$; " -> "; MAPGETN(ROOM, "exits." + K$)
410 NEXT
420 PRINT
430 REM Persist via the existing OPEN/PRINT# IO once you have the JSON.
440 REM    OPEN 1,1,1,"room.json"
450 REM    PRINT#1, JSON$(ROOM)
460 REM    CLOSE 1
470 MAPFREE ROOM
