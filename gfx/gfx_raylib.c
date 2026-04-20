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
#include "gfx_mouse.h"
#include "gfx_sound.h"
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
    GFX_SQ_VISIBLE,
    GFX_SQ_COPY
} GfxSpriteQKind;

typedef struct {
    GfxSpriteQKind kind;
    int slot;
    int slot2; /* COPY: destination slot */
    char path[GFX_SPRITE_PATH_MAX];
    float x, y;
    int z;
    int sx, sy, sw, sh;
    int tile_w, tile_h; /* LOADSPRITE tilemap: >0 = grid cell size */
    /* COPY: mod values snapshotted at enqueue time */
    int mod_a, mod_r, mod_g, mod_b;
    float mod_sx, mod_sy;
} GfxSpriteCmd;

typedef struct {
    Texture2D tex;
    Image     src_image;  /* CPU-side copy for pixel-perfect hit tests; .data = NULL if absent */
    int loaded;
    int visible;
    int tile_w, tile_h;   /* 0 = single image */
    int tiles_x, tiles_y; /* grid dimensions */
    int tile_count;       /* tiles_x * tiles_y, or 1 for single */
    int draw_frame;       /* 1-based tile index for DRAWSPRITE default crop */
    /* Per-slot modulation (SPRITEMODULATE); default opaque white, scale 1,1. */
    int mod_a, mod_r, mod_g, mod_b;
    float mod_sx, mod_sy;
    int mod_explicit; /* 1 if SPRITEMODULATE ran; preserve when LOAD finishes async */
    /* Persistent draw state (last DRAWSPRITE for this slot until UNLOAD). */
    int draw_active;
    float draw_x, draw_y;
    int draw_z;
    int draw_sx, draw_sy, draw_sw, draw_sh;
    /* Full path to source PNG — kept so SPRITECOPY can reload+tint from disk. */
    char src_path[GFX_SPRITE_PATH_MAX];
} GfxSpriteSlot;

typedef struct {
    int slot;
    float x, y;
    int z;
    int sx, sy, sw, sh;
    int mod_a, mod_r, mod_g, mod_b;
    float mod_sx, mod_sy;
} GfxSpriteDraw;

static void gfx_sprite_process_queue(void);

static pthread_mutex_t g_sprite_mutex = PTHREAD_MUTEX_INITIALIZER;
/* macOS / OpenGL: LoadTexture/UnloadTexture must run on the main thread. Worker waits
 * until the render loop has processed LOAD/UNLOAD (see gfx_sprite_process_queue tail). */
static pthread_cond_t g_sprite_gpu_cv = PTHREAD_COND_INITIALIZER;
static uint64_t g_sprite_gpu_issue_seq = 0;
static uint64_t g_sprite_gpu_done_seq = 0;

/* ── IMAGE GRAB from visible framebuffer (cross-thread) ─────────────
 *
 * BASIC's IMAGE GRAB slot, sx, sy, sw, sh runs on the interpreter
 * thread, but LoadImageFromTexture needs the GL context that only the
 * render thread owns. Interpreter posts a grab request + cond_waits;
 * render thread, right after sprite composite, pulls pixels off the
 * composited RenderTexture into the slot's RGBA buffer, then signals.
 *
 * Worst-case block = time to next render tick (~16 ms at 60 Hz). */
static pthread_mutex_t g_grab_mtx = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t  g_grab_cv  = PTHREAD_COND_INITIALIZER;
static int g_grab_pending = 0;
static int g_grab_slot    = 0;
static int g_grab_sx, g_grab_sy, g_grab_sw, g_grab_sh;
static int g_grab_result  = -1;

static char g_sprite_base_dir[GFX_SPRITE_PATH_MAX];
static GfxSpriteSlot g_sprite_slots[GFX_SPRITE_MAX_SLOTS];

/* Global anti-aliasing / texture-filter mode.
 *   0 = nearest-neighbour (hard pixels, classic retro look) — default
 *   1 = bilinear (smoothed)
 * Set via the BASIC `ANTIALIAS ON/OFF` statement. gfx_set_antialias()
 * just flips the flag — the main render thread (which owns the GL
 * context) checks each tick and re-applies the filter to every
 * loaded texture + the target if the value changed. Cross-thread GL
 * calls are undefined under emscripten-glfw, so the interpreter
 * thread never touches texture state directly. */
static int g_antialias = 0;
static int g_antialias_applied = -1; /* force first-frame apply */

static int sprite_filter_mode(void)
{
    return g_antialias ? TEXTURE_FILTER_BILINEAR : TEXTURE_FILTER_POINT;
}

void gfx_set_antialias(int on)
{
    g_antialias = on ? 1 : 0;
}
static GfxSpriteCmd g_sprite_q[GFX_SPRITE_Q_CAP];
static int g_sprite_q_count;

/* Interpreter-thread-local cache of the last DRAWSPRITE per slot.
 * Written in gfx_sprite_enqueue_draw (interpreter thread); read in
 * gfx_sprite_is_mouse_over (interpreter thread). No mutex needed.
 * Exists so ISMOUSEOVERSPRITE can hit-test against where the program
 * just asked to draw, without racing the GPU consumer thread that
 * updates g_sprite_slots[].draw_active/x/y. */
typedef struct {
    int   has_draw;       /* 0 until first enqueue, cleared on unload  */
    float x, y;           /* last-enqueued top-left in world pixels    */
    int   w, h;           /* effective drawn w,h (post tile/crop)      */
    int   z;              /* last-enqueued Z for SPRITEAT tie-break     */
} GfxSpriteDrawPos;
static GfxSpriteDrawPos g_sprite_draw_pos[GFX_SPRITE_MAX_SLOTS];

static void gfx_sprite_wait_gpu_op(uint64_t seq)
{
    if (seq == 0) {
        return;
    }
#if defined(__EMSCRIPTEN__)
    /* Single-threaded wasm: no separate render thread exists to advance
     * g_sprite_gpu_done_seq, so pthread_cond_wait would spin forever.
     * Drain the queue inline — GL context is valid at this point because
     * wasm_raylib_init_once ran during basic_load_and_run_gfx. */
    gfx_sprite_process_queue();
#else
    pthread_mutex_lock(&g_sprite_mutex);
    while (g_sprite_gpu_done_seq < seq) {
        pthread_cond_wait(&g_sprite_gpu_cv, &g_sprite_mutex);
    }
    pthread_mutex_unlock(&g_sprite_mutex);
#endif
}

static int sprite_q_push_locked(const GfxSpriteCmd *c)
{
    if (g_sprite_q_count < GFX_SPRITE_Q_CAP) {
        g_sprite_q[g_sprite_q_count++] = *c;
        return 1;
    }
    return 0;
}

