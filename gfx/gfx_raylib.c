/* gfx/gfx_raylib.c – Raylib front-end for CBM-BASIC GFX.
 *
 * Two compile modes:
 *   1. Standalone demo  (no GFX_VIDEO): builds as gfx-demo with a
 *      hardcoded test pattern.
 *   2. Integrated build  (GFX_VIDEO defined): builds as basic-gfx,
 *      runs a .bas program in a worker thread while the main thread
 *      drives the raylib render loop.  POKE/PEEK in the BASIC program
 *      write/read the shared GfxVideoState rendered each frame.
 */

#include "raylib.h"
#include "gfx_video.h"
#include <string.h>
#include <stdio.h>

#ifdef GFX_VIDEO
#include <pthread.h>
#include "../basic_api.h"
#endif

/* ── Screen geometry ──────────────────────────────────────────────── */

#define SCREEN_COLS  40
#define SCREEN_ROWS  25
#define CELL_W        8
#define CELL_H        8
#define NATIVE_W     (SCREEN_COLS * CELL_W)   /* 320 */
#define NATIVE_H     (SCREEN_ROWS * CELL_H)   /* 200 */
#define SCALE         3
#define WIN_W        (NATIVE_W * SCALE)        /* 960 */
#define WIN_H        (NATIVE_H * SCALE)        /* 600 */

/* ── C64 palette (approximate RGB values) ─────────────────────────── */

static const Color c64_palette[16] = {
    { 0x00, 0x00, 0x00, 0xFF },   /*  0  Black       */
    { 0xFF, 0xFF, 0xFF, 0xFF },   /*  1  White       */
    { 0x88, 0x00, 0x00, 0xFF },   /*  2  Red         */
    { 0xAA, 0xFF, 0xEE, 0xFF },   /*  3  Cyan        */
    { 0xCC, 0x44, 0xCC, 0xFF },   /*  4  Purple      */
    { 0x00, 0xCC, 0x55, 0xFF },   /*  5  Green       */
    { 0x00, 0x00, 0xAA, 0xFF },   /*  6  Blue        */
    { 0xEE, 0xEE, 0x77, 0xFF },   /*  7  Yellow      */
    { 0xDD, 0x88, 0x55, 0xFF },   /*  8  Orange      */
    { 0x66, 0x44, 0x00, 0xFF },   /*  9  Brown       */
    { 0xFF, 0x77, 0x77, 0xFF },   /* 10  Light Red   */
    { 0x33, 0x33, 0x33, 0xFF },   /* 11  Dark Gray   */
    { 0x77, 0x77, 0x77, 0xFF },   /* 12  Medium Gray */
    { 0xAA, 0xFF, 0x66, 0xFF },   /* 13  Light Green */
    { 0x00, 0x88, 0xFF, 0xFF },   /* 14  Light Blue  */
    { 0xBB, 0xBB, 0xBB, 0xFF },   /* 15  Light Gray  */
};

static const uint8_t BG_COLOR = 6;   /* default C64 blue background */

/* ── Built-in 8×8 font (C64 uppercase, screen codes 0–63) ────────── */

