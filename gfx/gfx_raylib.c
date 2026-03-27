/* gfx/gfx_raylib.c – Raylib front-end for RGC-BASIC GFX.
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
#include "../petscii.h"
#include <string.h>
#include <stdio.h>

#ifdef GFX_VIDEO
#include <pthread.h>
#include <stdlib.h>
#include "../basic_api.h"

#define GFX_SPRITE_MAX_SLOTS   64
#define GFX_SPRITE_Q_CAP      256
#define GFX_SPRITE_PATH_MAX   512

typedef enum {
    GFX_SQ_LOAD = 1,
    GFX_SQ_UNLOAD,
    GFX_SQ_DRAW,
    GFX_SQ_VISIBLE
} GfxSpriteQKind;

typedef struct {
    GfxSpriteQKind kind;
    int slot;
    char path[GFX_SPRITE_PATH_MAX];
    float x, y;
    int z;
    int sx, sy, sw, sh;
} GfxSpriteCmd;

typedef struct {
    Texture2D tex;
    int loaded;
    int visible;
    /* Persistent draw state (last DRAWSPRITE for this slot until UNLOAD). */
    int draw_active;
    float draw_x, draw_y;
    int draw_z;
    int draw_sx, draw_sy, draw_sw, draw_sh;
} GfxSpriteSlot;

typedef struct {
    int slot;
    float x, y;
    int z;
    int sx, sy, sw, sh;
} GfxSpriteDraw;

static pthread_mutex_t g_sprite_mutex = PTHREAD_MUTEX_INITIALIZER;
static char g_sprite_base_dir[GFX_SPRITE_PATH_MAX];
static GfxSpriteSlot g_sprite_slots[GFX_SPRITE_MAX_SLOTS];
static GfxSpriteCmd g_sprite_q[GFX_SPRITE_Q_CAP];
static int g_sprite_q_count;

static int sprite_q_push(const GfxSpriteCmd *c)
{
    int ok = 0;
    pthread_mutex_lock(&g_sprite_mutex);
    if (g_sprite_q_count < GFX_SPRITE_Q_CAP) {
        g_sprite_q[g_sprite_q_count++] = *c;
        ok = 1;
    }
    pthread_mutex_unlock(&g_sprite_mutex);
    return ok;
}

void gfx_set_sprite_base_dir(const char *dir)
{
    pthread_mutex_lock(&g_sprite_mutex);
    if (!dir || !dir[0]) {
        g_sprite_base_dir[0] = '\0';
    } else {
        strncpy(g_sprite_base_dir, dir, sizeof(g_sprite_base_dir) - 1);
        g_sprite_base_dir[sizeof(g_sprite_base_dir) - 1] = '\0';
    }
    pthread_mutex_unlock(&g_sprite_mutex);
}

static void sprite_build_path(char *out, size_t outsz, const char *rel)
{
    if (!rel || !rel[0]) {
        out[0] = '\0';
        return;
    }
    if (rel[0] == '/' || (rel[0] != '\0' && rel[1] == ':' &&
                          ((rel[0] >= 'A' && rel[0] <= 'Z') ||
                           (rel[0] >= 'a' && rel[0] <= 'z')))) {
        snprintf(out, outsz, "%s", rel);
        return;
    }
    pthread_mutex_lock(&g_sprite_mutex);
    if (g_sprite_base_dir[0] != '\0') {
        snprintf(out, outsz, "%s/%s", g_sprite_base_dir, rel);
    } else {
        snprintf(out, outsz, "%s", rel);
    }
    pthread_mutex_unlock(&g_sprite_mutex);
}

void gfx_sprite_enqueue_load(int slot, const char *path)
{
    GfxSpriteCmd c;
    if (slot < 0 || slot >= GFX_SPRITE_MAX_SLOTS || !path) {
        return;
    }
    memset(&c, 0, sizeof(c));
    c.kind = GFX_SQ_LOAD;
    c.slot = slot;
    strncpy(c.path, path, sizeof(c.path) - 1);
    c.path[sizeof(c.path) - 1] = '\0';
    (void)sprite_q_push(&c);
}

void gfx_sprite_enqueue_unload(int slot)
{
    GfxSpriteCmd c;
    if (slot < 0 || slot >= GFX_SPRITE_MAX_SLOTS) {
        return;
    }
    memset(&c, 0, sizeof(c));
    c.kind = GFX_SQ_UNLOAD;
    c.slot = slot;
    (void)sprite_q_push(&c);
}