static int sprite_q_push(const GfxSpriteCmd *c)
{
    int ok;
    pthread_mutex_lock(&g_sprite_mutex);
    ok = sprite_q_push_locked(c);
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

void gfx_sprite_enqueue_load_ex(int slot, const char *path, int tile_w, int tile_h)
{
    GfxSpriteCmd c;
    uint64_t seq;
    if (slot < 0 || slot >= GFX_SPRITE_MAX_SLOTS || !path) {
        return;
    }
    memset(&c, 0, sizeof(c));
    c.kind = GFX_SQ_LOAD;
    c.slot = slot;
    c.tile_w = tile_w;
    c.tile_h = tile_h;
    strncpy(c.path, path, sizeof(c.path) - 1);
    c.path[sizeof(c.path) - 1] = '\0';
    pthread_mutex_lock(&g_sprite_mutex);
    if (!sprite_q_push_locked(&c)) {
        pthread_mutex_unlock(&g_sprite_mutex);
        return;
    }
    g_sprite_gpu_issue_seq++;
    seq = g_sprite_gpu_issue_seq;
    pthread_mutex_unlock(&g_sprite_mutex);
    gfx_sprite_wait_gpu_op(seq);
}

void gfx_sprite_enqueue_load(int slot, const char *path)
{
    gfx_sprite_enqueue_load_ex(slot, path, 0, 0);
}

void gfx_sprite_enqueue_unload(int slot)
{
    GfxSpriteCmd c;
    uint64_t seq;
    if (slot < 0 || slot >= GFX_SPRITE_MAX_SLOTS) {
        return;
    }
    memset(&c, 0, sizeof(c));
    c.kind = GFX_SQ_UNLOAD;
    c.slot = slot;
    pthread_mutex_lock(&g_sprite_mutex);
    if (!sprite_q_push_locked(&c)) {
        pthread_mutex_unlock(&g_sprite_mutex);
        return;
    }
    g_sprite_gpu_issue_seq++;
    seq = g_sprite_gpu_issue_seq;
    pthread_mutex_unlock(&g_sprite_mutex);
    gfx_sprite_wait_gpu_op(seq);
    /* Invalidate hit-test cache so ISMOUSEOVERSPRITE returns 0 after UNLOAD. */
    memset(&g_sprite_draw_pos[slot], 0, sizeof(g_sprite_draw_pos[slot]));
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

void gfx_sprite_enqueue_copy(int src_slot, int dst_slot)
{
    GfxSpriteCmd c;
    if (src_slot < 0 || src_slot >= GFX_SPRITE_MAX_SLOTS) return;
    if (dst_slot < 0 || dst_slot >= GFX_SPRITE_MAX_SLOTS) return;
    if (src_slot == dst_slot) return; /* use a spare slot to bake in-place */
    memset(&c, 0, sizeof(c));
    c.kind  = GFX_SQ_COPY;
    c.slot  = src_slot;
    c.slot2 = dst_slot;
    /* Snapshot mod values now (interpreter thread) so render thread sees them */
    pthread_mutex_lock(&g_sprite_mutex);
    c.mod_a  = g_sprite_slots[src_slot].mod_a;
    c.mod_r  = g_sprite_slots[src_slot].mod_r;
    c.mod_g  = g_sprite_slots[src_slot].mod_g;
    c.mod_b  = g_sprite_slots[src_slot].mod_b;
    c.mod_sx = g_sprite_slots[src_slot].mod_sx;
    c.mod_sy = g_sprite_slots[src_slot].mod_sy;
    pthread_mutex_unlock(&g_sprite_mutex);
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

    /* Mirror position into interpreter-thread cache for ISMOUSEOVERSPRITE.
     * sw/sh <= 0 means "use the slot's full sub-texture from (sx,sy)"; we
     * fall back to gfx_sprite_effective_source_rect to resolve that to a
     * real size (grabs mutex internally, so don't hold any lock here).
     *
     * The renderer draws at dest = (src_w * mod_sx, src_h * mod_sy) (see
     * the DrawTexturePro call in gfx_sprite_render_cell_list), so the
     * hit-test cache has to match that scale — otherwise the bbox hangs
     * off the top-left and misses the visible pixels. */
    {
        int rw = sw, rh = sh;
        float msx, msy;
        if (rw <= 0 || rh <= 0) {
            int tsx, tsy, tsw, tsh;
            tsx = sx; tsy = sy; tsw = rw; tsh = rh;
            if (gfx_sprite_effective_source_rect(slot, &tsx, &tsy, &tsw, &tsh) == 0) {
                if (rw <= 0) rw = tsw;
                if (rh <= 0) rh = tsh;
            }
        }
        pthread_mutex_lock(&g_sprite_mutex);
        msx = g_sprite_slots[slot].mod_sx;
        msy = g_sprite_slots[slot].mod_sy;
        pthread_mutex_unlock(&g_sprite_mutex);
        if (msx <= 0.0f) msx = 1.0f;
        if (msy <= 0.0f) msy = 1.0f;
        g_sprite_draw_pos[slot].x = x;
        g_sprite_draw_pos[slot].y = y;
        g_sprite_draw_pos[slot].w = rw > 0 ? (int)((float)rw * msx + 0.5f) : 0;
        g_sprite_draw_pos[slot].h = rh > 0 ? (int)((float)rh * msy + 0.5f) : 0;
        g_sprite_draw_pos[slot].z = z;
        g_sprite_draw_pos[slot].has_draw = (rw > 0 && rh > 0) ? 1 : 0;
    }
}

int gfx_sprite_hit_rect(int slot, int wx, int wy)
{
    GfxSpriteDrawPos *d;
    int x, y, w, h;
    if (slot < 0 || slot >= GFX_SPRITE_MAX_SLOTS) return 0;
    d = &g_sprite_draw_pos[slot];
    if (!d->has_draw || d->w <= 0 || d->h <= 0) return 0;
    x = (int)d->x;
    y = (int)d->y;
    w = d->w;
    h = d->h;
    return (wx >= x && wx < x + w && wy >= y && wy < y + h) ? 1 : 0;
}

/* Pixel-perfect companion to gfx_sprite_hit_rect. Samples the sprite's
 * source alpha channel at the mouse-relative pixel (after inverse
 * scaling from drawn rect back to source rect, including SPRITEFRAME
 * / tile crop). Returns 1 if the rect test passes AND
 * alpha > alpha_cutoff, else 0. alpha_cutoff in [0, 255]; 0 means
 * "any non-fully-transparent pixel counts", 16 is a common value that
 * ignores PNG edge dust. Slots that didn't load with CPU-side pixels
 * (LoadImage failed) fall back to the bounding-rect result. */
int gfx_sprite_hit_pixel(int slot, int wx, int wy, int alpha_cutoff)
{
    GfxSpriteDrawPos *d;
    int x, y, w, h;
    int src_x, src_y, src_w, src_h;
    int local_x, local_y;
    int sx, sy;
    Color c;

    if (!gfx_sprite_hit_rect(slot, wx, wy)) return 0;
    d = &g_sprite_draw_pos[slot];
    x = (int)d->x;
    y = (int)d->y;
    w = d->w;
    h = d->h;
    if (w <= 0 || h <= 0) return 0;

    /* Resolve the active source rect (respects SPRITEFRAME / tile grid
     * / explicit crop). Always valid if the slot is loaded. */
    src_x = 0; src_y = 0; src_w = 0; src_h = 0;
    if (gfx_sprite_effective_source_rect(slot, &src_x, &src_y, &src_w, &src_h) != 0) return 0;
    if (src_w <= 0 || src_h <= 0) return 0;

    /* Drawn rect (w, h) may differ from source rect (src_w, src_h) when
     * SPRITEMODULATE applies a non-1 scale — invert the scale here so we
     * sample the right source pixel. Integer nearest-neighbour is fine
     * for a hit test; bilinear antialiasing doesn't change alpha enough
     * at the sub-pixel scale to matter. */
    local_x = wx - x;
    local_y = wy - y;
    sx = src_x + (local_x * src_w) / w;
    sy = src_y + (local_y * src_h) / h;

    pthread_mutex_lock(&g_sprite_mutex);
    if (!g_sprite_slots[slot].loaded || !g_sprite_slots[slot].src_image.data) {
        /* No CPU-side pixels: fall back to bounding rect (already
         * verified true above). */
        pthread_mutex_unlock(&g_sprite_mutex);
        return 1;
    }
    if (sx < 0 || sx >= g_sprite_slots[slot].src_image.width ||
        sy < 0 || sy >= g_sprite_slots[slot].src_image.height) {
        pthread_mutex_unlock(&g_sprite_mutex);
        return 0;
    }
    c = GetImageColor(g_sprite_slots[slot].src_image, sx, sy);
    pthread_mutex_unlock(&g_sprite_mutex);
    if (alpha_cutoff < 0) alpha_cutoff = 0;
    if (alpha_cutoff > 255) alpha_cutoff = 255;
    return ((int)c.a > alpha_cutoff) ? 1 : 0;
}

int gfx_sprite_at(int wx, int wy)
{
    int i, best = -1, best_z = 0;
    /* Axis-aligned bounding sweep over the per-slot cache. Highest Z
     * wins; ties broken by later-enqueued slot via index order (i > best
     * keeps the most recently hit slot on equal Z). */
    for (i = 0; i < GFX_SPRITE_MAX_SLOTS; i++) {
        GfxSpriteDrawPos *d = &g_sprite_draw_pos[i];
        if (!d->has_draw || d->w <= 0 || d->h <= 0) continue;
        if (wx < (int)d->x || wx >= (int)d->x + d->w) continue;
        if (wy < (int)d->y || wy >= (int)d->y + d->h) continue;
        if (best < 0 || d->z > best_z || (d->z == best_z && i > best)) {
            best = i;
            best_z = d->z;
        }
    }
    return best;
}

int gfx_sprite_is_mouse_over(int slot)
{
    /* World-space hit test against raw mouse (SCROLL unaware). The
     * BASIC-level ISMOUSEOVERSPRITE() wrapper in basic.c adds the
     * scroll offset so sprites at world (x,y) meet mouse coords that
     * live in screen space. This raw entry point is kept for callers
     * that already work in world space (tests, C-side demos). */
    return gfx_sprite_hit_rect(slot, gfx_mouse_x(), gfx_mouse_y());
}

void gfx_sprite_set_modulate(int slot, int alpha, int r, int g, int b, float scale_x, float scale_y)
{
    if (slot < 0 || slot >= GFX_SPRITE_MAX_SLOTS) {
        return;
    }
    if (alpha < 0) {
        alpha = 0;
    }
    if (alpha > 255) {
        alpha = 255;
    }
    if (r < 0) {
        r = 0;
    }
    if (r > 255) {
        r = 255;
    }
    if (g < 0) {
        g = 0;
    }
    if (g > 255) {
        g = 255;
    }
    if (b < 0) {
        b = 0;
    }
    if (b > 255) {
        b = 255;
    }
    if (scale_x <= 0.0f) {
        scale_x = 1.0f;
    }
    if (scale_y <= 0.0f) {
        scale_y = 1.0f;
    }
    pthread_mutex_lock(&g_sprite_mutex);
    g_sprite_slots[slot].mod_a = alpha;
    g_sprite_slots[slot].mod_r = r;
    g_sprite_slots[slot].mod_g = g;
    g_sprite_slots[slot].mod_b = b;
    g_sprite_slots[slot].mod_sx = scale_x;
    g_sprite_slots[slot].mod_sy = scale_y;
    g_sprite_slots[slot].mod_explicit = 1;
    pthread_mutex_unlock(&g_sprite_mutex);
}

int gfx_sprite_slot_width(int slot)
{
    int w = 0;
    if (slot < 0 || slot >= GFX_SPRITE_MAX_SLOTS) {
        return 0;
    }
    pthread_mutex_lock(&g_sprite_mutex);
    if (g_sprite_slots[slot].loaded) {
        if (g_sprite_slots[slot].tile_w > 0 && g_sprite_slots[slot].tile_h > 0) {
            w = g_sprite_slots[slot].tile_w;
        } else {
            w = g_sprite_slots[slot].tex.width;
        }
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
        if (g_sprite_slots[slot].tile_w > 0 && g_sprite_slots[slot].tile_h > 0) {
            h = g_sprite_slots[slot].tile_h;
        } else {
            h = g_sprite_slots[slot].tex.height;
        }
    }
    pthread_mutex_unlock(&g_sprite_mutex);
    return h;
}

int gfx_sprite_slot_tile_count(int slot)
{
    int n = 0;
    if (slot < 0 || slot >= GFX_SPRITE_MAX_SLOTS) {
        return 0;
    }
    pthread_mutex_lock(&g_sprite_mutex);
    if (g_sprite_slots[slot].loaded) {
        n = g_sprite_slots[slot].tile_count;
    }
    pthread_mutex_unlock(&g_sprite_mutex);
    return n;
}

int gfx_sprite_slot_sheet_cols(int slot)
{
    int v = 0;
    if (slot < 0 || slot >= GFX_SPRITE_MAX_SLOTS) return 0;
    pthread_mutex_lock(&g_sprite_mutex);
    if (g_sprite_slots[slot].loaded) v = g_sprite_slots[slot].tiles_x;
    pthread_mutex_unlock(&g_sprite_mutex);
    return v;
}
int gfx_sprite_slot_sheet_rows(int slot)
{
    int v = 0;
    if (slot < 0 || slot >= GFX_SPRITE_MAX_SLOTS) return 0;
    pthread_mutex_lock(&g_sprite_mutex);
    if (g_sprite_slots[slot].loaded) v = g_sprite_slots[slot].tiles_y;
    pthread_mutex_unlock(&g_sprite_mutex);
    return v;
}
int gfx_sprite_slot_sheet_cell_w(int slot)
{
    int v = 0;
    if (slot < 0 || slot >= GFX_SPRITE_MAX_SLOTS) return 0;
    pthread_mutex_lock(&g_sprite_mutex);
    if (g_sprite_slots[slot].loaded) v = g_sprite_slots[slot].tile_w;
    pthread_mutex_unlock(&g_sprite_mutex);
    return v;
}
int gfx_sprite_slot_sheet_cell_h(int slot)
{
    int v = 0;
    if (slot < 0 || slot >= GFX_SPRITE_MAX_SLOTS) return 0;
    pthread_mutex_lock(&g_sprite_mutex);
    if (g_sprite_slots[slot].loaded) v = g_sprite_slots[slot].tile_h;
    pthread_mutex_unlock(&g_sprite_mutex);
    return v;
}

/* TILEMAP DRAW: stamp a cols x rows grid of tile indices.
 *
 * Can't use gfx_sprite_enqueue_draw for this — that path mirrors the
 * last draw into g_sprite_slots[slot].draw_* as a single persistent
 * position, so N calls per slot per frame collapse to one visible
 * draw. Instead, we materialise a per-cell list that the compositor
 * iterates after the regular sprite loop. Replace semantics: each
 * TILEMAP DRAW call overwrites the prior list. */

#define GFX_TILEMAP_MAX_CELLS 4096

typedef struct {
    int slot;
    float x, y;
    int z;
    int sx, sy, sw, sh;
    float rot;   /* rotation in degrees, 0 = no rotation (SPRITE STAMP only) */
} GfxTilemapCell;

/* Double-buffered cell list. BASIC appends to g_tm_build; the
 * compositor reads g_tm_show. gfx_cells_flip() atomically copies
 * build → show, so the renderer never sees a half-populated frame
 * regardless of when its snapshot lands relative to BASIC's STAMP
 * loop. */
static GfxTilemapCell g_tm_build[GFX_TILEMAP_MAX_CELLS];
static int g_tm_build_count = 0;
static GfxTilemapCell g_tm_show[GFX_TILEMAP_MAX_CELLS];
static int g_tm_show_count = 0;
/* Legacy aliases for code that still reads the "old" names. Removed in
 * a subsequent cleanup. */
#define g_tm_cells g_tm_build
#define g_tm_count g_tm_build_count

/* TILEMAP DRAW and SPRITE STAMP both append to g_tm_cells; the
 * compositor drains the list each render pass. So a program that
 * rebuilds its scene every frame (the normal BASIC pattern) gets clean
 * per-frame semantics without an explicit clear, and callers can layer
 * a tilemap + sprite stamps into the same frame by calling both. */
void gfx_draw_tilemap(int slot, float x0, float y0, int cols, int rows, int z,
                      const int *tiles, int tile_count)
{
    static GfxTilemapCell scratch[GFX_TILEMAP_MAX_CELLS];
    int cell_w, cell_h;
    int r, c, i = 0, n = 0;
    int existing;
    if (!tiles || cols <= 0 || rows <= 0) return;
    cell_w = gfx_sprite_slot_sheet_cell_w(slot);
    cell_h = gfx_sprite_slot_sheet_cell_h(slot);
    if (cell_w <= 0 || cell_h <= 0) return;
    for (r = 0; r < rows && n < GFX_TILEMAP_MAX_CELLS; r++) {
        for (c = 0; c < cols && n < GFX_TILEMAP_MAX_CELLS; c++) {
            int idx, sx, sy, sw, sh;
            if (i >= tile_count) break;
            idx = tiles[i++];
            if (idx <= 0) continue;
            if (gfx_sprite_tile_source_rect(slot, idx, &sx, &sy, &sw, &sh) != 0) continue;
            scratch[n].slot = slot;
            scratch[n].x = x0 + (float)(c * cell_w);
            scratch[n].y = y0 + (float)(r * cell_h);
            scratch[n].z = z;
            scratch[n].sx = sx;
            scratch[n].sy = sy;
            scratch[n].sw = sw;
            scratch[n].sh = sh;
            scratch[n].rot = 0.0f;
            n++;
        }
    }
    /* Append under the mutex. If the list would overflow we drop the
     * excess rather than partially append — keeps the render stable. */
    pthread_mutex_lock(&g_sprite_mutex);
    existing = g_tm_count;
    if (existing + n > GFX_TILEMAP_MAX_CELLS) n = GFX_TILEMAP_MAX_CELLS - existing;
    if (n > 0) {
        memcpy(g_tm_cells + existing, scratch, (size_t)n * sizeof(GfxTilemapCell));
        g_tm_count = existing + n;
    }
    pthread_mutex_unlock(&g_sprite_mutex);
}

/* Clear the BUILD buffer only (the list BASIC is writing to). Used by
 * CLS so the program starts each tick with an empty scene. The SHOW
 * buffer is untouched — the renderer keeps displaying the previous
 * committed frame until VSYNC swaps. */
void gfx_cells_clear(void)
{
    pthread_mutex_lock(&g_sprite_mutex);
    g_tm_build_count = 0;
    pthread_mutex_unlock(&g_sprite_mutex);
}

/* Commit build → show atomically. VSYNC calls this after the program
 * has finished assembling a frame; the renderer now displays the new
 * cell list as a consistent unit. Build is left populated (the new
 * frame has been handed off); CLS at the top of the next tick wipes
 * it for the fresh rebuild. */
void gfx_cells_flip(void)
{
    pthread_mutex_lock(&g_sprite_mutex);
    g_tm_show_count = g_tm_build_count;
    if (g_tm_show_count > 0) {
        memcpy(g_tm_show, g_tm_build,
               (size_t)g_tm_show_count * sizeof(GfxTilemapCell));
    }
    pthread_mutex_unlock(&g_sprite_mutex);
}

/* SPRITE STAMP: append a single sprite-tile draw to the per-frame cell
 * list. `frame` is a 1-based tile index into the slot's sheet; 0 uses
 * the slot's current SPRITEFRAME (same default as DRAWSPRITE). */
void gfx_sprite_stamp(int slot, float x, float y, int frame, int z, float rot_deg)
{
    int sx, sy, sw, sh;
    int idx = (frame > 0) ? frame : gfx_sprite_get_draw_frame(slot);
    if (idx <= 0) idx = 1;
    if (gfx_sprite_tile_source_rect(slot, idx, &sx, &sy, &sw, &sh) != 0) {
        /* Fall back to slot's effective source rect (handles single-image
         * sprites that aren't a tile sheet). */
        sx = sy = 0;
        if (gfx_sprite_effective_source_rect(slot, &sx, &sy, &sw, &sh) != 0) return;
    }
    pthread_mutex_lock(&g_sprite_mutex);
    if (g_tm_count < GFX_TILEMAP_MAX_CELLS) {
        GfxTilemapCell *c = &g_tm_cells[g_tm_count++];
        c->slot = slot;
        c->x = x;
        c->y = y;
        c->z = z;
        c->sx = sx;
        c->sy = sy;
        c->sw = sw;
        c->sh = sh;
        c->rot = rot_deg;
    }
    pthread_mutex_unlock(&g_sprite_mutex);
}

int gfx_sprite_tile_source_rect(int slot, int tile_index_1based, int *sx, int *sy, int *sw, int *sh)
{
    GfxSpriteSlot *sl;
    int idx0, tx, ty;
    if (slot < 0 || slot >= GFX_SPRITE_MAX_SLOTS || !sx || !sy || !sw || !sh) {
        return -1;
    }
    pthread_mutex_lock(&g_sprite_mutex);
    sl = &g_sprite_slots[slot];
    if (!sl->loaded || sl->tile_w <= 0 || sl->tile_h <= 0 || sl->tiles_x <= 0 || sl->tile_count <= 0) {
        pthread_mutex_unlock(&g_sprite_mutex);
        return -1;
    }
    if (tile_index_1based < 1 || tile_index_1based > sl->tile_count) {
        pthread_mutex_unlock(&g_sprite_mutex);
        return -1;
    }
    idx0 = tile_index_1based - 1;
    tx = idx0 % sl->tiles_x;
    ty = idx0 / sl->tiles_x;
    *sx = tx * sl->tile_w;
    *sy = ty * sl->tile_h;
    *sw = sl->tile_w;
    *sh = sl->tile_h;
    pthread_mutex_unlock(&g_sprite_mutex);
    return 0;
}

void gfx_sprite_set_draw_frame(int slot, int frame_1based)
{
    GfxSpriteSlot *sl;
    if (slot < 0 || slot >= GFX_SPRITE_MAX_SLOTS) {
        return;
    }
    pthread_mutex_lock(&g_sprite_mutex);
    sl = &g_sprite_slots[slot];
    if (!sl->loaded || sl->tile_w <= 0 || sl->tile_h <= 0 || sl->tile_count <= 0) {
        pthread_mutex_unlock(&g_sprite_mutex);
        return;
    }
    if (frame_1based < 1) {
        frame_1based = 1;
    }
    if (frame_1based > sl->tile_count) {
        frame_1based = sl->tile_count;
    }
    sl->draw_frame = frame_1based;
    /* Invalidate any cached explicit crop — gfx_sprite_effective_source_rect
     * prefers (draw_sx, draw_sy, draw_sw, draw_sh) when they're non-zero, so
     * without this the first DRAWSPRITE's crop would stick forever and
     * subsequent SPRITEFRAME changes wouldn't advance the displayed tile. */
    sl->draw_sw = 0;
    sl->draw_sh = 0;
    pthread_mutex_unlock(&g_sprite_mutex);
}

int gfx_sprite_get_draw_frame(int slot)
{
    int f = 1;
    if (slot < 0 || slot >= GFX_SPRITE_MAX_SLOTS) {
        return 0;
    }
    pthread_mutex_lock(&g_sprite_mutex);
    if (g_sprite_slots[slot].loaded) {
        f = g_sprite_slots[slot].draw_frame;
        if (f < 1) {
            f = 1;
        }
    }
    pthread_mutex_unlock(&g_sprite_mutex);
    return f;
}

int gfx_sprite_effective_source_rect(int slot, int *sx, int *sy, int *sw, int *sh)
{
    GfxSpriteSlot *sl;
    int tw, th;
    if (slot < 0 || slot >= GFX_SPRITE_MAX_SLOTS || !sx || !sy || !sw || !sh) {
        return -1;
    }
    pthread_mutex_lock(&g_sprite_mutex);
    sl = &g_sprite_slots[slot];
    if (!sl->loaded) {
        pthread_mutex_unlock(&g_sprite_mutex);
        return -1;
    }
    if (sl->draw_sw > 0 && sl->draw_sh > 0) {
        *sx = sl->draw_sx;
        *sy = sl->draw_sy;
        *sw = sl->draw_sw;
        *sh = sl->draw_sh;
        pthread_mutex_unlock(&g_sprite_mutex);
        return 0;
    }
    if (sl->tile_w > 0 && sl->tile_h > 0 && sl->tile_count > 0) {
        int f = sl->draw_frame;
        int idx0, tx, ty;
        if (f < 1) {
            f = 1;
        }
        if (f > sl->tile_count) {
            f = sl->tile_count;
        }
        idx0 = f - 1;
        tx = idx0 % sl->tiles_x;
        ty = idx0 / sl->tiles_x;
        *sx = tx * sl->tile_w;
        *sy = ty * sl->tile_h;
        *sw = sl->tile_w;
        *sh = sl->tile_h;
        pthread_mutex_unlock(&g_sprite_mutex);
        return 0;
    }
    tw = sl->tex.width;
    th = sl->tex.height;
    *sx = sl->draw_sx;
    *sy = sl->draw_sy;
    *sw = tw - sl->draw_sx;
    *sh = th - sl->draw_sy;
    pthread_mutex_unlock(&g_sprite_mutex);
    return 0;
}

int gfx_sprite_slots_overlap_aabb(int slot_a, int slot_b)
{
    float ax, ay, aw, ah, bx, by, bw, bh;
    float ax2, ay2, bx2, by2;
    GfxSpriteSlot *a;
    GfxSpriteSlot *b;

    if (slot_a < 0 || slot_a >= GFX_SPRITE_MAX_SLOTS ||
        slot_b < 0 || slot_b >= GFX_SPRITE_MAX_SLOTS) {
        return 0;
    }
    pthread_mutex_lock(&g_sprite_mutex);
    a = &g_sprite_slots[slot_a];
    b = &g_sprite_slots[slot_b];
    if (!a->loaded || !a->visible || !a->draw_active ||
        !b->loaded || !b->visible || !b->draw_active) {
        pthread_mutex_unlock(&g_sprite_mutex);
        return 0;
    }
    {
        float swa, sha, swb, shb;
        int twa, tha, twb, thb;
        twa = a->tex.width;
        tha = a->tex.height;
        twb = b->tex.width;
        thb = b->tex.height;
        if (a->draw_sw <= 0 || a->draw_sh <= 0) {
            if (a->tile_w > 0 && a->tile_h > 0) {
                swa = (float)a->tile_w;
                sha = (float)a->tile_h;
            } else {
                swa = (float)(twa - a->draw_sx);
                sha = (float)(tha - a->draw_sy);
            }
        } else {
            swa = (float)a->draw_sw;
            sha = (float)a->draw_sh;
        }
        if (b->draw_sw <= 0 || b->draw_sh <= 0) {
            if (b->tile_w > 0 && b->tile_h > 0) {
                swb = (float)b->tile_w;
                shb = (float)b->tile_h;
            } else {
                swb = (float)(twb - b->draw_sx);
                shb = (float)(thb - b->draw_sy);
            }
        } else {
            swb = (float)b->draw_sw;
            shb = (float)b->draw_sh;
        }
        if (swa <= 0 || sha <= 0 || swb <= 0 || shb <= 0) {
            pthread_mutex_unlock(&g_sprite_mutex);
            return 0;
        }
        ax = a->draw_x;
        ay = a->draw_y;
        aw = swa * a->mod_sx;
        ah = sha * a->mod_sy;
        bx = b->draw_x;
        by = b->draw_y;
        bw = swb * b->mod_sx;
        bh = shb * b->mod_sy;
    }
    pthread_mutex_unlock(&g_sprite_mutex);

    ax2 = ax + aw;
    ay2 = ay + ah;
    bx2 = bx + bw;
    by2 = by + bh;
    if (ax2 <= bx || bx2 <= ax || ay2 <= by || by2 <= ay) {
        return 0;
    }
    return 1;
}

static int cmp_tm_cell_z(const void *a, const void *b)
{
    const GfxTilemapCell *ca = (const GfxTilemapCell *)a;
    const GfxTilemapCell *cb = (const GfxTilemapCell *)b;
    if (ca->z < cb->z) return -1;
    if (ca->z > cb->z) return 1;
    return 0;
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
            int tw = c->tile_w;
            int th = c->tile_h;
            int preserve_mod;
            int pma, pmr, pmg, pmb;
            float pmsx, pmsy;
            pthread_mutex_lock(&g_sprite_mutex);
            preserve_mod = g_sprite_slots[c->slot].mod_explicit;
            pma = g_sprite_slots[c->slot].mod_a;
            pmr = g_sprite_slots[c->slot].mod_r;
            pmg = g_sprite_slots[c->slot].mod_g;
            pmb = g_sprite_slots[c->slot].mod_b;
            pmsx = g_sprite_slots[c->slot].mod_sx;
            pmsy = g_sprite_slots[c->slot].mod_sy;
            pthread_mutex_unlock(&g_sprite_mutex);
            sprite_build_path(full, sizeof(full), c->path);
            pthread_mutex_lock(&g_sprite_mutex);
            if (g_sprite_slots[c->slot].loaded) {
                UnloadTexture(g_sprite_slots[c->slot].tex);
                if (g_sprite_slots[c->slot].src_image.data) {
                    UnloadImage(g_sprite_slots[c->slot].src_image);
                    g_sprite_slots[c->slot].src_image.data = NULL;
                }
                g_sprite_slots[c->slot].loaded = 0;
            }
            pthread_mutex_unlock(&g_sprite_mutex);
            {
                /* Load via Image so we keep CPU-side pixels for
                 * pixel-perfect ISMOUSEOVERSPRITE; texture is made
                 * from the image so GPU and CPU share one decode. */
                Image img = LoadImage(full);
                if (img.data) {
                    t = LoadTextureFromImage(img);
                    if (t.id == 0) { UnloadImage(img); img.data = NULL; }
                    pthread_mutex_lock(&g_sprite_mutex);
                    g_sprite_slots[c->slot].src_image = img;
                    pthread_mutex_unlock(&g_sprite_mutex);
                } else {
                    t.id = 0;
                    pthread_mutex_lock(&g_sprite_mutex);
                    g_sprite_slots[c->slot].src_image.data = NULL;
                    pthread_mutex_unlock(&g_sprite_mutex);
                }
            }
            pthread_mutex_lock(&g_sprite_mutex);
            if (t.id != 0) {
                /* Bilinear so PNG sprites scale smoothly (matches Canvas2D
                 * default imageSmoothingEnabled behaviour). Text/glyph
                 * render target keeps POINT for crisp pixel-art look. */
                SetTextureFilter(t, sprite_filter_mode());
                g_sprite_slots[c->slot].tex = t;
                g_sprite_slots[c->slot].loaded = 1;
                g_sprite_slots[c->slot].visible = 1;
                g_sprite_slots[c->slot].draw_active = 0;
                strncpy(g_sprite_slots[c->slot].src_path, full,
                        GFX_SPRITE_PATH_MAX - 1);
                g_sprite_slots[c->slot].src_path[GFX_SPRITE_PATH_MAX - 1] = '\0';
                g_sprite_slots[c->slot].tile_w = tw;
                g_sprite_slots[c->slot].tile_h = th;
                g_sprite_slots[c->slot].tiles_x = 0;
                g_sprite_slots[c->slot].tiles_y = 0;
                g_sprite_slots[c->slot].tile_count = 1;
                if (tw > 0 && th > 0 && t.width >= tw && t.height >= th) {
                    g_sprite_slots[c->slot].tiles_x = t.width / tw;
                    g_sprite_slots[c->slot].tiles_y = t.height / th;
                    g_sprite_slots[c->slot].tile_count =
                        g_sprite_slots[c->slot].tiles_x * g_sprite_slots[c->slot].tiles_y;
                    g_sprite_slots[c->slot].draw_frame = 1;
                } else {
                    g_sprite_slots[c->slot].tile_w = 0;
                    g_sprite_slots[c->slot].tile_h = 0;
                    g_sprite_slots[c->slot].draw_frame = 1;
                }
                if (preserve_mod) {
                    g_sprite_slots[c->slot].mod_a = pma;
                    g_sprite_slots[c->slot].mod_r = pmr;
                    g_sprite_slots[c->slot].mod_g = pmg;
                    g_sprite_slots[c->slot].mod_b = pmb;
                    g_sprite_slots[c->slot].mod_sx = pmsx;
                    g_sprite_slots[c->slot].mod_sy = pmsy;
                    g_sprite_slots[c->slot].mod_explicit = 1;
                    if (getenv("RGC_SPRITE_TRACE")) {
                        fprintf(stderr,
                            "[LOAD_DONE] slot=%d preserve_mod=1 mod_a=%d rgb=(%d,%d,%d) "
                            "scale=(%.2f,%.2f)\n",
                            c->slot, pma, pmr, pmg, pmb, pmsx, pmsy);
                    }
                } else {
                    g_sprite_slots[c->slot].mod_a = 255;
                    g_sprite_slots[c->slot].mod_r = 255;
                    g_sprite_slots[c->slot].mod_g = 255;
                    g_sprite_slots[c->slot].mod_b = 255;
                    g_sprite_slots[c->slot].mod_sx = 1.0f;
                    g_sprite_slots[c->slot].mod_sy = 1.0f;
                    g_sprite_slots[c->slot].mod_explicit = 0;
                }
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
                if (g_sprite_slots[c->slot].src_image.data) {
                    UnloadImage(g_sprite_slots[c->slot].src_image);
                    g_sprite_slots[c->slot].src_image.data = NULL;
                }
                g_sprite_slots[c->slot].loaded = 0;
                g_sprite_slots[c->slot].visible = 0;
                g_sprite_slots[c->slot].draw_active = 0;
                g_sprite_slots[c->slot].tile_w = g_sprite_slots[c->slot].tile_h = 0;
                g_sprite_slots[c->slot].tiles_x = g_sprite_slots[c->slot].tiles_y = 0;
                g_sprite_slots[c->slot].tile_count = 0;
                g_sprite_slots[c->slot].draw_frame = 0;
                g_sprite_slots[c->slot].mod_a = 255;
                g_sprite_slots[c->slot].mod_r = 255;
                g_sprite_slots[c->slot].mod_g = 255;
                g_sprite_slots[c->slot].mod_b = 255;
                g_sprite_slots[c->slot].mod_sx = 1.0f;
                g_sprite_slots[c->slot].mod_sy = 1.0f;
                g_sprite_slots[c->slot].mod_explicit = 0;
            }
            pthread_mutex_unlock(&g_sprite_mutex);
            break;
        case GFX_SQ_COPY: {
            /* Clone src GPU texture into dst slot (independent Texture2D).
             * If source has colour modulate applied, bake it into the pixel
             * data before uploading so dst has clean mods (255,255,255,255).
             * Best practice: apply SPRITEMODIFY before SPRITECOPY for
             * best performance — baked copies skip per-draw tint arithmetic. */
            Texture2D new_tex;
            Image img;
            GfxSpriteSlot src_snap;
            int dst = c->slot2;
            int bake;
            pthread_mutex_lock(&g_sprite_mutex);
            if (!g_sprite_slots[c->slot].loaded) {
                fprintf(stderr, "[COPY] src slot %d NOT loaded — aborting\n", c->slot);
                pthread_mutex_unlock(&g_sprite_mutex);
                break;
            }
            src_snap = g_sprite_slots[c->slot]; /* snapshot under lock */
            if (getenv("RGC_SPRITE_TRACE")) {
                fprintf(stderr, "[COPY] src=%d dst=%d path=%s c->mod_sx=%.2f src_snap.mod_sx=%.2f mod_a=%d\n",
                    c->slot, dst, src_snap.src_path, c->mod_sx, src_snap.mod_sx, c->mod_a);
            }
            pthread_mutex_unlock(&g_sprite_mutex);

            /* Only bake RGB — alpha is applied at draw time, not baked */
            bake = (c->mod_r != 255 || c->mod_g != 255 || c->mod_b != 255);

            /* Load from disk (CPU-side), optionally tint pixels, upload to GPU.
             * Avoids GPU readback and ImageColorTint() version dependency. */
            /* Always load from disk when path is available — LoadImageFromTexture
             * can lose palette-based alpha on GPU readback. */
            if (src_snap.src_path[0] != '\0') {
                img = LoadImage(src_snap.src_path);
            } else {
                img = LoadImageFromTexture(src_snap.tex);
            }
            /* Always ensure RGBA so alpha blending works correctly */
            if (img.data) {
                ImageFormat(&img, PIXELFORMAT_UNCOMPRESSED_R8G8B8A8);
            }
            if (bake && img.data) {
                unsigned char *px = (unsigned char *)img.data;
                int npix = img.width * img.height;
                int i;
                unsigned mr = (unsigned)c->mod_r;
                unsigned mg = (unsigned)c->mod_g;
                unsigned mb = (unsigned)c->mod_b;
                for (i = 0; i < npix; i++) {
                    px[i*4+0] = (unsigned char)((px[i*4+0] * mr + 127) / 255);
                    px[i*4+1] = (unsigned char)((px[i*4+1] * mg + 127) / 255);
                    px[i*4+2] = (unsigned char)((px[i*4+2] * mb + 127) / 255);
                    /* Don't bake alpha — preserve original transparency.
                     * Alpha mod is applied at draw time via DrawTexturePro tint. */
                }
            }
            new_tex = LoadTextureFromImage(img);
            /* Keep CPU-side pixel data for pixel-perfect ISMOUSEOVERSPRITE
             * on the copied slot. ImageCopy gives us an independent buffer
             * so src and dst don't share storage when src == dst. */
            Image dst_img = img.data ? ImageCopy(img) : (Image){0};
            UnloadImage(img);
            if (new_tex.id == 0) {
                if (dst_img.data) UnloadImage(dst_img);
                break;
            }
            SetTextureFilter(new_tex, sprite_filter_mode());

            pthread_mutex_lock(&g_sprite_mutex);
            if (g_sprite_slots[dst].loaded) {
                UnloadTexture(g_sprite_slots[dst].tex);
                if (g_sprite_slots[dst].src_image.data) {
                    UnloadImage(g_sprite_slots[dst].src_image);
                    g_sprite_slots[dst].src_image.data = NULL;
                }
            }
            /* Preserve any mods/scale explicitly set on dst by SPRITEMODULATE
             * after the copy was enqueued (interpreter runs ahead of render).
             * Use mod_explicit flag — 0 (uninitialized) scale is a valid value
             * and must NOT be treated as "explicitly set". */
            /* For self-copy (src==dst), don't preserve dst mods — they ARE the
             * source mods that we just baked into the pixels. */
            int   dst_mod_explicit = (dst != c->slot) ? g_sprite_slots[dst].mod_explicit : 0;
            float dst_sx = g_sprite_slots[dst].mod_sx;
            float dst_sy = g_sprite_slots[dst].mod_sy;
            int   dst_ma = g_sprite_slots[dst].mod_a;
            int   dst_mr = g_sprite_slots[dst].mod_r;
            int   dst_mg = g_sprite_slots[dst].mod_g;
            int   dst_mb = g_sprite_slots[dst].mod_b;
            g_sprite_slots[dst]          = src_snap;
            g_sprite_slots[dst].tex      = new_tex;
            /* src_snap.src_image pointed at src's CPU buffer; replace with
             * our independent ImageCopy so src can unload without
             * dangling dst's hit-test buffer. dst_img may be {0} if the
             * source image was unavailable — keep data=NULL in that case. */
            g_sprite_slots[dst].src_image = dst_img;
            g_sprite_slots[dst].draw_active = 0;
            /* Scale priority: dst explicit (SPRITEMODULATE ran on dst) > cmd
             * snapshot (captured from src at enqueue time). */
            if (dst_mod_explicit) {
                g_sprite_slots[dst].mod_sx = dst_sx;
                g_sprite_slots[dst].mod_sy = dst_sy;
            } else {
                /* Use scale captured at enqueue time — src slot may be unloaded by now */
                g_sprite_slots[dst].mod_sx = c->mod_sx;
                g_sprite_slots[dst].mod_sy = c->mod_sy;
            }
            if (bake) {
                /* Pixels are baked — reset mods unless dst got new ones */
                if (dst_mod_explicit) {
                    g_sprite_slots[dst].mod_a = dst_ma;
                    g_sprite_slots[dst].mod_r = dst_mr;
                    g_sprite_slots[dst].mod_g = dst_mg;
                    g_sprite_slots[dst].mod_b = dst_mb;
                    g_sprite_slots[dst].mod_explicit = 1;
                } else {
                    g_sprite_slots[dst].mod_r = 255;
                    g_sprite_slots[dst].mod_g = 255;
                    g_sprite_slots[dst].mod_b = 255;
                    /* Keep alpha mod for draw-time — it wasn't baked */
                    g_sprite_slots[dst].mod_a = c->mod_a;
                    g_sprite_slots[dst].mod_explicit = 0;
                }
            }
            memset(&g_sprite_draw_pos[dst], 0, sizeof(g_sprite_draw_pos[dst]));
            if (getenv("RGC_SPRITE_TRACE")) {
                fprintf(stderr,
                    "[COPY_DONE] src=%d dst=%d bake=%d src_snap.mod_a=%d c->mod_a=%d "
                    "dst.mod_a=%d dst.mod_explicit=%d dst.visible=%d dst.loaded=%d\n",
                    c->slot, dst, bake, src_snap.mod_a, c->mod_a,
                    g_sprite_slots[dst].mod_a, g_sprite_slots[dst].mod_explicit,
                    g_sprite_slots[dst].visible, g_sprite_slots[dst].loaded);
            }
            pthread_mutex_unlock(&g_sprite_mutex);
            break;
        }
        case GFX_SQ_DRAW:
            pthread_mutex_lock(&g_sprite_mutex);
            if (c->slot >= 0 && c->slot < GFX_SPRITE_MAX_SLOTS) {
                if (c->slot <= 3 && getenv("RGC_SPRITE_TRACE")) {
                    fprintf(stderr, "[DRAW] slot=%d x=%.0f y=%.0f z=%d loaded=%d\n",
                        c->slot, c->x, c->y, c->z, g_sprite_slots[c->slot].loaded);
                }
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

    pthread_mutex_lock(&g_sprite_mutex);
    g_sprite_gpu_done_seq = g_sprite_gpu_issue_seq;
    pthread_cond_broadcast(&g_sprite_gpu_cv);
    pthread_mutex_unlock(&g_sprite_mutex);
}

static void gfx_sprite_shutdown(void)
{
    int i;
    pthread_mutex_lock(&g_sprite_mutex);
    for (i = 0; i < GFX_SPRITE_MAX_SLOTS; i++) {
            if (g_sprite_slots[i].loaded) {
            UnloadTexture(g_sprite_slots[i].tex);
            if (g_sprite_slots[i].src_image.data) {
                UnloadImage(g_sprite_slots[i].src_image);
                g_sprite_slots[i].src_image.data = NULL;
            }
            g_sprite_slots[i].loaded = 0;
            g_sprite_slots[i].visible = 0;
            g_sprite_slots[i].draw_active = 0;
        }
    }
    g_sprite_q_count = 0;
    pthread_mutex_unlock(&g_sprite_mutex);
}

/* z_min/z_max filter which sprites to draw (inclusive).
 * Pass INT_MIN/INT_MAX to draw all. */
static void gfx_sprite_composite_range(const GfxVideoState *vs, RenderTexture2D target,
                                        int nat_w, int nat_h, int z_min, int z_max,
                                        int process_queue)
{
    GfxSpriteDraw draws[GFX_SPRITE_MAX_SLOTS];
    int nd = 0;
    int i;
    float scx = 0.0f, scy = 0.0f;

    if (vs) {
        scx = (float)vs->scroll_x;
        scy = (float)vs->scroll_y;
    }

    if (process_queue)
        gfx_sprite_process_queue();

    pthread_mutex_lock(&g_sprite_mutex);
    for (i = 0; i < GFX_SPRITE_MAX_SLOTS; i++) {
        if (!g_sprite_slots[i].loaded || !g_sprite_slots[i].visible ||
            !g_sprite_slots[i].draw_active) {
            continue;
        }
        if (g_sprite_slots[i].draw_z < z_min || g_sprite_slots[i].draw_z > z_max) {
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
        draws[nd].mod_a = g_sprite_slots[i].mod_a;
        draws[nd].mod_r = g_sprite_slots[i].mod_r;
        draws[nd].mod_g = g_sprite_slots[i].mod_g;
        draws[nd].mod_b = g_sprite_slots[i].mod_b;
        draws[nd].mod_sx = g_sprite_slots[i].mod_sx;
        draws[nd].mod_sy = g_sprite_slots[i].mod_sy;
        nd++;
    }
    pthread_mutex_unlock(&g_sprite_mutex);

    /* Peek at tilemap cell count so we enter the render block even when
     * no per-slot sprites are active — TILEMAP DRAW alone must still draw. */
    pthread_mutex_lock(&g_sprite_mutex);
    int tm_have = (g_tm_show_count > 0);
    pthread_mutex_unlock(&g_sprite_mutex);
    if (nd <= 0 && !tm_have) {
        return;
    }
    if (nd > 0) qsort(draws, (size_t)nd, sizeof(draws[0]), cmp_sprite_draw_z);

    BeginTextureMode(target);
    BeginBlendMode(BLEND_ALPHA);

    /* TILEMAP cells — render BEFORE sprites. Tilemap typically z=0 for
     * backgrounds; sprites (e.g. player at z=100) should draw on top.
     * If a program really wants tilemap-over-sprite, mix z explicitly.
     * (A full z-sorted merge of sprites + tiles is deferred; the two-
     * pass split is sufficient for the common background-vs-player
     * case.)
     * Auto-clear after rendering: cells are per-frame, callers must
     * re-submit each tick. Matches the one-position-per-slot sprite
     * model and lets programs layer a tilemap + stamps without state
     * leaking across frames. */
    {
        GfxTilemapCell local[GFX_TILEMAP_MAX_CELLS];
        int tn, ti;
        pthread_mutex_lock(&g_sprite_mutex);
        tn = g_tm_show_count;
        if (tn > GFX_TILEMAP_MAX_CELLS) tn = GFX_TILEMAP_MAX_CELLS;
        if (tn > 0) memcpy(local, g_tm_show, (size_t)tn * sizeof(GfxTilemapCell));
        pthread_mutex_unlock(&g_sprite_mutex);
        if (tn > 1) qsort(local, (size_t)tn, sizeof(GfxTilemapCell), cmp_tm_cell_z);
        for (ti = 0; ti < tn; ti++) {
            GfxTilemapCell *cell = &local[ti];
            Texture2D t;
            Rectangle src, dest;
            int s = cell->slot;
            if (s < 0 || s >= GFX_SPRITE_MAX_SLOTS) continue;
            if (cell->z < z_min || cell->z > z_max) continue;
            pthread_mutex_lock(&g_sprite_mutex);
            if (!g_sprite_slots[s].loaded || !g_sprite_slots[s].visible) {
                pthread_mutex_unlock(&g_sprite_mutex);
                continue;
            }
            t = g_sprite_slots[s].tex;
            pthread_mutex_unlock(&g_sprite_mutex);
            src = (Rectangle){ (float)cell->sx, (float)cell->sy,
                                (float)cell->sw, (float)cell->sh };
            /* When rotating, DrawTexturePro rotates around the origin
             * argument — offset by half the destination size so rotation
             * pivots around the sprite's centre, then add back to keep
             * the cell's (x, y) meaning "top-left of the un-rotated
             * quad". */
            if (cell->rot != 0.0f) {
                dest = (Rectangle){ cell->x - scx + (float)cell->sw * 0.5f,
                                     cell->y - scy + (float)cell->sh * 0.5f,
                                     (float)cell->sw, (float)cell->sh };
                DrawTexturePro(t, src, dest,
                               (Vector2){ (float)cell->sw * 0.5f,
                                           (float)cell->sh * 0.5f },
                               cell->rot, WHITE);
            } else {
                dest = (Rectangle){ cell->x - scx, cell->y - scy,
                                     (float)cell->sw, (float)cell->sh };
                DrawTexturePro(t, src, dest, (Vector2){ 0, 0 }, 0.0f, WHITE);
            }
        }
    }

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
        dest = (Rectangle){
            d->x - scx,
            d->y - scy,
            sw * d->mod_sx,
            sh * d->mod_sy
        };
        if (getenv("RGC_SPRITE_TRACE")) {
            fprintf(stderr,
                "[COMP] slot=%d tex.id=%u tex.fmt=%d src=(%.0f,%.0f,%.0f,%.0f) "
                "dest=(%.0f,%.0f,%.0f,%.0f) tint=(%d,%d,%d,%d)\n",
                s, t.id, t.format, sx, sy, sw, sh,
                dest.x, dest.y, dest.width, dest.height,
                d->mod_r, d->mod_g, d->mod_b, d->mod_a);
        }
        DrawTexturePro(
            t,
            src,
            dest,
            (Vector2){ 0, 0 },
            0.0f,
            (Color){
                (unsigned char)d->mod_r,
                (unsigned char)d->mod_g,
                (unsigned char)d->mod_b,
                (unsigned char)d->mod_a
            });
    }

    EndBlendMode();
    EndTextureMode();
    (void)nat_w;
    (void)nat_h;
}

/* ── IMAGE GRAB from visible framebuffer ───────────────────────────
 *
 * Called from the BASIC interpreter thread (via statement_image_grab).
 * Blocks until the render thread fulfils the grab, which happens right
 * after the next gfx_sprite_composite_range (i.e. with the fully-
 * composited target: bitmap + text + sprites + tilemap cells). */
/* Forward decl so the WASM inline path can share the readback helper. */
static int gfx_raylib_readback_into_slot(RenderTexture2D target,
                                         int slot, int sx, int sy, int sw, int sh);

#ifdef __EMSCRIPTEN__
/* Forward: defined after g_wasm_target / g_wasm_inited are declared
 * further down the file. Keeps the WASM inline-grab path's texture
 * readback using the canonical globals without needing to reorder
 * their (static) definitions. */
static int gfx_wasm_inline_grab_into_slot(int slot, int sx, int sy, int sw, int sh);
#endif

int gfx_grab_visible_rgba(int slot, int sx, int sy, int sw, int sh)
{
    int rc;
    if (sw <= 0 || sh <= 0) return -1;
#ifdef __EMSCRIPTEN__
    /* Browser WASM is single-threaded (Asyncify). The interpreter and
     * the render loop run on the same thread, so a cond_wait here would
     * deadlock — the service callback could never fire. Instead, read
     * back from g_wasm_target right now; the most recent VSYNC has
     * already composited the target, so its pixels are current. */
    return gfx_wasm_inline_grab_into_slot(slot, sx, sy, sw, sh);
#else
    pthread_mutex_lock(&g_grab_mtx);
    g_grab_slot = slot;
    g_grab_sx = sx; g_grab_sy = sy;
    g_grab_sw = sw; g_grab_sh = sh;
    g_grab_pending = 1;
    g_grab_result = -1;
    while (g_grab_pending) {
        pthread_cond_wait(&g_grab_cv, &g_grab_mtx);
    }
    rc = g_grab_result;
    pthread_mutex_unlock(&g_grab_mtx);
    return rc;
#endif
}

/* Shared GPU → slot.rgba readback (desktop service + WASM inline). */
static int gfx_raylib_readback_into_slot(RenderTexture2D target,
                                         int slot, int sx, int sy, int sw, int sh)
{
    int rc = -1;
    Image img = LoadImageFromTexture(target.texture);
    if (img.data) {
        if (img.format != PIXELFORMAT_UNCOMPRESSED_R8G8B8A8) {
            ImageFormat(&img, PIXELFORMAT_UNCOMPRESSED_R8G8B8A8);
        }
        ImageFlipVertical(&img);

        if (gfx_image_new_rgba(slot, sw, sh) == 0) {
            uint8_t *dst = gfx_image_rgba_buffer(slot);
            const uint8_t *src = (const uint8_t *)img.data;
            int y;
            memset(dst, 0, (size_t)sw * (size_t)sh * 4u);
            for (y = 0; y < sh; y++) {
                int isy = sy + y;
                int x0 = sx, x1 = sx + sw;
                if (isy < 0 || isy >= img.height) continue;
                if (x0 < 0) x0 = 0;
                if (x1 > img.width) x1 = img.width;
                if (x1 <= x0) continue;
                memcpy(dst + ((size_t)y * (size_t)sw + (size_t)(x0 - sx)) * 4u,
                       src + ((size_t)isy * (size_t)img.width + (size_t)x0) * 4u,
                       (size_t)(x1 - x0) * 4u);
            }
            rc = 0;
        }
        UnloadImage(img);
    }
    return rc;
}

/* Called on the render thread after sprite composite, before the
 * window draw. Desktop-only: if a grab is pending, fulfil it via the
 * shared readback helper. WASM path runs the same helper inline from
 * the interpreter in gfx_grab_visible_rgba (single thread, no wait). */
#ifndef __EMSCRIPTEN__
static void gfx_raylib_service_grab(RenderTexture2D target, int nat_w, int nat_h)
{
    pthread_mutex_lock(&g_grab_mtx);
    if (!g_grab_pending) {
        pthread_mutex_unlock(&g_grab_mtx);
        return;
    }
    int slot = g_grab_slot;
    int sx = g_grab_sx, sy = g_grab_sy;
    int sw = g_grab_sw, sh = g_grab_sh;
    int rc = gfx_raylib_readback_into_slot(target, slot, sx, sy, sw, sh);
    g_grab_result = rc;
    g_grab_pending = 0;
    pthread_cond_signal(&g_grab_cv);
    pthread_mutex_unlock(&g_grab_mtx);
    (void)nat_w;
    (void)nat_h;
}
#endif
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

/* Palette is now a writable table in gfx_video.c (gfx_c64_palette_rgb).
 * Legacy `c64_palette(i)` subscript call-sites continue to work via a
 * raylib-Color wrapper macro, but the underlying bytes can be retuned
 * at runtime by PALETTESET / PALETTERESET and renderers pick up the
 * change on the next frame. */
static inline Color c64_palette_at(int idx) {
    const uint8_t *e = gfx_c64_palette_rgb[idx & 0x0F];
    return (Color){ e[0], e[1], e[2], e[3] };
}
#define c64_palette(i) c64_palette_at(i)

/* Background colour comes from video state (s->bg_color). */

#include "gfx_charrom.h"


/* ── Renderer (shared by both modes) ──────────────────────────────── */

/* Persistent CPU-side pixel buffer + GPU texture, reused across frames.
 * Avoid per-pixel DrawPixel() draw calls — fill buffer, UpdateTexture once,
 * then one DrawTexture into the RenderTexture2D target. */
static Color   *g_pixbuf      = NULL;
static int      g_pixbuf_w    = 0;
static int      g_pixbuf_h    = 0;
static Texture2D g_pixtex     = { 0 };
static int      g_pixtex_w    = 0;
static int      g_pixtex_h    = 0;

static void pixbuf_shutdown(void)
{
    if (g_pixtex.id != 0) {
        UnloadTexture(g_pixtex);
        g_pixtex = (Texture2D){ 0 };
    }
    free(g_pixbuf);
    g_pixbuf = NULL;
    g_pixbuf_w = g_pixbuf_h = 0;
    g_pixtex_w = g_pixtex_h = 0;
}

static Color *ensure_pixbuf(int w, int h)
{
    if (w != g_pixbuf_w || h != g_pixbuf_h || g_pixbuf == NULL) {
        free(g_pixbuf);
        g_pixbuf = (Color *)malloc((size_t)w * (size_t)h * sizeof(Color));
        g_pixbuf_w = w;
        g_pixbuf_h = h;
    }
    if (w != g_pixtex_w || h != g_pixtex_h || g_pixtex.id == 0) {
        if (g_pixtex.id != 0) {
            UnloadTexture(g_pixtex);
        }
        Image img = {
            .data    = g_pixbuf,
            .width   = w,
            .height  = h,
            .mipmaps = 1,
            .format  = PIXELFORMAT_UNCOMPRESSED_R8G8B8A8,
        };
        g_pixtex = LoadTextureFromImage(img);
        g_pixtex_w = w;
        g_pixtex_h = h;
    }
    return g_pixbuf;
}

static void render_text_screen(const GfxVideoState *s,
                               RenderTexture2D target)
{
    int row, col, y, x;
    int cols = (s->cols == 40 || s->cols == 80) ? (int)s->cols : 40;
    int fb_w = cols * CELL_W;
    int fb_h = SCREEN_ROWS * CELL_H;
    int sx = (int)s->scroll_x;
    int sy = (int)s->scroll_y;
    Color bg_global = c64_palette(s->bg_color & 0x0F);
    Color *buf = ensure_pixbuf(fb_w, fb_h);

    /* Clear with background. */
    {
        int total = fb_w * fb_h;
        int i;
        for (i = 0; i < total; i++) {
            buf[i] = bg_global;
        }
    }

    for (row = 0; row < SCREEN_ROWS; row++) {
        for (col = 0; col < cols; col++) {
            int idx = row * cols + col;
            uint8_t sc = s->screen[idx];
            uint8_t ci = s->color[idx] & 0x0F;
            uint8_t bgi = s->bgcolor[idx] & 0x0F;
            const uint8_t *glyph;
            Color fg = c64_palette(ci);
            Color bg = c64_palette(bgi);
            int reversed = (sc & 0x80) ? 1 : 0;
            int base_px = col * CELL_W - sx;
            int base_py = row * CELL_H - sy;

            glyph = &s->chars[(uint8_t)(sc & 0x7F) * 8];

            for (y = 0; y < CELL_H; y++) {
                int py = base_py + y;
                uint8_t bits = glyph[y];
                if (py < 0 || py >= fb_h) {
                    continue;
                }
                for (x = 0; x < CELL_W; x++) {
                    int px = base_px + x;
                    int on = (bits & (0x80 >> x)) ? 1 : 0;
                    if (px < 0 || px >= fb_w) {
                        continue;
                    }
                    buf[py * fb_w + px] = (on ^ reversed) ? fg : bg;
                }
            }
        }
    }

    UpdateTexture(g_pixtex, buf);
    BeginTextureMode(target);
    ClearBackground(bg_global);
    DrawTexture(g_pixtex, 0, 0, WHITE);
    EndTextureMode();
}

/* SCREEN 3 — 320×200 8bpp indexed plane. Each pixel stores a 0..255
 * palette index, sampled through gfx_c64_palette_rgb at composite so
 * PALETTESET / PALETTEROTATE take effect next frame. */
static void render_indexed_screen(const GfxVideoState *s, RenderTexture2D target,
                                  int native_w)
{
    int y, x, off_x;
    int sx = (int)s->scroll_x;
    int sy = (int)s->scroll_y;
    int fb_w = native_w;
    int fb_h = NATIVE_H;
    Color *buf = ensure_pixbuf(fb_w, fb_h);
    Color bg = c64_palette(s->bg_color);
    const uint8_t *src = (s->double_buffer) ? s->bitmap_color_show : s->bitmap_color;

    off_x = (native_w - (int)GFX_BITMAP_WIDTH) / 2;
    if (off_x < 0) off_x = 0;

    {
        int total = fb_w * fb_h;
        int i;
        for (i = 0; i < total; i++) buf[i] = bg;
    }

    for (y = 0; y < (int)GFX_BITMAP_HEIGHT; y++) {
        int py = y - sy;
        if (py < 0 || py >= fb_h) continue;
        for (x = 0; x < (int)GFX_BITMAP_WIDTH; x++) {
            int px = off_x + x - sx;
            uint8_t idx;
            const uint8_t *e;
            if (px < 0 || px >= fb_w) continue;
            idx = src[y * GFX_BITMAP_WIDTH + x];
            e = gfx_c64_palette_rgb[idx];
            buf[py * fb_w + px].r = e[0];
            buf[py * fb_w + px].g = e[1];
            buf[py * fb_w + px].b = e[2];
            buf[py * fb_w + px].a = e[3];
        }
    }

    UpdateTexture(g_pixtex, buf);
    BeginTextureMode(target);
    ClearBackground(bg);
    DrawTexture(g_pixtex, 0, 0, WHITE);
    EndTextureMode();
}

/* SCREEN 2 — 320×200 RGBA plane drawn as a flat texture. Bypasses the
 * palette lookup path entirely; each pixel carries its own RGBA. Still
 * respects SCROLL and letterbox-x offset. */
static void render_rgba_screen(const GfxVideoState *s, RenderTexture2D target,
                               int native_w)
{
    int y, x, off_x;
    int sx = (int)s->scroll_x;
    int sy = (int)s->scroll_y;
    /* Target dimensions now come from the RenderTexture2D — it's 320×200
     * for SCREEN 2 and 640×400 for SCREEN 4 (the caller swaps the target
     * in when screen_mode changes). Source dimensions come from the
     * state's rgba_w/h, which the helpers write through. */
    int fb_w = target.texture.width  > 0 ? target.texture.width  : native_w;
    int fb_h = target.texture.height > 0 ? target.texture.height : NATIVE_H;
    int src_w = (int)s->rgba_w;
    int src_h = (int)s->rgba_h;
    Color *buf = ensure_pixbuf(fb_w, fb_h);
    Color bg = { s->bgrgba_r, s->bgrgba_g, s->bgrgba_b, s->bgrgba_a };
    const uint8_t *src = (s->double_buffer && s->bitmap_rgba_show) ? s->bitmap_rgba_show : s->bitmap_rgba;
    (void)native_w;

    off_x = (fb_w - src_w) / 2;
    if (off_x < 0) off_x = 0;

    {
        int total = fb_w * fb_h;
        int i;
        for (i = 0; i < total; i++) buf[i] = bg;
    }

    if (!src) {
        UpdateTexture(g_pixtex, buf);
        BeginTextureMode(target);
        ClearBackground(bg);
        DrawTexture(g_pixtex, 0, 0, WHITE);
        EndTextureMode();
        return;
    }

    for (y = 0; y < src_h; y++) {
        int py = y - sy;
        if (py < 0 || py >= fb_h) continue;
        for (x = 0; x < src_w; x++) {
            int px = off_x + x - sx;
            unsigned off;
            if (px < 0 || px >= fb_w) continue;
            off = ((unsigned)y * (unsigned)src_w + (unsigned)x) * 4u;
            buf[py * fb_w + px].r = src[off + 0];
            buf[py * fb_w + px].g = src[off + 1];
            buf[py * fb_w + px].b = src[off + 2];
            buf[py * fb_w + px].a = src[off + 3];
        }
    }

    UpdateTexture(g_pixtex, buf);
    BeginTextureMode(target);
    ClearBackground(bg);
    DrawTexture(g_pixtex, 0, 0, WHITE);
    EndTextureMode();
}

/* 320×200 hi-res: MSB of each byte is the leftmost pixel in that group of 8. */
static void render_bitmap_screen(const GfxVideoState *s, RenderTexture2D target,
                                 int native_w)
{
    int y, x, off_x;
    int sx = (int)s->scroll_x;
    int sy = (int)s->scroll_y;
    Color fg_fallback = c64_palette(s->bitmap_fg & 0x0F);
    Color bg = c64_palette(s->bg_color & 0x0F);
    int fb_w = native_w;
    int fb_h = NATIVE_H;
    Color *buf = ensure_pixbuf(fb_w, fb_h);
    int main_slot_visible = (s->screen_show == 0) ||
                            (s->double_buffer && s->screen_show == 1);

    off_x = (native_w - (int)GFX_BITMAP_WIDTH) / 2;
    if (off_x < 0) {
        off_x = 0;
    }

    /* Clear with background. */
    {
        int total = fb_w * fb_h;
        int i;
        for (i = 0; i < total; i++) {
            buf[i] = bg;
        }
    }

    for (y = 0; y < (int)GFX_BITMAP_HEIGHT; y++) {
        int py = y - sy;
        if (py < 0 || py >= fb_h) {
            continue;
        }
        for (x = 0; x < (int)GFX_BITMAP_WIDTH; x++) {
            /* Display plane: reads bitmap_show[] when the program
             * enabled DOUBLEBUFFER ON, otherwise bitmap[]. */
            int on = gfx_bitmap_get_show_pixel(s, (unsigned)x, (unsigned)y);
            int px = off_x + x - sx;
            Color fg;
            if (px < 0 || px >= fb_w) {
                continue;
            }
            if (on) {
                /* Per-pixel palette lookup for the main bitmap (slot 0
                 * or the DOUBLEBUFFER shadow on slot 1). Non-zero colour
                 * index wins; zero falls back to the live bitmap_fg
                 * register (preserves legacy "one pen" behaviour for
                 * programs that POKE bytes directly or run pre-colour-
                 * plane code). Non-main SCREEN BUFFER slots have no
                 * colour companion and always use the fallback. */
                int idx = 0;
                if (main_slot_visible) {
                    idx = gfx_bitmap_get_show_color(s, (unsigned)x, (unsigned)y);
                }
                fg = idx ? c64_palette(idx & 0x0F) : fg_fallback;
                buf[py * fb_w + px] = fg;
            } else {
                buf[py * fb_w + px] = bg;
            }
        }
    }

    UpdateTexture(g_pixtex, buf);
    BeginTextureMode(target);
    ClearBackground(bg);
    DrawTexture(g_pixtex, 0, 0, WHITE);
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

#if !defined(__EMSCRIPTEN__)
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
                "Usage: %s [-petscii] [-charset upper|lower|c64-*|pet-*] [-palette ansi|c64] [-columns 80] [-memory c64|pet|default] [-gfx-title \"title\"] [-gfx-border N] [-fullscreen] <program.bas> [args...]\n",
                argv[0]);
        return 1;
    }
    prog_path = argv[prog_idx];

    gfx_video_init(&vs);
    vs.charset_lowercase = (uint8_t)(petscii_get_lowercase() ? 1 : 0);
    vs.charrom_family = (uint8_t)(basic_get_charrom_family() ? 1 : 0);
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

        SetTraceLogLevel(LOG_INFO);
        {
            const char *title = basic_get_gfx_window_title();
            InitWindow(win_w, win_h, title ? title : "RGC-BASIC GFX");
        }
        SetTargetFPS(60);
        target = LoadRenderTexture(nat_w, nat_h);
        /* Upscale filter is always POINT: the render target is 320×200 and
         * bilinear here would smear every source pixel across a 4×4 window,
         * giving blurred squares that look nothing like antialiasing. True
         * per-primitive AA needs either a Wu-line rasteriser or super-
         * sampling and is tracked in docs/rgc-blitter-surface-spec.md.
         * ANTIALIAS now only toggles the sprite filter — that's where
         * rotated / scaled PNG sprites benefit from bilinear sampling. */
        SetTextureFilter(target.texture, TEXTURE_FILTER_POINT);

        /* -fullscreen: stretch to full monitor, preserve aspect (letterbox).
         * Target monitor dims become the window; draw-rect computed per frame. */
        if (basic_get_gfx_fullscreen()) {
            int mon = GetCurrentMonitor();
            int mw = GetMonitorWidth(mon);
            int mh = GetMonitorHeight(mon);
            if (mw > 0 && mh > 0) {
                SetWindowSize(mw, mh);
                win_w = mw;
                win_h = mh;
            }
            if (!IsWindowFullscreen()) {
                ToggleFullscreen();
            }
            /* Don't hide the system cursor automatically — programs that
             * want a clean retro screen still call HIDECURSOR, but
             * mouse-driven UIs (SPRITEAT drag-and-drop, menu buttons)
             * need the pointer visible in fullscreen too. */
        }
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
        static uint8_t last_charrom_family = 0xFF;
        vs.charrom_family = (uint8_t)(basic_get_charrom_family() ? 1 : 0);
        if (last_charset != vs.charset_lowercase || last_charrom_family != vs.charrom_family) {
            gfx_load_default_charrom(&vs);
            last_charset = vs.charset_lowercase;
            last_charrom_family = vs.charrom_family;
        }
        /* 60 Hz jiffy clock (C64-style TI), wraps every 24 hours. */
        gfx_video_advance_ticks60(&vs, 1u);

        /* Pump all loaded music streams once per frame. raudio
         * decodes on demand and will underflow (silence) within a
         * second without this tick. Cheap when no music is loaded. */
        gfx_music_tick();

        /* ANTIALIAS: apply pending filter change on the main (GL) thread.
         * gfx_set_antialias() just flips the flag; this walks loaded
         * sprite textures + the render target and calls SetTextureFilter
         * when the desired mode has changed since the last frame. */
        if (g_antialias != g_antialias_applied) {
            int mode = sprite_filter_mode();
            int si;
            pthread_mutex_lock(&g_sprite_mutex);
            for (si = 0; si < GFX_SPRITE_MAX_SLOTS; si++) {
                if (g_sprite_slots[si].loaded) {
                    SetTextureFilter(g_sprite_slots[si].tex, mode);
                }
            }
            pthread_mutex_unlock(&g_sprite_mutex);
            /* Leave the main render target on POINT — see the init comment
             * at LoadRenderTexture. Bilinear at the 320×200 -> window
             * upscale smears whole pixel squares and misreads as
             * antialiasing. Only sprite textures participate in the
             * ANTIALIAS toggle now. */
            g_antialias_applied = g_antialias;
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
        /* Punctuation — set both unshifted and shifted ASCII so BASIC can
         * poll either via KEYPRESS/KEYDOWN without caring about modifier state. */
        if (IsKeyDown(KEY_EQUAL))        { vs.key_state['='] = 1; vs.key_state['+'] = 1; }
        if (IsKeyDown(KEY_MINUS))        { vs.key_state['-'] = 1; vs.key_state['_'] = 1; }
        if (IsKeyDown(KEY_COMMA))        { vs.key_state[','] = 1; vs.key_state['<'] = 1; }
        if (IsKeyDown(KEY_PERIOD))       { vs.key_state['.'] = 1; vs.key_state['>'] = 1; }
        if (IsKeyDown(KEY_SLASH))        { vs.key_state['/'] = 1; vs.key_state['?'] = 1; }
        if (IsKeyDown(KEY_SEMICOLON))    { vs.key_state[';'] = 1; vs.key_state[':'] = 1; }
        if (IsKeyDown(KEY_APOSTROPHE))   { vs.key_state['\''] = 1; vs.key_state['"'] = 1; }
        if (IsKeyDown(KEY_LEFT_BRACKET)) { vs.key_state['['] = 1; vs.key_state['{'] = 1; }
        if (IsKeyDown(KEY_RIGHT_BRACKET)){ vs.key_state[']'] = 1; vs.key_state['}'] = 1; }
        if (IsKeyDown(KEY_BACKSLASH))    { vs.key_state['\\'] = 1; vs.key_state['|'] = 1; }
        if (IsKeyDown(KEY_GRAVE))        { vs.key_state['`'] = 1; vs.key_state['~'] = 1; }
        if (IsKeyDown(KEY_TAB))          vs.key_state['\t'] = 1;

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

        /* SCREEN 4 (GFX_SCREEN_RGBA_HI) needs a 640×400 render target so
         * the wider canvas isn't sub-sampled down to nat_w × nat_h. Swap
         * the target out when the mode changes; reload keeps the POINT
         * filter so hi-res draws stay crisp. */
        {
            int want_tw = (vs.screen_mode == GFX_SCREEN_RGBA_HI) ? (int)GFX_RGBA_HI_W : nat_w;
            int want_th = (vs.screen_mode == GFX_SCREEN_RGBA_HI) ? (int)GFX_RGBA_HI_H : nat_h;
            if (target.texture.width != want_tw || target.texture.height != want_th) {
                UnloadRenderTexture(target);
                target = LoadRenderTexture(want_tw, want_th);
                SetTextureFilter(target.texture, TEXTURE_FILTER_POINT);
            }
        }

        if (vs.screen_mode == GFX_SCREEN_INDEXED) {
            render_indexed_screen(&vs, target, nat_w);
        } else if (vs.screen_mode == GFX_SCREEN_RGBA ||
                   vs.screen_mode == GFX_SCREEN_RGBA_HI) {
            render_rgba_screen(&vs, target, nat_w);
        } else if (vs.screen_mode == GFX_SCREEN_BITMAP) {
            render_bitmap_screen(&vs, target, nat_w);
        } else {
            render_text_screen(&vs, target);
        }
        /* All sprites draw on top (z-sorted among themselves).
         * Negative z = behind positive z, but all are above text. */
        gfx_sprite_composite_range(&vs, target, nat_w, nat_h, -32768, 32767, 1);

        /* Fulfil any pending IMAGE GRAB now that target holds the fully
         * composited frame. Desktop-only: WASM does the readback inline
         * from the interpreter (single thread, no cond_wait). */
#ifndef __EMSCRIPTEN__
        gfx_raylib_service_grab(target, nat_w, nat_h);
#endif

        /* Compute destination rect for this frame.
         * Fullscreen: letterbox — preserve target:target aspect, black/border bars.
         * Windowed: honour -gfx-border pixel inset.
         * Source rect uses the live target dimensions so SCREEN 4 (640×400)
         * blits the wider canvas to the window without cropping to nat_w. */
        {
            int tex_w = target.texture.width;
            int tex_h = target.texture.height;
            int fullscreen = basic_get_gfx_fullscreen();
            int cur_w = fullscreen ? GetScreenWidth()  : win_w;
            int cur_h = fullscreen ? GetScreenHeight() : win_h;
            float dx, dy, dw, dh;

            if (fullscreen) {
                float tex_ar = (float)tex_w / (float)tex_h;
                float scr_ar = (float)cur_w / (float)cur_h;
                if (scr_ar > tex_ar) {
                    dh = (float)cur_h;
                    dw = dh * tex_ar;
                    dx = ((float)cur_w - dw) * 0.5f;
                    dy = 0.0f;
                } else {
                    dw = (float)cur_w;
                    dh = dw / tex_ar;
                    dx = 0.0f;
                    dy = ((float)cur_h - dh) * 0.5f;
                }
            } else {
                int border = basic_get_gfx_border();
                dx = (float)border;
                dy = (float)border;
                dw = (float)(cur_w - 2 * border);
                dh = (float)(cur_h - 2 * border);
                if (dw < 1) dw = 1;
                if (dh < 1) dh = 1;
            }

            gfx_mouse_raylib_poll(tex_w, tex_h, dx, dy, dx + dw, dy + dh);

            BeginDrawing();
            {
                int bc = basic_get_gfx_border_color();
                uint8_t ci = (bc >= 0 && bc <= 15) ? (uint8_t)bc : (vs.bg_color & 0x0F);
                if (fullscreen || basic_get_gfx_border() > 0) {
                    ClearBackground(fullscreen && bc < 0 ? BLACK : c64_palette(ci));
                }
                DrawTexturePro(
                    target.texture,
                    (Rectangle){ 0, 0, (float)tex_w, -(float)tex_h },
                    (Rectangle){ dx, dy, dw, dh },
                    (Vector2){ 0, 0 }, 0.0f, WHITE);
            }
            EndDrawing();
        }
    }

    /* Flush any pending LOAD/UNLOAD so worker threads never block on cond wait after halt,
     * and OpenGL texture ops stay on this (main) thread. */
    gfx_sprite_process_queue();

    closed_by_user = WindowShouldClose() && !basic_halted();

    gfx_sprite_shutdown();
    gfx_sound_shutdown();
    pixbuf_shutdown();
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
#endif /* !__EMSCRIPTEN__ */

/* ══════════════════════════════════════════════════════════════════════
 *  Emscripten / raylib-wasm entry points.
 *
 *  Same renderer source as native, but no pthread, no WindowShouldClose
 *  loop. Interpreter runs on the main thread via Asyncify; render is driven
 *  by the existing wasm_gfx_refresh_js() hook that the interpreter already
 *  calls after each state change.
 * ══════════════════════════════════════════════════════════════════════ */
#if defined(__EMSCRIPTEN__) && defined(GFX_USE_RAYLIB)

#include <emscripten.h>

/* basic.c provides these but no public header declares them for the wasm
 * variant; forward-declare locally to keep this block self-contained. */
extern void basic_load(const char *path);
extern void basic_run(const char *path, int nargs, char **args);
extern int  basic_apply_arg_string(const char *argline);

static GfxVideoState g_wasm_vs;
static RenderTexture2D g_wasm_target;
static int g_wasm_inited = 0;
static int g_wasm_nat_w = NATIVE_W;
static int g_wasm_nat_h = NATIVE_H;

/* WASM IMAGE GRAB: synchronous readback from g_wasm_target. Safe
 * because the browser is single-threaded (Asyncify) — the most recent
 * VSYNC already composited the target before control returned to the
 * interpreter. Declared forward at the top of the file; definition
 * lives here so it can see the static globals. */
static int gfx_wasm_inline_grab_into_slot(int slot, int sx, int sy, int sw, int sh)
{
    if (!g_wasm_inited) return -1;
    return gfx_raylib_readback_into_slot(g_wasm_target, slot, sx, sy, sw, sh);
}

static void wasm_raylib_init_once(void)
{
    int cols;
    const char *title;
    if (g_wasm_inited) {
        return;
    }
    gfx_video_init(&g_wasm_vs);
    g_wasm_vs.charset_lowercase = (uint8_t)(petscii_get_lowercase() ? 1 : 0);
    g_wasm_vs.charrom_family = (uint8_t)(basic_get_charrom_family() ? 1 : 0);
    gfx_load_default_charrom(&g_wasm_vs);
    memset(g_wasm_vs.screen, 32, GFX_TEXT_SIZE);
    memset(g_wasm_vs.color, 14, GFX_COLOR_SIZE);
    basic_set_video(&g_wasm_vs);

    cols = g_wasm_vs.cols ? (int)g_wasm_vs.cols : 40;
    g_wasm_nat_w = cols * CELL_W;
    g_wasm_nat_h = SCREEN_ROWS * CELL_H;

    SetTraceLogLevel(LOG_INFO);
    title = basic_get_gfx_window_title();
    /* GL backing = native * SCALE so -gfx-border pixels are proportional to
     * the same window size desktop uses (960x600). At native-sized backing the
     * border (e.g. 32) would eat 10% of the content. Render target stays at
     * native res; DrawTexturePro upscales with the border inset. CSS then
     * further scales this 3x canvas to the iframe with image-rendering:
     * pixelated — still crisp because the GL stage is integer-scaled. */
    InitWindow(g_wasm_nat_w * SCALE, g_wasm_nat_h * SCALE, title ? title : "RGC-BASIC GFX");
    SetTargetFPS(60);
    g_wasm_target = LoadRenderTexture(g_wasm_nat_w, g_wasm_nat_h);
    /* Same rationale as native: the upscale filter stays POINT. See
     * the long comment at the native LoadRenderTexture call. */
    SetTextureFilter(g_wasm_target.texture, TEXTURE_FILTER_POINT);
    g_wasm_inited = 1;
}

/* Real implementations — overrides the stubs in gfx_wasm_raylib_stubs.c.
 * NOTE: when step 3c retires that shim, these become the sole definitions. */
void wasm_gfx_refresh_js(void)
{
    int win_w, win_h, border;
    float dx, dy, dw, dh;
    Color bg;
    int bc;
    if (!g_wasm_inited) {
        return;
    }
    /* The interpreter calls this hook from many statement handlers — per
     * DRAWSPRITE, per TEXTAT, per PSET, etc. Doing a full GL frame each time
     * collapses WASM perf (0.4 FPS on 120-sprite loops). Rate-limit to 60Hz
     * so at most one render happens per ~16ms of wall time. State keeps
     * updating in g_wasm_vs; the next scheduled render shows the latest. */
    {
        static double last_render_ms = 0.0;
        extern int g_wasm_force_next_refresh;
        double now_ms = emscripten_get_now();
        if (!g_wasm_force_next_refresh && now_ms - last_render_ms < 16.0) {
            return;
        }
        g_wasm_force_next_refresh = 0;
        last_render_ms = now_ms;
    }
    gfx_video_advance_ticks60(&g_wasm_vs, 1u);
    gfx_music_tick();   /* keep all LoadMusicStream slots fed */
    /* Re-apply ANTIALIAS filter every frame on GL thread. raylib-emscripten
     * sometimes loses filter binding between frames on NPOT render textures
     * (WebGL1/ES2), so force the current mode each tick. Cheap (two glTexParameteri
     * calls) and ensures ANTIALIAS OFF stays crisp. */
    {
        int mode = sprite_filter_mode();
        int si;
        pthread_mutex_lock(&g_sprite_mutex);
        for (si = 0; si < GFX_SPRITE_MAX_SLOTS; si++) {
            if (g_sprite_slots[si].loaded) {
                SetTextureFilter(g_sprite_slots[si].tex, mode);
            }
        }
        pthread_mutex_unlock(&g_sprite_mutex);
        /* Target stays POINT — bilinear at upscale smears, it doesn't
         * antialias. See native init comment. */
        g_antialias_applied = g_antialias;
    }
    /* SCREEN 4 — swap the render target to 640×400 so the hi-res RGBA
     * plane isn't sub-sampled. Resize window too so the iframe canvas
     * shows the wider canvas 1:1 instead of inside a 320-wide frame. */
    {
        int want_tw = (g_wasm_vs.screen_mode == GFX_SCREEN_RGBA_HI) ? (int)GFX_RGBA_HI_W : g_wasm_nat_w;
        int want_th = (g_wasm_vs.screen_mode == GFX_SCREEN_RGBA_HI) ? (int)GFX_RGBA_HI_H : g_wasm_nat_h;
        if (g_wasm_target.texture.width != want_tw ||
            g_wasm_target.texture.height != want_th) {
            UnloadRenderTexture(g_wasm_target);
            g_wasm_target = LoadRenderTexture(want_tw, want_th);
            SetTextureFilter(g_wasm_target.texture, TEXTURE_FILTER_POINT);
            SetWindowSize(want_tw * SCALE, want_th * SCALE);
        }
    }

    if (g_wasm_vs.screen_mode == GFX_SCREEN_INDEXED) {
        render_indexed_screen(&g_wasm_vs, g_wasm_target, g_wasm_nat_w);
    } else if (g_wasm_vs.screen_mode == GFX_SCREEN_RGBA ||
               g_wasm_vs.screen_mode == GFX_SCREEN_RGBA_HI) {
        render_rgba_screen(&g_wasm_vs, g_wasm_target, g_wasm_nat_w);
    } else if (g_wasm_vs.screen_mode == GFX_SCREEN_BITMAP) {
        render_bitmap_screen(&g_wasm_vs, g_wasm_target, g_wasm_nat_w);
    } else {
        render_text_screen(&g_wasm_vs, g_wasm_target);
    }
    gfx_sprite_composite_range(&g_wasm_vs, g_wasm_target,
                               g_wasm_target.texture.width,
                               g_wasm_target.texture.height,
                               -32768, 32767, 1);

    win_w = GetScreenWidth();
    win_h = GetScreenHeight();
    border = basic_get_gfx_border();
    dx = (float)border;
    dy = (float)border;
    dw = (float)(win_w - 2 * border);
    dh = (float)(win_h - 2 * border);
    if (dw < 1.0f) dw = 1.0f;
    if (dh < 1.0f) dh = 1.0f;

    gfx_mouse_raylib_poll(g_wasm_target.texture.width,
                          g_wasm_target.texture.height,
                          dx, dy, dx + dw, dy + dh);

    bc = basic_get_gfx_border_color();
    bg = (bc >= 0 && bc <= 15) ? c64_palette(bc) : c64_palette(g_wasm_vs.bg_color & 0x0F);

    BeginDrawing();
    ClearBackground(border > 0 ? bg : BLACK);
    DrawTexturePro(
        g_wasm_target.texture,
        (Rectangle){ 0, 0, (float)g_wasm_target.texture.width, -(float)g_wasm_target.texture.height },
        (Rectangle){ dx, dy, dw, dh },
        (Vector2){ 0, 0 }, 0.0f, WHITE);
    EndDrawing();
}

void wasm_canvas_sync_charset_from_options(void)
{
    if (!g_wasm_inited) {
        return;
    }
    g_wasm_vs.charset_lowercase = (uint8_t)(petscii_get_lowercase() ? 1 : 0);
    g_wasm_vs.charrom_family = (uint8_t)(basic_get_charrom_family() ? 1 : 0);
    gfx_load_default_charrom(&g_wasm_vs);
}

/* If #OPTION columns changed g_wasm_vs.cols after wasm_raylib_init_once
 * already created the 40-col window/render target, resize to match. */
static void wasm_resize_if_cols_changed(void)
{
    int want_cols = g_wasm_vs.cols ? (int)g_wasm_vs.cols : 40;
    int want_w = want_cols * CELL_W;
    if (want_w == g_wasm_nat_w) return;
    UnloadRenderTexture(g_wasm_target);
    g_wasm_nat_w = want_w;
    SetWindowSize(g_wasm_nat_w * SCALE, g_wasm_nat_h * SCALE);
    g_wasm_target = LoadRenderTexture(g_wasm_nat_w, g_wasm_nat_h);
    SetTextureFilter(g_wasm_target.texture, TEXTURE_FILTER_POINT);
}

/* Forced-refresh flag: bypasses the 60Hz rate-limit in wasm_gfx_refresh_js
 * so the end-of-run frame always commits (otherwise short programs whose
 * last PRINT hits the screen within 16ms of the prior budget-tick render
 * leave the final text invisible — fileio_basics, adventure banners, etc.). */
int g_wasm_force_next_refresh = 0;

EMSCRIPTEN_KEEPALIVE
void basic_load_and_run_gfx(const char *path)
{
    wasm_raylib_init_once();
    basic_load(path);
    wasm_resize_if_cols_changed();
    basic_run(path, 0, NULL);
    g_wasm_force_next_refresh = 1;
    wasm_gfx_refresh_js();
}

EMSCRIPTEN_KEEPALIVE
int basic_load_and_run_gfx_argline(const char *argline)
{
    /* Minimal argline handling: apply interpreter flags via the existing
     * basic_apply_arg_string entry point, then treat the first non-flag
     * token as the .bas path. For now, forward unmodified — the IDE wraps
     * "path args..." and the interpreter's arg parser handles the split.
     * TODO: replicate canvas path's quoted-token splitter if needed. */
    if (!argline || !*argline) {
        return -1;
    }
    (void)basic_apply_arg_string(argline);
    /* argline is expected to start with the program path. basic_apply_arg_string
     * leaves the remaining program+args intact in the argv; for simplicity,
     * treat the full argline as the program path when it has no spaces. */
    {
        const char *p = argline;
        while (*p == ' ' || *p == '\t') p++;
        if (!*p) return -1;
        basic_load(p);
        wasm_resize_if_cols_changed();
        basic_run(p, 0, NULL);
    }
    g_wasm_force_next_refresh = 1;
    wasm_gfx_refresh_js();
    return 0;
}

EMSCRIPTEN_KEEPALIVE
uint8_t *wasm_gfx_key_state_ptr(void)
{
    if (!g_wasm_inited) {
        return NULL;
    }
    return g_wasm_vs.key_state;
}

EMSCRIPTEN_KEEPALIVE
void wasm_gfx_key_state_set(int idx, int down)
{
    if (!g_wasm_inited || idx < 0 || idx >= 256) {
        return;
    }
    g_wasm_vs.key_state[(unsigned)idx] = down ? 1 : 0;
}

EMSCRIPTEN_KEEPALIVE
void wasm_gfx_key_state_clear(void)
{
    if (!g_wasm_inited) {
        return;
    }
    memset(g_wasm_vs.key_state, 0, sizeof(g_wasm_vs.key_state));
}

#endif /* __EMSCRIPTEN__ && GFX_USE_RAYLIB */

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
    SetTraceLogLevel(LOG_INFO);
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

    pixbuf_shutdown();
    UnloadRenderTexture(target);
    CloseWindow();
    return 0;
}

#endif /* !GFX_VIDEO */
