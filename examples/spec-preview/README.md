# Spec-preview examples

These programs demonstrate commands from the graphics respec
(`docs/tilemap-sheet-plan.md`) that are **not yet implemented**. They
exist to:

1. Serve as test targets for the implementation PR.
2. Show the intended API shape so users can review before code lands.
3. Give documentation authors concrete runnable code to embed.

**Expect these to fail with "unknown command" errors on rgc-basic
builds prior to v1.9.** Once the new tokens ship, move them up into
`examples/` and delete the sibling concat-name versions if duplicated.

## Commands previewed here

| File | Demonstrates |
|---|---|
| `gfx_tilemap_demo.bas` | `TILEMAP DRAW` — batched grid stamp from 1-D array |
| `gfx_sheet_info_demo.bas` | `SHEET COLS/ROWS/WIDTH/HEIGHT`, `SPRITE FRAMES`, `TILE COUNT` |
| `gfx_screen_offset_demo.bas` | `SCREEN OFFSET` — viewport scroll on oversized surface |
| `gfx_screen_zone_demo.bas` | `SCREEN ZONE` + `SCREEN SCROLL` — parallax bands |

All four use the two-word canonical spellings. Concat aliases
(`DRAWTILEMAP`, etc.) will be accepted too once the feature ships.