void gfx_sprite_enqueue_visible(int slot, int on)
{
    GfxSpriteCmd c;
    if (slot < 0 || slot >= GFX_SPRITE_MAX_SLOTS) {
        return;
    }
    memset(&c, 0, sizeof(c));
    c.kind = GFX_SQ_VISIBLE;
    c.slot = slot;
    c.z = on ? 1 : 0;
    (void)sprite_q_push(&c);
}

void gfx_sprite_enqueue_draw(int slot, float x, float y, int z, int sx, int sy, int sw, int sh)
{
    GfxSpriteCmd c;
    if (slot < 0 || slot >= GFX_SPRITE_MAX_SLOTS) {
        return;
    }
    memset(&c, 0, sizeof(c));
    c.kind = GFX_SQ_DRAW;
    c.slot = slot;
    c.x = x;
    c.y = y;
    c.z = z;
    c.sx = sx;
    c.sy = sy;
    c.sw = sw;
    c.sh = sh;
    (void)sprite_q_push(&c);
}

int gfx_sprite_slot_width(int slot)
{
    int w = 0;
    if (slot < 0 || slot >= GFX_SPRITE_MAX_SLOTS) {
        return 0;
    }
    pthread_mutex_lock(&g_sprite_mutex);
    if (g_sprite_slots[slot].loaded) {
        w = g_sprite_slots[slot].tex.width;
    }
    pthread_mutex_unlock(&g_sprite_mutex);
    return w;
}

int gfx_sprite_slot_height(int slot)
{
    int h = 0;
    if (slot < 0 || slot >= GFX_SPRITE_MAX_SLOTS) {
        return 0;
    }
    pthread_mutex_lock(&g_sprite_mutex);
    if (g_sprite_slots[slot].loaded) {
        h = g_sprite_slots[slot].tex.height;
    }
    pthread_mutex_unlock(&g_sprite_mutex);
    return h;
}

static int cmp_sprite_draw_z(const void *a, const void *b)
{
    const GfxSpriteDraw *da = (const GfxSpriteDraw *)a;
    const GfxSpriteDraw *db = (const GfxSpriteDraw *)b;
    if (da->z < db->z) {
        return -1;
    }
    if (da->z > db->z) {
        return 1;
    }
    return 0;
}

/* Process queued loads/unloads/visibility/draw-updates (main thread only). */
static void gfx_sprite_process_queue(void)
{
    GfxSpriteCmd cmds[GFX_SPRITE_Q_CAP];
    int i, n = 0;

    pthread_mutex_lock(&g_sprite_mutex);
    n = g_sprite_q_count;
    if (n > GFX_SPRITE_Q_CAP) {
        n = GFX_SPRITE_Q_CAP;
    }
    for (i = 0; i < n; i++) {
        cmds[i] = g_sprite_q[i];
    }
    g_sprite_q_count = 0;
    pthread_mutex_unlock(&g_sprite_mutex);

    for (i = 0; i < n; i++) {
        GfxSpriteCmd *c = &cmds[i];
        if (c->slot < 0 || c->slot >= GFX_SPRITE_MAX_SLOTS) {
            continue;
        }
        switch (c->kind) {
        case GFX_SQ_LOAD: {
            char full[1024];
            Texture2D t;
            sprite_build_path(full, sizeof(full), c->path);
            pthread_mutex_lock(&g_sprite_mutex);
            if (g_sprite_slots[c->slot].loaded) {
                UnloadTexture(g_sprite_slots[c->slot].tex);
                g_sprite_slots[c->slot].loaded = 0;
            }
            pthread_mutex_unlock(&g_sprite_mutex);
            t = LoadTexture(full);
            pthread_mutex_lock(&g_sprite_mutex);
            if (t.id != 0) {
                SetTextureFilter(t, TEXTURE_FILTER_POINT);
                g_sprite_slots[c->slot].tex = t;
                g_sprite_slots[c->slot].loaded = 1;
                g_sprite_slots[c->slot].visible = 1;
                g_sprite_slots[c->slot].draw_active = 0;
            }
            pthread_mutex_unlock(&g_sprite_mutex);
            break;
        }
        case GFX_SQ_VISIBLE:
            pthread_mutex_lock(&g_sprite_mutex);
            if (c->slot >= 0 && c->slot < GFX_SPRITE_MAX_SLOTS) {
                g_sprite_slots[c->slot].visible = c->z ? 1 : 0;
            }
            pthread_mutex_unlock(&g_sprite_mutex);
            break;
        case GFX_SQ_UNLOAD:
            pthread_mutex_lock(&g_sprite_mutex);
            if (g_sprite_slots[c->slot].loaded) {
                UnloadTexture(g_sprite_slots[c->slot].tex);
                g_sprite_slots[c->slot].loaded = 0;
                g_sprite_slots[c->slot].visible = 0;
                g_sprite_slots[c->slot].draw_active = 0;
            }
            pthread_mutex_unlock(&g_sprite_mutex);
            break;
        case GFX_SQ_DRAW:
            pthread_mutex_lock(&g_sprite_mutex);
            if (c->slot >= 0 && c->slot < GFX_SPRITE_MAX_SLOTS) {
                g_sprite_slots[c->slot].draw_active = 1;
                g_sprite_slots[c->slot].draw_x = c->x;
                g_sprite_slots[c->slot].draw_y = c->y;
                g_sprite_slots[c->slot].draw_z = c->z;
                g_sprite_slots[c->slot].draw_sx = c->sx;
                g_sprite_slots[c->slot].draw_sy = c->sy;
                g_sprite_slots[c->slot].draw_sw = c->sw;
                g_sprite_slots[c->slot].draw_sh = c->sh;
            }
            pthread_mutex_unlock(&g_sprite_mutex);
            break;
        default:
            break;
        }
    }
}