static const uint8_t default_font[64][8] = {
    /* 0 @  */ {0x3C,0x66,0x6E,0x6E,0x60,0x62,0x3C,0x00},
    /* 1 A  */ {0x18,0x3C,0x66,0x7E,0x66,0x66,0x66,0x00},
    /* 2 B  */ {0x7C,0x66,0x66,0x7C,0x66,0x66,0x7C,0x00},
    /* 3 C  */ {0x3C,0x66,0x60,0x60,0x60,0x66,0x3C,0x00},
    /* 4 D  */ {0x78,0x6C,0x66,0x66,0x66,0x6C,0x78,0x00},
    /* 5 E  */ {0x7E,0x60,0x60,0x78,0x60,0x60,0x7E,0x00},
    /* 6 F  */ {0x7E,0x60,0x60,0x78,0x60,0x60,0x60,0x00},
    /* 7 G  */ {0x3C,0x66,0x60,0x6E,0x66,0x66,0x3C,0x00},
    /* 8 H  */ {0x66,0x66,0x66,0x7E,0x66,0x66,0x66,0x00},
    /* 9 I  */ {0x3C,0x18,0x18,0x18,0x18,0x18,0x3C,0x00},
    /*10 J  */ {0x1E,0x0C,0x0C,0x0C,0x0C,0x6C,0x38,0x00},
    /*11 K  */ {0x66,0x6C,0x78,0x70,0x78,0x6C,0x66,0x00},
    /*12 L  */ {0x60,0x60,0x60,0x60,0x60,0x60,0x7E,0x00},
    /*13 M  */ {0x63,0x77,0x7F,0x6B,0x63,0x63,0x63,0x00},
    /*14 N  */ {0x66,0x76,0x7E,0x7E,0x6E,0x66,0x66,0x00},
    /*15 O  */ {0x3C,0x66,0x66,0x66,0x66,0x66,0x3C,0x00},
    /*16 P  */ {0x7C,0x66,0x66,0x7C,0x60,0x60,0x60,0x00},
    /*17 Q  */ {0x3C,0x66,0x66,0x66,0x66,0x3C,0x0E,0x00},
    /*18 R  */ {0x7C,0x66,0x66,0x7C,0x78,0x6C,0x66,0x00},
    /*19 S  */ {0x3C,0x66,0x60,0x3C,0x06,0x66,0x3C,0x00},
    /*20 T  */ {0x7E,0x18,0x18,0x18,0x18,0x18,0x18,0x00},
    /*21 U  */ {0x66,0x66,0x66,0x66,0x66,0x66,0x3C,0x00},
    /*22 V  */ {0x66,0x66,0x66,0x66,0x66,0x3C,0x18,0x00},
    /*23 W  */ {0x63,0x63,0x63,0x6B,0x7F,0x77,0x63,0x00},
    /*24 X  */ {0x66,0x66,0x3C,0x18,0x3C,0x66,0x66,0x00},
    /*25 Y  */ {0x66,0x66,0x66,0x3C,0x18,0x18,0x18,0x00},
    /*26 Z  */ {0x7E,0x06,0x0C,0x18,0x30,0x60,0x7E,0x00},
    /*27 [  */ {0x3C,0x30,0x30,0x30,0x30,0x30,0x3C,0x00},
    /*28 £  */ {0x0C,0x12,0x30,0x7C,0x30,0x62,0xFC,0x00},
    /*29 ]  */ {0x3C,0x0C,0x0C,0x0C,0x0C,0x0C,0x3C,0x00},
    /*30 ↑  */ {0x18,0x3C,0x7E,0x18,0x18,0x18,0x18,0x00},
    /*31 ←  */ {0x00,0x18,0x30,0x7E,0x30,0x18,0x00,0x00},
    /*32    */ {0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00},
    /*33 !  */ {0x18,0x18,0x18,0x18,0x00,0x00,0x18,0x00},
    /*34 "  */ {0x66,0x66,0x66,0x00,0x00,0x00,0x00,0x00},
    /*35 #  */ {0x66,0x66,0xFF,0x66,0xFF,0x66,0x66,0x00},
    /*36 $  */ {0x18,0x3E,0x60,0x3C,0x06,0x7C,0x18,0x00},
    /*37 %  */ {0x62,0x66,0x0C,0x18,0x30,0x66,0x46,0x00},
    /*38 &  */ {0x3C,0x66,0x3C,0x38,0x67,0x66,0x3F,0x00},
    /*39 '  */ {0x06,0x0C,0x18,0x00,0x00,0x00,0x00,0x00},
    /*40 (  */ {0x0C,0x18,0x30,0x30,0x30,0x18,0x0C,0x00},
    /*41 )  */ {0x30,0x18,0x0C,0x0C,0x0C,0x18,0x30,0x00},
    /*42 *  */ {0x00,0x66,0x3C,0xFF,0x3C,0x66,0x00,0x00},
    /*43 +  */ {0x00,0x18,0x18,0x7E,0x18,0x18,0x00,0x00},
    /*44 ,  */ {0x00,0x00,0x00,0x00,0x00,0x18,0x18,0x30},
    /*45 -  */ {0x00,0x00,0x00,0x7E,0x00,0x00,0x00,0x00},
    /*46 .  */ {0x00,0x00,0x00,0x00,0x00,0x18,0x18,0x00},
    /*47 /  */ {0x00,0x03,0x06,0x0C,0x18,0x30,0x60,0x00},
    /*48 0  */ {0x3C,0x66,0x6E,0x76,0x66,0x66,0x3C,0x00},
    /*49 1  */ {0x18,0x18,0x38,0x18,0x18,0x18,0x7E,0x00},
    /*50 2  */ {0x3C,0x66,0x06,0x0C,0x30,0x60,0x7E,0x00},
    /*51 3  */ {0x3C,0x66,0x06,0x1C,0x06,0x66,0x3C,0x00},
    /*52 4  */ {0x06,0x0E,0x1E,0x66,0x7F,0x06,0x06,0x00},
    /*53 5  */ {0x7E,0x60,0x7C,0x06,0x06,0x66,0x3C,0x00},
    /*54 6  */ {0x3C,0x66,0x60,0x7C,0x66,0x66,0x3C,0x00},
    /*55 7  */ {0x7E,0x66,0x0C,0x18,0x18,0x18,0x18,0x00},
    /*56 8  */ {0x3C,0x66,0x66,0x3C,0x66,0x66,0x3C,0x00},
    /*57 9  */ {0x3C,0x66,0x66,0x3E,0x06,0x66,0x3C,0x00},
    /*58 :  */ {0x00,0x00,0x18,0x00,0x00,0x18,0x00,0x00},
    /*59 ;  */ {0x00,0x00,0x18,0x00,0x00,0x18,0x18,0x30},
    /*60 <  */ {0x0E,0x18,0x30,0x60,0x30,0x18,0x0E,0x00},
    /*61 =  */ {0x00,0x00,0x7E,0x00,0x7E,0x00,0x00,0x00},
    /*62 >  */ {0x70,0x18,0x0C,0x06,0x0C,0x18,0x70,0x00},
    /*63 ?  */ {0x3C,0x66,0x06,0x0C,0x18,0x00,0x18,0x00},
};

