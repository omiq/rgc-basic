1 REM Browser canvas demo: PETSCII + PNG overlay (same LOADSPRITE/DRAWSPRITE as basic-gfx).
2 REM Native: ./basic-gfx examples/gfx_canvas_demo.bas  (needs gfx_canvas_demo.png beside this file)
3 REM WASM: put gfx_canvas_demo.png on MEMFS root (e.g. canvas Upload, or fetch in tests).
10 PRINT CHR$(14)
20 PRINT "{CLR}{WHT}CANVAS DEMO{CYN} - red 8x8 PNG at pixel (100,100)"
30 PRINT "{GREY2}SPRITE z=50 draws above text."
40 LOADSPRITE 0,"gfx_canvas_demo.png"
50 DRAWSPRITE 0,100,100,50
60 SLEEP 120
70 END