static void gfx_sprite_shutdown(void)
{
    int i;
    pthread_mutex_lock(&g_sprite_mutex);
    for (i = 0; i < GFX_SPRITE_MAX_SLOTS; i++) {
            if (g_sprite_slots[i].loaded) {
            UnloadTexture(g_sprite_slots[i].tex);
            g_sprite_slots[i].loaded = 0;
            g_sprite_slots[i].visible = 0;
            g_sprite_slots[i].draw_active = 0;
        }
    }
    g_sprite_q_count = 0;
    pthread_mutex_unlock(&g_sprite_mutex);
}

static void gfx_sprite_composite(RenderTexture2D target, int nat_w, int nat_h)
{
    GfxSpriteDraw draws[GFX_SPRITE_MAX_SLOTS];
    int nd = 0;
    int i;

    gfx_sprite_process_queue();

    pthread_mutex_lock(&g_sprite_mutex);
    for (i = 0; i < GFX_SPRITE_MAX_SLOTS; i++) {
        if (!g_sprite_slots[i].loaded || !g_sprite_slots[i].visible ||
            !g_sprite_slots[i].draw_active) {
            continue;
        }
        if (nd >= GFX_SPRITE_MAX_SLOTS) {
            break;
        }
        draws[nd].slot = i;
        draws[nd].x = g_sprite_slots[i].draw_x;
        draws[nd].y = g_sprite_slots[i].draw_y;
        draws[nd].z = g_sprite_slots[i].draw_z;
        draws[nd].sx = g_sprite_slots[i].draw_sx;
        draws[nd].sy = g_sprite_slots[i].draw_sy;
        draws[nd].sw = g_sprite_slots[i].draw_sw;
        draws[nd].sh = g_sprite_slots[i].draw_sh;
        nd++;
    }
    pthread_mutex_unlock(&g_sprite_mutex);

    if (nd <= 0) {
        return;
    }
    qsort(draws, (size_t)nd, sizeof(draws[0]), cmp_sprite_draw_z);

    BeginTextureMode(target);
    BeginBlendMode(BLEND_ALPHA);
    for (i = 0; i < nd; i++) {
        GfxSpriteDraw *d = &draws[i];
        int s = d->slot;
        float sx, sy, sw, sh;
        Rectangle src, dest;
        Texture2D t;

        if (s < 0 || s >= GFX_SPRITE_MAX_SLOTS) {
            continue;
        }
        pthread_mutex_lock(&g_sprite_mutex);
        if (!g_sprite_slots[s].loaded || !g_sprite_slots[s].visible) {
            pthread_mutex_unlock(&g_sprite_mutex);
            continue;
        }
        t = g_sprite_slots[s].tex;
        pthread_mutex_unlock(&g_sprite_mutex);

        sx = (float)d->sx;
        sy = (float)d->sy;
        if (d->sw <= 0 || d->sh <= 0) {
            sw = (float)(t.width - d->sx);
            sh = (float)(t.height - d->sy);
        } else {
            sw = (float)d->sw;
            sh = (float)d->sh;
        }
        if (sw <= 0 || sh <= 0) {
            continue;
        }
        if (sx < 0 || sy < 0 || sx + sw > (float)t.width + 0.01f ||
            sy + sh > (float)t.height + 0.01f) {
            continue;
        }
        src = (Rectangle){ sx, sy, sw, sh };
        dest = (Rectangle){ d->x, d->y, sw, sh };
        DrawTexturePro(
            t,
            src,
            dest,
            (Vector2){ 0, 0 },
            0.0f,
            WHITE);
    }
    EndBlendMode();
    EndTextureMode();
    (void)nat_w;
    (void)nat_h;
}
#endif /* GFX_VIDEO */

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