static void load_default_charrom(GfxVideoState *s)
{
    memcpy(s->chars, default_font, sizeof(default_font));
}

/* ── Renderer (shared by both modes) ──────────────────────────────── */

static void render_text_screen(const GfxVideoState *s,
                               RenderTexture2D target)
{
    int row, col, y, x;

    BeginTextureMode(target);
    ClearBackground(c64_palette[BG_COLOR]);

    for (row = 0; row < SCREEN_ROWS; row++) {
        for (col = 0; col < SCREEN_COLS; col++) {
            int idx = row * SCREEN_COLS + col;
            uint8_t sc = s->screen[idx];
            uint8_t ci = s->color[idx] & 0x0F;
            int reversed = (sc >= 128);
            uint8_t char_idx;
            const uint8_t *glyph;
            Color fg = c64_palette[ci];
            Color bg = c64_palette[BG_COLOR];

            char_idx = sc & 0x7F;
            if (char_idx >= 64) char_idx &= 0x3F;
            glyph = &s->chars[char_idx * 8];

            for (y = 0; y < CELL_H; y++) {
                uint8_t bits = glyph[y];
                for (x = 0; x < CELL_W; x++) {
                    int px = col * CELL_W + x;
                    int py = row * CELL_H + y;
                    if (reversed) {
                        DrawPixel(px, py,
                                  (bits & (0x80 >> x)) ? bg : fg);
                    } else {
                        if (bits & (0x80 >> x))
                            DrawPixel(px, py, fg);
                    }
                }
            }
        }
    }
    EndTextureMode();
}

/* ══════════════════════════════════════════════════════════════════════
 *  MODE 1: basic-gfx  (GFX_VIDEO defined)
 *  Runs a .bas program in a worker thread; main thread renders.
 * ══════════════════════════════════════════════════════════════════════ */
#ifdef GFX_VIDEO

typedef struct {
    const char *prog_path;
    int nargs;
    char **args;
} InterpreterArgs;

static void *interpreter_thread(void *arg)
{
    InterpreterArgs *ia = (InterpreterArgs *)arg;
    basic_load(ia->prog_path);
    basic_run(ia->prog_path, ia->nargs, ia->args);
    return NULL;
}

int main(int argc, char **argv)
{
    GfxVideoState vs;
    RenderTexture2D target;
    pthread_t tid;
    InterpreterArgs ia;
    int prog_idx;
    const char *prog_path;

    prog_idx = basic_parse_args(argc, argv);
    if (prog_idx < 0) {
        fprintf(stderr,
                "Usage: %s [-petscii] [-palette ansi|c64] <program.bas> [args...]\n",
                argv[0]);
        return 1;
    }
    prog_path = argv[prog_idx];

    gfx_video_init(&vs);
    load_default_charrom(&vs);
    memset(vs.screen, 32, GFX_TEXT_SIZE);
    memset(vs.color, 14, GFX_COLOR_SIZE);

    basic_set_video(&vs);

    ia.prog_path = prog_path;
    ia.nargs     = argc - (prog_idx + 1);
    ia.args      = (argc > (prog_idx + 1)) ? (argv + (prog_idx + 1)) : NULL;

    InitWindow(WIN_W, WIN_H, "CBM-BASIC GFX");
    SetTargetFPS(60);
    target = LoadRenderTexture(NATIVE_W, NATIVE_H);

    pthread_create(&tid, NULL, interpreter_thread, &ia);

    while (!WindowShouldClose()) {
        render_text_screen(&vs, target);

        BeginDrawing();
        DrawTexturePro(
            target.texture,
            (Rectangle){ 0, 0, (float)NATIVE_W, -(float)NATIVE_H },
            (Rectangle){ 0, 0, (float)WIN_W, (float)WIN_H },
            (Vector2){ 0, 0 }, 0.0f, WHITE);
        EndDrawing();
    }

    UnloadRenderTexture(target);
    CloseWindow();
    pthread_join(tid, NULL);
    return 0;
}