/* Background colour comes from video state (s->bg_color). */

#include "gfx_charrom.h"


/* ── Renderer (shared by both modes) ──────────────────────────────── */

static void render_text_screen(const GfxVideoState *s,
                               RenderTexture2D target)
{
    int row, col, y, x;
    int cols = (s->cols == 40 || s->cols == 80) ? (int)s->cols : 40;

    BeginTextureMode(target);
    ClearBackground(c64_palette[s->bg_color & 0x0F]);

    for (row = 0; row < SCREEN_ROWS; row++) {
        for (col = 0; col < cols; col++) {
            int idx = row * cols + col;
            uint8_t sc = s->screen[idx];
            uint8_t ci = s->color[idx] & 0x0F;
            const uint8_t *glyph;
            Color fg = c64_palette[ci];
            Color bg = c64_palette[s->bg_color & 0x0F];
            int reversed = (sc & 0x80) ? 1 : 0;

            /* Screen RAM holds C64 screen codes 0–255. For reversed (128–255),
             * screen 65–90 (A–Z) use the uppercase font’s 1–26 glyphs—font_lower
             * use base glyph and swap fg/bg (font_lower wrong at 208/215). */
            glyph = &s->chars[(uint8_t)(sc & 0x7F) * 8];

            for (y = 0; y < CELL_H; y++) {
                uint8_t bits = glyph[y];
                for (x = 0; x < CELL_W; x++) {
                    int px = col * CELL_W + x;
                    int py = row * CELL_H + y;
                    int on = (bits & (0x80 >> x)) ? 1 : 0;
                    Color c = (on ^ reversed) ? fg : bg;
                    DrawPixel(px, py, c);
                }
            }
        }
    }
    EndTextureMode();
}

/* 320×200 hi-res: MSB of each byte is the leftmost pixel in that group of 8. */
static void render_bitmap_screen(const GfxVideoState *s, RenderTexture2D target,
                                 int native_w)
{
    int y, x, off_x;
    Color fg = c64_palette[s->bitmap_fg & 0x0F];
    Color bg = c64_palette[s->bg_color & 0x0F];

    off_x = (native_w - (int)GFX_BITMAP_WIDTH) / 2;
    if (off_x < 0) {
        off_x = 0;
    }

    BeginTextureMode(target);
    ClearBackground(bg);
    for (y = 0; y < (int)GFX_BITMAP_HEIGHT; y++) {
        for (x = 0; x < (int)GFX_BITMAP_WIDTH; x++) {
            int on = gfx_bitmap_get_pixel(s, (unsigned)x, (unsigned)y);
            DrawPixel(off_x + x, y, on ? fg : bg);
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

static void keyq_push(GfxVideoState *vs, uint8_t b)
{
    uint8_t next = (uint8_t)(vs->key_q_tail + 1);
    if (next >= (uint8_t)sizeof(vs->key_queue)) next = 0;
    if (next == vs->key_q_head) {
        return;  /* full: drop */
    }
    vs->key_queue[vs->key_q_tail] = b;
    vs->key_q_tail = next;
}

int main(int argc, char **argv)
{
    GfxVideoState vs;
    RenderTexture2D target;
    pthread_t tid;
    InterpreterArgs ia;
    int prog_idx;
    const char *prog_path;
    int closed_by_user;
    int nat_w, nat_h, win_w, win_h;

    prog_idx = basic_parse_args(argc, argv);
    if (prog_idx < 0) {
        fprintf(stderr,
                "Usage: %s [-petscii] [-palette ansi|c64] [-columns 80] [-gfx-title \"title\"] [-gfx-border N] <program.bas> [args...]\n",
                argv[0]);
        return 1;
    }
    prog_path = argv[prog_idx];

    gfx_video_init(&vs);
    vs.charset_lowercase = (uint8_t)(petscii_get_lowercase() ? 1 : 0);
    gfx_load_default_charrom(&vs);
    memset(vs.screen, 32, GFX_TEXT_SIZE);
    memset(vs.color, 14, GFX_COLOR_SIZE);

    basic_set_video(&vs);

    ia.prog_path = prog_path;
    ia.nargs     = argc - (prog_idx + 1);
    ia.args      = (argc > (prog_idx + 1)) ? (argv + (prog_idx + 1)) : NULL;

    /* Window/target size from vs.cols (40 or 80); set by basic_set_video from -columns */
    {
        int cols = vs.cols ? (int)vs.cols : 40;
        nat_w = cols * CELL_W;
        nat_h = SCREEN_ROWS * CELL_H;
        win_w = nat_w * SCALE;
        win_h = nat_h * SCALE;

        SetTraceLogLevel(LOG_WARNING);
        {
            const char *title = basic_get_gfx_window_title();
            InitWindow(win_w, win_h, title ? title : "RGC-BASIC GFX");
        }
        SetTargetFPS(60);
        target = LoadRenderTexture(nat_w, nat_h);
    }

    pthread_create(&tid, NULL, interpreter_thread, &ia);

    /* Run the render loop until either:
     *  - the user closes the window / presses ESC, or
     *  - the BASIC interpreter has halted (END / error / fall-through).
     *
     * This allows BASIC programs to control how long the window remains
     * visible (e.g., via SLEEP) and then exit cleanly without requiring
     * manual ESC presses. */
    while (!WindowShouldClose() && !basic_halted()) {
        /* Apply #OPTION gfx_title if set during load */
        {
            static char last_title[128];
            const char *t = basic_get_gfx_window_title();
            if (t && strcmp(t, last_title) != 0) {
                SetWindowTitle(t);
                strncpy(last_title, t, sizeof(last_title) - 1);
                last_title[sizeof(last_title) - 1] = '\0';
            }
        }
        static uint8_t last_charset = 0xFF;
        if (last_charset != vs.charset_lowercase) {
            gfx_load_default_charrom(&vs);
            last_charset = vs.charset_lowercase;
        }
        /* 60 Hz jiffy clock (C64-style TI), wraps every 24 hours. */
        vs.ticks60++;
        if (vs.ticks60 >= 5184000u) {
            vs.ticks60 = 0;
        }

        /* Update simple keyboard state map (ASCII-like indices) so BASIC can
         * poll via PEEK(GFX_KEY_BASE + code). */
        gfx_video_clear_keys(&vs);
        if (IsKeyDown(KEY_SPACE))  vs.key_state[32]  = 1;
        if (IsKeyDown(KEY_ENTER))  vs.key_state[13]  = 1;
        if (IsKeyDown(KEY_ESCAPE)) vs.key_state[27]  = 1;
        if (IsKeyDown(KEY_UP))     vs.key_state[145] = 1; /* C64 CHR$ up */
        if (IsKeyDown(KEY_DOWN))   vs.key_state[17]  = 1; /* C64 CHR$ down */
        if (IsKeyDown(KEY_LEFT))   vs.key_state[157] = 1; /* C64 CHR$ left */
        if (IsKeyDown(KEY_RIGHT))  vs.key_state[29]  = 1; /* C64 CHR$ right */
        if (IsKeyDown(KEY_A)) vs.key_state['A'] = 1;
        if (IsKeyDown(KEY_B)) vs.key_state['B'] = 1;
        if (IsKeyDown(KEY_C)) vs.key_state['C'] = 1;
        if (IsKeyDown(KEY_D)) vs.key_state['D'] = 1;
        if (IsKeyDown(KEY_E)) vs.key_state['E'] = 1;
        if (IsKeyDown(KEY_F)) vs.key_state['F'] = 1;
        if (IsKeyDown(KEY_G)) vs.key_state['G'] = 1;
        if (IsKeyDown(KEY_H)) vs.key_state['H'] = 1;
        if (IsKeyDown(KEY_I)) vs.key_state['I'] = 1;
        if (IsKeyDown(KEY_J)) vs.key_state['J'] = 1;
        if (IsKeyDown(KEY_K)) vs.key_state['K'] = 1;
        if (IsKeyDown(KEY_L)) vs.key_state['L'] = 1;
        if (IsKeyDown(KEY_M)) vs.key_state['M'] = 1;
        if (IsKeyDown(KEY_N)) vs.key_state['N'] = 1;
        if (IsKeyDown(KEY_O)) vs.key_state['O'] = 1;
        if (IsKeyDown(KEY_P)) vs.key_state['P'] = 1;
        if (IsKeyDown(KEY_Q)) vs.key_state['Q'] = 1;
        if (IsKeyDown(KEY_R)) vs.key_state['R'] = 1;
        if (IsKeyDown(KEY_S)) vs.key_state['S'] = 1;
        if (IsKeyDown(KEY_T)) vs.key_state['T'] = 1;
        if (IsKeyDown(KEY_U)) vs.key_state['U'] = 1;
        if (IsKeyDown(KEY_V)) vs.key_state['V'] = 1;
        if (IsKeyDown(KEY_W)) vs.key_state['W'] = 1;
        if (IsKeyDown(KEY_X)) vs.key_state['X'] = 1;
        if (IsKeyDown(KEY_Y)) vs.key_state['Y'] = 1;
        if (IsKeyDown(KEY_Z)) vs.key_state['Z'] = 1;
        if (IsKeyDown(KEY_ZERO))  vs.key_state['0'] = 1;
        if (IsKeyDown(KEY_ONE))   vs.key_state['1'] = 1;
        if (IsKeyDown(KEY_TWO))   vs.key_state['2'] = 1;
        if (IsKeyDown(KEY_THREE)) vs.key_state['3'] = 1;
        if (IsKeyDown(KEY_FOUR))  vs.key_state['4'] = 1;
        if (IsKeyDown(KEY_FIVE))  vs.key_state['5'] = 1;
        if (IsKeyDown(KEY_SIX))   vs.key_state['6'] = 1;
        if (IsKeyDown(KEY_SEVEN)) vs.key_state['7'] = 1;
        if (IsKeyDown(KEY_EIGHT)) vs.key_state['8'] = 1;
        if (IsKeyDown(KEY_NINE))  vs.key_state['9'] = 1;

        /* Keypress FIFO for INKEY$(): collect typed characters and a few
         * special keys as single-byte codes. */
        {
            int ch;
            int got_any = 0;
            int got_printable = 0;
            while ((ch = GetCharPressed()) > 0) {
                if (ch >= 1 && ch <= 255) {
                    if (ch >= 'a' && ch <= 'z') ch = (ch - 'a') + 'A';
                    keyq_push(&vs, (uint8_t)ch);
                    got_any = 1;
                    if (ch >= ' ' && ch <= '~') got_printable = 1;
                }
            }
            /* Skip IsKeyPressed when GetCharPressed already delivered—avoids
             * duplicate keys (both can report the same press on e.g. Enter). */
            if (!got_any) {
            if (IsKeyPressed(KEY_ENTER))     keyq_push(&vs, 13);
            if (IsKeyPressed(KEY_BACKSPACE)) keyq_push(&vs, 20);  /* DEL */
            if (IsKeyPressed(KEY_ESCAPE))    keyq_push(&vs, 27);
            if (IsKeyPressed(KEY_UP))        keyq_push(&vs, 145);
            if (IsKeyPressed(KEY_DOWN))      keyq_push(&vs, 17);
            if (IsKeyPressed(KEY_LEFT))      keyq_push(&vs, 157);
            if (IsKeyPressed(KEY_RIGHT))     keyq_push(&vs, 29);
            }
            /* WSLg may not deliver printable chars via GetCharPressed. */
            if (!got_printable) {
            if (IsKeyPressed(KEY_A)) keyq_push(&vs, 'A');
            if (IsKeyPressed(KEY_B)) keyq_push(&vs, 'B');
            if (IsKeyPressed(KEY_C)) keyq_push(&vs, 'C');
            if (IsKeyPressed(KEY_D)) keyq_push(&vs, 'D');
            if (IsKeyPressed(KEY_E)) keyq_push(&vs, 'E');
            if (IsKeyPressed(KEY_F)) keyq_push(&vs, 'F');
            if (IsKeyPressed(KEY_G)) keyq_push(&vs, 'G');
            if (IsKeyPressed(KEY_H)) keyq_push(&vs, 'H');
            if (IsKeyPressed(KEY_I)) keyq_push(&vs, 'I');
            if (IsKeyPressed(KEY_J)) keyq_push(&vs, 'J');
            if (IsKeyPressed(KEY_K)) keyq_push(&vs, 'K');
            if (IsKeyPressed(KEY_L)) keyq_push(&vs, 'L');
            if (IsKeyPressed(KEY_M)) keyq_push(&vs, 'M');
            if (IsKeyPressed(KEY_N)) keyq_push(&vs, 'N');
            if (IsKeyPressed(KEY_O)) keyq_push(&vs, 'O');
            if (IsKeyPressed(KEY_P)) keyq_push(&vs, 'P');
            if (IsKeyPressed(KEY_Q)) keyq_push(&vs, 'Q');
            if (IsKeyPressed(KEY_R)) keyq_push(&vs, 'R');
            if (IsKeyPressed(KEY_S)) keyq_push(&vs, 'S');
            if (IsKeyPressed(KEY_T)) keyq_push(&vs, 'T');
            if (IsKeyPressed(KEY_U)) keyq_push(&vs, 'U');
            if (IsKeyPressed(KEY_V)) keyq_push(&vs, 'V');
            if (IsKeyPressed(KEY_W)) keyq_push(&vs, 'W');
            if (IsKeyPressed(KEY_X)) keyq_push(&vs, 'X');
            if (IsKeyPressed(KEY_Y)) keyq_push(&vs, 'Y');
            if (IsKeyPressed(KEY_Z)) keyq_push(&vs, 'Z');
            if (IsKeyPressed(KEY_ZERO))  keyq_push(&vs, '0');
            if (IsKeyPressed(KEY_ONE))   keyq_push(&vs, '1');
            if (IsKeyPressed(KEY_TWO))   keyq_push(&vs, '2');
            if (IsKeyPressed(KEY_THREE)) keyq_push(&vs, '3');
            if (IsKeyPressed(KEY_FOUR))  keyq_push(&vs, '4');
            if (IsKeyPressed(KEY_FIVE))  keyq_push(&vs, '5');
            if (IsKeyPressed(KEY_SIX))   keyq_push(&vs, '6');
            if (IsKeyPressed(KEY_SEVEN)) keyq_push(&vs, '7');
            if (IsKeyPressed(KEY_EIGHT)) keyq_push(&vs, '8');
            if (IsKeyPressed(KEY_NINE))  keyq_push(&vs, '9');
            }
        }

        if (vs.screen_mode == GFX_SCREEN_BITMAP) {
            render_bitmap_screen(&vs, target, nat_w);
        } else {
            render_text_screen(&vs, target);
        }
        gfx_sprite_composite(target, nat_w, nat_h);

        BeginDrawing();
        {
            int border = basic_get_gfx_border();
            if (border > 0) {
                int bc = basic_get_gfx_border_color();
                uint8_t ci = (bc >= 0 && bc <= 15) ? (uint8_t)bc : (vs.bg_color & 0x0F);
                ClearBackground(c64_palette[ci]);
            }
            {
                float dx = (float)border;
                float dy = (float)border;
                float dw = (float)(win_w - 2 * border);
                float dh = (float)(win_h - 2 * border);
                if (dw < 1) dw = 1;
                if (dh < 1) dh = 1;
                DrawTexturePro(
                    target.texture,
                    (Rectangle){ 0, 0, (float)nat_w, -(float)nat_h },
                    (Rectangle){ dx, dy, dw, dh },
                    (Vector2){ 0, 0 }, 0.0f, WHITE);
            }
        }
        EndDrawing();
    }

    closed_by_user = WindowShouldClose() && !basic_halted();

    gfx_sprite_shutdown();
    UnloadRenderTexture(target);
    CloseWindow();
    /* If the user closed the window before the BASIC program ended, don't
     * block forever waiting for the interpreter thread. Exiting the process
     * will terminate all threads; detach to avoid a join leak. */
    if (closed_by_user) {
        pthread_detach(tid);
        return 0;
    }
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

    write_text(s, 4, 1, "**** RGC-BASIC GFX V1 ****", 1);
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
    gfx_load_default_charrom(&vs);
    setup_demo(&vs);

    /* Suppress raylib INFO trace logs (e.g. timer messages). */
    SetTraceLogLevel(LOG_WARNING);
    InitWindow(WIN_W, WIN_H, "RGC-BASIC GFX \xe2\x80\x93 Phase 1 Demo");
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