/* ══════════════════════════════════════════════════════════════════════
 *  MODE 2: gfx-demo  (GFX_VIDEO not defined)
 *  Standalone test pattern – no interpreter, no threading.
 * ══════════════════════════════════════════════════════════════════════ */
#else /* !GFX_VIDEO */

static uint8_t ascii_to_screencode(char c)
{
    if (c >= 'A' && c <= 'Z') return (uint8_t)(c - 'A' + 1);
    if (c >= 'a' && c <= 'z') return (uint8_t)(c - 'a' + 1);
    if (c == '@') return 0;
    if (c >= ' ' && c <= '?') return (uint8_t)c;
    return 32;
}

static void write_text(GfxVideoState *s, int col, int row,
                       const char *text, uint8_t color_idx)
{
    int i;
    for (i = 0; text[i] != '\0'; i++) {
        int pos = row * SCREEN_COLS + col + i;
        if (pos < 0 || pos >= (int)GFX_TEXT_SIZE) break;
        s->screen[pos] = ascii_to_screencode(text[i]);
        s->color[pos]  = color_idx;
    }
}

static void write_text_reversed(GfxVideoState *s, int col, int row,
                                const char *text, uint8_t color_idx)
{
    int i;
    for (i = 0; text[i] != '\0'; i++) {
        int pos = row * SCREEN_COLS + col + i;
        if (pos < 0 || pos >= (int)GFX_TEXT_SIZE) break;
        s->screen[pos] = ascii_to_screencode(text[i]) | 0x80;
        s->color[pos]  = color_idx;
    }
}

static void setup_demo(GfxVideoState *s)
{
    int row;

    memset(s->screen, 32, GFX_TEXT_SIZE);
    memset(s->color, 14, GFX_COLOR_SIZE);

    write_text(s, 4, 1, "**** CBM-BASIC GFX V1 ****", 1);
    write_text(s, 4, 3, "RAYLIB PHASE 1 - VIDEO MEMORY", 14);
    write_text(s, 4, 4, "40X25 TEXT SCREEN + 8X8 FONT", 14);
    write_text(s, 1, 6, "ABCDEFGHIJKLMNOPQRSTUVWXYZ", 1);
    write_text(s, 1, 7, "0123456789 !@#$%&()+=-.,;:", 15);

    write_text(s, 1, 9, "COLOUR PALETTE:", 1);
    for (row = 0; row < 16; row++) {
        int r = 11 + row / 8;
        int col_start = (row % 8) * 5;
        int c;
        for (c = 0; c < 4; c++) {
            int pos = r * SCREEN_COLS + col_start + c;
            s->screen[pos] = 32 | 0x80;
            s->color[pos]  = (uint8_t)row;
        }
    }
    write_text(s, 1, 13, "BLK  WHT  RED  CYN  PUR", 15);
    write_text(s, 1, 14, "GRN  BLU  YEL  ORG  BRN", 15);
    write_text(s, 0, 16, "READY.", 14);

    {
        static const struct { uint8_t ci; const char *label; } stripes[] = {
            { 2, "    RED STRIPE    " },  { 3, "   CYAN STRIPE    " },
            { 4, "  PURPLE STRIPE   " },  { 5, "   GREEN STRIPE   " },
            { 6, "   BLUE STRIPE    " },  { 7, "  YELLOW STRIPE   " },
        };
        int si;
        for (si = 0; si < 6; si++) {
            int r = 18 + si, c;
            for (c = 0; c < SCREEN_COLS; c++) {
                int pos = r * SCREEN_COLS + c;
                s->screen[pos] = 32 | 0x80;
                s->color[pos]  = stripes[si].ci;
            }
            write_text_reversed(s, 11, r, stripes[si].label, stripes[si].ci);
        }
    }
    write_text(s, 3, 24, "PRESS ESC OR CLOSE WINDOW TO EXIT", 15);
}

int main(void)
{
    GfxVideoState vs;
    RenderTexture2D target;

    gfx_video_init(&vs);
    load_default_charrom(&vs);
    setup_demo(&vs);

    InitWindow(WIN_W, WIN_H, "CBM-BASIC GFX \xe2\x80\x93 Phase 1 Demo");
    SetTargetFPS(60);
    target = LoadRenderTexture(NATIVE_W, NATIVE_H);

    while (!WindowShouldClose()) {
        render_text_screen(&vs, target);

        BeginDrawing();
        DrawTexturePro(
            target.texture,
            (Rectangle){ 0, 0, (float)NATIVE_W, -(float)NATIVE_H },
            (Rectangle){ 0, 0, (float)WIN_W, (float)WIN_H },
            (Vector2){ 0, 0 }, 0.0f, WHITE);
        EndDrawing();
    }

    UnloadRenderTexture(target);
    CloseWindow();
    return 0;
}

#endif /* !GFX_VIDEO */
