/* Software PNG sprites for headless / WASM canvas (no Raylib).
 * Mirrors gfx_raylib.c queue semantics: LOADSPRITE queues decode on the worker;
 * gfx_sprite_process_queue() applies pending commands (called from render + SPRITEW/H). */

#include "gfx_software_sprites.h"
#include "gfx_video.h"
#include "gfx_mouse.h"
#include "../basic_api.h"
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* STB_IMAGE_IMPLEMENTATION now lives in gfx_images.c so the loader is
 * linked in every GFX target (not just canvas/WASM). */
#include "stb_image.h"

#define GFX_SPRITE_MAX_SLOTS 64
#define GFX_SPRITE_Q_CAP 256
#define GFX_SPRITE_PATH_MAX 512

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
    int tile_w, tile_h;
} GfxSpriteCmd;

typedef struct {
    int loaded;
    int visible;
    int w, h;
    int tile_w, tile_h;
    int tiles_x, tiles_y;
    int tile_count;
    int draw_frame;
    unsigned char *rgba; /* malloc'd w*h*4, straight alpha */
    int mod_a, mod_r, mod_g, mod_b;
    float mod_sx, mod_sy;
    int mod_explicit;
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
    int mod_a, mod_r, mod_g, mod_b;
    float mod_sx, mod_sy;
} GfxSpriteDraw;

static char g_sprite_base_dir[GFX_SPRITE_PATH_MAX];
static GfxSpriteSlot g_sprite_slots[GFX_SPRITE_MAX_SLOTS];
static GfxSpriteCmd g_sprite_q[GFX_SPRITE_Q_CAP];
static int g_sprite_q_count;

/* Set to 1 by JS Canvas2D backend to skip software sprite compositing. */
static int g_js_sprite_backend = 0;
int gfx_sprite_js_backend_active(void) { return g_js_sprite_backend; }
void gfx_sprite_set_js_backend(int enable) { g_js_sprite_backend = enable; }

/* Interpreter-thread hit-test cache. Mirrors gfx_raylib.c. See
 * docs/mouse-over-sprite-plan.md for rationale. */
typedef struct {
    int   has_draw;
    float x, y;
    int   w, h;
} GfxSpriteDrawPos;
static GfxSpriteDrawPos g_sprite_draw_pos[GFX_SPRITE_MAX_SLOTS];

static int sprite_q_push(const GfxSpriteCmd *c)
{
    if (g_sprite_q_count >= GFX_SPRITE_Q_CAP) {
        return 0;
    }
    g_sprite_q[g_sprite_q_count++] = *c;
    return 1;
}

void gfx_set_sprite_base_dir(const char *dir)
{
    if (!dir || !dir[0]) {
        g_sprite_base_dir[0] = '\0';
    } else {
        strncpy(g_sprite_base_dir, dir, sizeof(g_sprite_base_dir) - 1);
        g_sprite_base_dir[sizeof(g_sprite_base_dir) - 1] = '\0';
    }
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
    if (g_sprite_base_dir[0] != '\0') {
        snprintf(out, outsz, "%s/%s", g_sprite_base_dir, rel);
    } else {
        snprintf(out, outsz, "%s", rel);
    }
}

void gfx_sprite_enqueue_load_ex(int slot, const char *path, int tile_w, int tile_h)
{
    GfxSpriteCmd c;
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
    (void)sprite_q_push(&c);
}

void gfx_sprite_enqueue_load(int slot, const char *path)
{
    gfx_sprite_enqueue_load_ex(slot, path, 0, 0);
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
    /* Invalidate hit-test cache (see gfx_raylib.c). */
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

    /* Hit-test cache (see gfx_raylib.c for rationale). */
    {
        int rw = sw, rh = sh;
        if (rw <= 0 || rh <= 0) {
            int tsx, tsy, tsw, tsh;
            tsx = sx; tsy = sy; tsw = rw; tsh = rh;
            if (gfx_sprite_effective_source_rect(slot, &tsx, &tsy, &tsw, &tsh) == 0) {
                if (rw <= 0) rw = tsw;
                if (rh <= 0) rh = tsh;
            }
        }
        g_sprite_draw_pos[slot].x = x;
        g_sprite_draw_pos[slot].y = y;
        g_sprite_draw_pos[slot].w = rw > 0 ? rw : 0;
        g_sprite_draw_pos[slot].h = rh > 0 ? rh : 0;
        g_sprite_draw_pos[slot].has_draw = (rw > 0 && rh > 0) ? 1 : 0;
    }
}

int gfx_sprite_is_mouse_over(int slot)
{
    GfxSpriteDrawPos *d;
    int mx, my;
    int x, y, w, h;
    if (slot < 0 || slot >= GFX_SPRITE_MAX_SLOTS) {
        return 0;
    }
    d = &g_sprite_draw_pos[slot];
    if (!d->has_draw || d->w <= 0 || d->h <= 0) {
        return 0;
    }
    mx = gfx_mouse_x();
    my = gfx_mouse_y();
    x = (int)d->x;
    y = (int)d->y;
    w = d->w;
    h = d->h;
    return (mx >= x && mx < x + w && my >= y && my < y + h) ? 1 : 0;
}

void gfx_sprite_set_modulate(int slot, int alpha, int r, int g, int b, float scale_x, float scale_y)
{
    GfxSpriteSlot *sl;
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
    sl = &g_sprite_slots[slot];
    sl->mod_a = alpha;
    sl->mod_r = r;
    sl->mod_g = g;
    sl->mod_b = b;
    sl->mod_sx = scale_x;
    sl->mod_sy = scale_y;
    sl->mod_explicit = 1;
}

int gfx_sprite_slot_width(int slot)
{
    gfx_sprite_process_queue();
    if (slot < 0 || slot >= GFX_SPRITE_MAX_SLOTS) {
        return 0;
    }
    if (!g_sprite_slots[slot].loaded) {
        return 0;
    }
    if (g_sprite_slots[slot].tile_w > 0 && g_sprite_slots[slot].tile_h > 0) {
        return g_sprite_slots[slot].tile_w;
    }
    return g_sprite_slots[slot].w;
}

int gfx_sprite_slot_height(int slot)
{
    gfx_sprite_process_queue();
    if (slot < 0 || slot >= GFX_SPRITE_MAX_SLOTS) {
        return 0;
    }
    if (!g_sprite_slots[slot].loaded) {
        return 0;
    }
    if (g_sprite_slots[slot].tile_w > 0 && g_sprite_slots[slot].tile_h > 0) {
        return g_sprite_slots[slot].tile_h;
    }
    return g_sprite_slots[slot].h;
}

int gfx_sprite_slot_tile_count(int slot)
{
    gfx_sprite_process_queue();
    if (slot < 0 || slot >= GFX_SPRITE_MAX_SLOTS) {
        return 0;
    }
    if (!g_sprite_slots[slot].loaded) {
        return 0;
    }
    return g_sprite_slots[slot].tile_count;
}

int gfx_sprite_slot_sheet_cols(int slot)
{
    gfx_sprite_process_queue();
    if (slot < 0 || slot >= GFX_SPRITE_MAX_SLOTS) return 0;
    if (!g_sprite_slots[slot].loaded) return 0;
    return g_sprite_slots[slot].tiles_x;
}
int gfx_sprite_slot_sheet_rows(int slot)
{
    gfx_sprite_process_queue();
    if (slot < 0 || slot >= GFX_SPRITE_MAX_SLOTS) return 0;
    if (!g_sprite_slots[slot].loaded) return 0;
    return g_sprite_slots[slot].tiles_y;
}
int gfx_sprite_slot_sheet_cell_w(int slot)
{
    gfx_sprite_process_queue();
    if (slot < 0 || slot >= GFX_SPRITE_MAX_SLOTS) return 0;
    if (!g_sprite_slots[slot].loaded) return 0;
    return g_sprite_slots[slot].tile_w;
}
int gfx_sprite_slot_sheet_cell_h(int slot)
{
    gfx_sprite_process_queue();
    if (slot < 0 || slot >= GFX_SPRITE_MAX_SLOTS) return 0;
    if (!g_sprite_slots[slot].loaded) return 0;
    return g_sprite_slots[slot].tile_h;
}

/* TILEMAP DRAW (canvas/WASM backend).
 *
 * Can't use gfx_sprite_enqueue_draw — that path mirrors into
 * g_sprite_slots[slot].draw_* as a single persistent position per slot
 * so N per-slot enqueues collapse to one draw. Instead we keep a
 * per-cell list (g_tm_cells[]) which the compositor consumes each
 * frame alongside the regular sprite slots.
 *
 * Replace semantics: each gfx_draw_tilemap call overwrites the list.
 * No mutex — canvas/WASM build is single-threaded. */

#define GFX_TILEMAP_MAX_CELLS 4096

/* Double-buffered cell list — see gfx/gfx_raylib.c for the rationale.
 * BASIC appends to g_tm_build; the compositor reads g_tm_show;
 * gfx_cells_flip() (called by VSYNC) swaps atomically. */
static GfxSpriteDraw g_tm_build[GFX_TILEMAP_MAX_CELLS];
static int g_tm_build_count = 0;
static GfxSpriteDraw g_tm_show[GFX_TILEMAP_MAX_CELLS];
static int g_tm_show_count = 0;
#define g_tm_cells g_tm_build
#define g_tm_count g_tm_build_count

void gfx_draw_tilemap(int slot, float x0, float y0, int cols, int rows, int z,
                      const int *tiles, int tile_count)
{
    int cell_w, cell_h;
    int r, c, i = 0;
    int n = g_tm_count;  /* append to any cells already queued this frame */
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
            g_tm_cells[n].slot = slot;
            g_tm_cells[n].x = x0 + (float)(c * cell_w);
            g_tm_cells[n].y = y0 + (float)(r * cell_h);
            g_tm_cells[n].z = z;
            g_tm_cells[n].sx = sx;
            g_tm_cells[n].sy = sy;
            g_tm_cells[n].sw = sw;
            g_tm_cells[n].sh = sh;
            g_tm_cells[n].mod_a = 255;
            g_tm_cells[n].mod_r = 255;
            g_tm_cells[n].mod_g = 255;
            g_tm_cells[n].mod_b = 255;
            g_tm_cells[n].mod_sx = 1.0f;
            g_tm_cells[n].mod_sy = 1.0f;
            n++;
        }
    }
    g_tm_count = n;
}

/* Clear only the build buffer; show buffer keeps the last committed
 * frame so the renderer still has something coherent to draw. */
void gfx_cells_clear(void)
{
    g_tm_build_count = 0;
}

/* Commit build → show. Single-threaded canvas/WASM build so no lock
 * needed, but keep the semantics identical to the raylib backend. */
void gfx_cells_flip(void)
{
    g_tm_show_count = g_tm_build_count;
    if (g_tm_show_count > 0) {
        memcpy(g_tm_show, g_tm_build,
               (size_t)g_tm_show_count * sizeof(GfxSpriteDraw));
    }
}

/* SPRITE STAMP: append a single sprite-tile draw. `frame` is a 1-based
 * tile index; 0 uses the slot's current SPRITEFRAME. `rot_deg` is
 * accepted for API parity with the raylib backend but ignored here —
 * the 1bpp software blitter doesn't rotate per-pixel. */
void gfx_sprite_stamp(int slot, float x, float y, int frame, int z, float rot_deg)
{
    int sx, sy, sw, sh;
    int idx = (frame > 0) ? frame : gfx_sprite_get_draw_frame(slot);
    (void)rot_deg;
    if (idx <= 0) idx = 1;
    if (gfx_sprite_tile_source_rect(slot, idx, &sx, &sy, &sw, &sh) != 0) {
        sx = sy = 0;
        if (gfx_sprite_effective_source_rect(slot, &sx, &sy, &sw, &sh) != 0) return;
    }
    if (g_tm_count < GFX_TILEMAP_MAX_CELLS) {
        GfxSpriteDraw *c = &g_tm_cells[g_tm_count++];
        c->slot = slot;
        c->x = x;
        c->y = y;
        c->z = z;
        c->sx = sx;
        c->sy = sy;
        c->sw = sw;
        c->sh = sh;
        c->mod_a = 255;
        c->mod_r = 255;
        c->mod_g = 255;
        c->mod_b = 255;
        c->mod_sx = 1.0f;
        c->mod_sy = 1.0f;
    }
}

int gfx_sprite_tile_source_rect(int slot, int tile_index_1based, int *sx, int *sy, int *sw, int *sh)
{
    GfxSpriteSlot *sl;
    int idx0, tx, ty;
    gfx_sprite_process_queue();
    if (slot < 0 || slot >= GFX_SPRITE_MAX_SLOTS || !sx || !sy || !sw || !sh) {
        return -1;
    }
    sl = &g_sprite_slots[slot];
    if (!sl->loaded || sl->tile_w <= 0 || sl->tile_h <= 0 || sl->tiles_x <= 0 || sl->tile_count <= 0) {
        return -1;
    }
    if (tile_index_1based < 1 || tile_index_1based > sl->tile_count) {
        return -1;
    }
    idx0 = tile_index_1based - 1;
    tx = idx0 % sl->tiles_x;
    ty = idx0 / sl->tiles_x;
    *sx = tx * sl->tile_w;
    *sy = ty * sl->tile_h;
    *sw = sl->tile_w;
    *sh = sl->tile_h;
    return 0;
}

void gfx_sprite_set_draw_frame(int slot, int frame_1based)
{
    GfxSpriteSlot *sl;
    gfx_sprite_process_queue();
    if (slot < 0 || slot >= GFX_SPRITE_MAX_SLOTS) {
        return;
    }
    sl = &g_sprite_slots[slot];
    if (!sl->loaded || sl->tile_w <= 0 || sl->tile_h <= 0 || sl->tile_count <= 0) {
        return;
    }
    if (frame_1based < 1) {
        frame_1based = 1;
    }
    if (frame_1based > sl->tile_count) {
        frame_1based = sl->tile_count;
    }
    sl->draw_frame = frame_1based;
    /* Invalidate any cached explicit crop from the previous DRAWSPRITE
     * so the next default draw resolves via the new frame. */
    sl->draw_sw = 0;
    sl->draw_sh = 0;
}

int gfx_sprite_get_draw_frame(int slot)
{
    int f = 1;
    gfx_sprite_process_queue();
    if (slot < 0 || slot >= GFX_SPRITE_MAX_SLOTS) {
        return 0;
    }
    if (g_sprite_slots[slot].loaded) {
        f = g_sprite_slots[slot].draw_frame;
        if (f < 1) {
            f = 1;
        }
    }
    return f;
}

int gfx_sprite_effective_source_rect(int slot, int *sx, int *sy, int *sw, int *sh)
{
    GfxSpriteSlot *sl;
    gfx_sprite_process_queue();
    if (slot < 0 || slot >= GFX_SPRITE_MAX_SLOTS || !sx || !sy || !sw || !sh) {
        return -1;
    }
    sl = &g_sprite_slots[slot];
    if (!sl->loaded) {
        return -1;
    }
    if (sl->draw_sw > 0 && sl->draw_sh > 0) {
        *sx = sl->draw_sx;
        *sy = sl->draw_sy;
        *sw = sl->draw_sw;
        *sh = sl->draw_sh;
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
        return 0;
    }
    *sx = sl->draw_sx;
    *sy = sl->draw_sy;
    *sw = sl->w - sl->draw_sx;
    *sh = sl->h - sl->draw_sy;
    return 0;
}

int gfx_sprite_slots_overlap_aabb(int slot_a, int slot_b)
{
    GfxSpriteSlot *a, *b;
    float ax, ay, aw, ah, bx, by, bw, bh;
    float ax2, ay2, bx2, by2;

    gfx_sprite_process_queue();
    if (slot_a < 0 || slot_a >= GFX_SPRITE_MAX_SLOTS ||
        slot_b < 0 || slot_b >= GFX_SPRITE_MAX_SLOTS) {
        return 0;
    }
    a = &g_sprite_slots[slot_a];
    b = &g_sprite_slots[slot_b];
    if (!a->loaded || !a->visible || !a->draw_active ||
        !b->loaded || !b->visible || !b->draw_active) {
        return 0;
    }
    if (a->draw_sw <= 0 || a->draw_sh <= 0) {
        if (a->tile_w > 0 && a->tile_h > 0) {
            aw = (float)a->tile_w;
            ah = (float)a->tile_h;
        } else {
            aw = (float)(a->w - a->draw_sx);
            ah = (float)(a->h - a->draw_sy);
        }
    } else {
        aw = (float)a->draw_sw;
        ah = (float)a->draw_sh;
    }
    if (b->draw_sw <= 0 || b->draw_sh <= 0) {
        if (b->tile_w > 0 && b->tile_h > 0) {
            bw = (float)b->tile_w;
            bh = (float)b->tile_h;
        } else {
            bw = (float)(b->w - b->draw_sx);
            bh = (float)(b->h - b->draw_sy);
        }
    } else {
        bw = (float)b->draw_sw;
        bh = (float)b->draw_sh;
    }
    if (aw <= 0 || ah <= 0 || bw <= 0 || bh <= 0) {
        return 0;
    }
    aw = aw * a->mod_sx;
    ah = ah * a->mod_sy;
    bw = bw * b->mod_sx;
    bh = bh * b->mod_sy;
    ax = a->draw_x;
    ay = a->draw_y;
    bx = b->draw_x;
    by = b->draw_y;
    ax2 = ax + aw;
    ay2 = ay + ah;
    bx2 = bx + bw;
    by2 = by + bh;
    if (ax2 <= bx || bx2 <= ax || ay2 <= by || by2 <= ay) {
        return 0;
    }
    return 1;
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

void gfx_sprite_process_queue(void)
{
    GfxSpriteCmd cmds[GFX_SPRITE_Q_CAP];
    int i, n = g_sprite_q_count;

    if (n > GFX_SPRITE_Q_CAP) {
        n = GFX_SPRITE_Q_CAP;
    }
    for (i = 0; i < n; i++) {
        cmds[i] = g_sprite_q[i];
    }
    g_sprite_q_count = 0;

    for (i = 0; i < n; i++) {
        GfxSpriteCmd *c = &cmds[i];
        if (c->slot < 0 || c->slot >= GFX_SPRITE_MAX_SLOTS) {
            continue;
        }
        switch (c->kind) {
        case GFX_SQ_LOAD: {
            char full[1024];
            int w = 0, h = 0, comp = 0;
            unsigned char *pix;
            GfxSpriteSlot *sl = &g_sprite_slots[c->slot];
            int tw = c->tile_w;
            int th = c->tile_h;
            int preserve_mod;
            int pma, pmr, pmg, pmb;
            float pmsx, pmsy;

            preserve_mod = sl->mod_explicit;
            pma = sl->mod_a;
            pmr = sl->mod_r;
            pmg = sl->mod_g;
            pmb = sl->mod_b;
            pmsx = sl->mod_sx;
            pmsy = sl->mod_sy;

            sprite_build_path(full, sizeof(full), c->path);
            if (sl->loaded && sl->rgba) {
                free(sl->rgba);
                sl->rgba = NULL;
            }
            sl->loaded = 0;
            sl->w = sl->h = 0;
            sl->visible = 0;
            sl->draw_active = 0;
            sl->tile_w = sl->tile_h = 0;
            sl->tiles_x = sl->tiles_y = sl->tile_count = 0;
            sl->draw_frame = 0;

            stbi_set_flip_vertically_on_load(0);
            pix = stbi_load(full, &w, &h, &comp, 4);
            if (pix && w > 0 && h > 0) {
                sl->rgba = pix;
                sl->w = w;
                sl->h = h;
                sl->loaded = 1;
                sl->visible = 1;
                sl->draw_active = 0;
                gfx_sprite_slot_bump_version(c->slot);
                sl->tile_w = tw;
                sl->tile_h = th;
                if (tw > 0 && th > 0 && w >= tw && h >= th) {
                    sl->tiles_x = w / tw;
                    sl->tiles_y = h / th;
                    sl->tile_count = sl->tiles_x * sl->tiles_y;
                    sl->draw_frame = 1;
                } else {
                    sl->tile_w = sl->tile_h = 0;
                    sl->tile_count = 1;
                    sl->draw_frame = 1;
                }
                if (preserve_mod) {
                    sl->mod_a = pma;
                    sl->mod_r = pmr;
                    sl->mod_g = pmg;
                    sl->mod_b = pmb;
                    sl->mod_sx = pmsx;
                    sl->mod_sy = pmsy;
                    sl->mod_explicit = 1;
                } else {
                    sl->mod_a = 255;
                    sl->mod_r = 255;
                    sl->mod_g = 255;
                    sl->mod_b = 255;
                    sl->mod_sx = 1.0f;
                    sl->mod_sy = 1.0f;
                    sl->mod_explicit = 0;
                }
            } else {
                if (pix) {
                    stbi_image_free(pix);
                }
            }
            break;
        }
        case GFX_SQ_VISIBLE:
            if (c->slot >= 0 && c->slot < GFX_SPRITE_MAX_SLOTS) {
                g_sprite_slots[c->slot].visible = c->z ? 1 : 0;
            }
            break;
        case GFX_SQ_UNLOAD: {
            GfxSpriteSlot *sl = &g_sprite_slots[c->slot];
            if (sl->loaded && sl->rgba) {
                stbi_image_free(sl->rgba);
                sl->rgba = NULL;
            }
            sl->loaded = 0;
            sl->visible = 0;
            sl->draw_active = 0;
            sl->w = sl->h = 0;
            sl->tile_w = sl->tile_h = 0;
            sl->tiles_x = sl->tiles_y = sl->tile_count = 0;
            sl->draw_frame = 0;
            sl->mod_a = 255;
            sl->mod_r = 255;
            sl->mod_g = 255;
            sl->mod_b = 255;
            sl->mod_sx = 1.0f;
            sl->mod_sy = 1.0f;
            sl->mod_explicit = 0;
            gfx_sprite_slot_bump_version(c->slot);
            break;
        }
        case GFX_SQ_COPY: {
            /* Clone src slot pixel data into dst slot (independent allocation).
             * Best practice for performance: if the source has colour modulate
             * applied (SPRITEMODIFY/SPRITEMODULATE), bake it into the destination
             * pixels and reset dst mods to 255. This allows the Canvas2D fast-path
             * to draw the copy without needing per-channel multiply at composite time. */
            GfxSpriteSlot *src = &g_sprite_slots[c->slot];
            GfxSpriteSlot *dst = &g_sprite_slots[c->slot2];
            unsigned char *new_rgba = NULL;
            size_t npix, i;
            int bake = (src->mod_r != 255 || src->mod_g != 255 ||
                        src->mod_b != 255 || src->mod_a != 255);
            if (!src->loaded || !src->rgba || src->w <= 0 || src->h <= 0) break;
            npix = (size_t)src->w * (size_t)src->h * 4u;
            new_rgba = (unsigned char *)malloc(npix);
            if (!new_rgba) break;
            if (bake) {
                /* Pre-multiply modulate into pixel data so dst is pure RGBA. */
                for (i = 0; i < npix; i += 4) {
                    new_rgba[i+0] = (unsigned char)((src->rgba[i+0] * (unsigned)src->mod_r + 127) / 255);
                    new_rgba[i+1] = (unsigned char)((src->rgba[i+1] * (unsigned)src->mod_g + 127) / 255);
                    new_rgba[i+2] = (unsigned char)((src->rgba[i+2] * (unsigned)src->mod_b + 127) / 255);
                    new_rgba[i+3] = (unsigned char)((src->rgba[i+3] * (unsigned)src->mod_a + 127) / 255);
                }
            } else {
                memcpy(new_rgba, src->rgba, npix);
            }
            /* Free existing dst if loaded */
            if (dst->loaded && dst->rgba) {
                free(dst->rgba);
                dst->rgba = NULL;
            }
            *dst = *src;           /* copy all scalar fields */
            dst->rgba = new_rgba;  /* replace with independent buffer */
            dst->draw_active = 0;  /* new slot has no draw position yet */
            if (bake) {
                /* Reset dst mods — colour is baked into pixels */
                dst->mod_r = 255; dst->mod_g = 255;
                dst->mod_b = 255; dst->mod_a = 255;
                dst->mod_explicit = 0;
            }
            memset(&g_sprite_draw_pos[c->slot2], 0, sizeof(g_sprite_draw_pos[c->slot2]));
            gfx_sprite_slot_bump_version(c->slot2);
            break;
        }
        case GFX_SQ_DRAW: {
            GfxSpriteSlot *sl = &g_sprite_slots[c->slot];
            sl->draw_active = 1;
            sl->draw_x = c->x;
            sl->draw_y = c->y;
            sl->draw_z = c->z;
            sl->draw_sx = c->sx;
            sl->draw_sy = c->sy;
            sl->draw_sw = c->sw;
            sl->draw_sh = c->sh;
            break;
        }
        default:
            break;
        }
    }
}

void gfx_sprite_shutdown(void)
{
    int i;
    for (i = 0; i < GFX_SPRITE_MAX_SLOTS; i++) {
        GfxSpriteSlot *sl = &g_sprite_slots[i];
        if (sl->loaded && sl->rgba) {
            stbi_image_free(sl->rgba);
            sl->rgba = NULL;
        }
        sl->loaded = 0;
        sl->visible = 0;
        sl->draw_active = 0;
        sl->w = sl->h = 0;
    }
    g_sprite_q_count = 0;
}

void gfx_canvas_sprite_composite_rgba(const GfxVideoState *s, uint8_t *rgba, int fb_w, int fb_h)
{
    GfxSpriteDraw *draws = NULL;
    int cap = 0;
    int nd = 0;
    int i, dx, dy;
    int scx = 0;
    int scy = 0;

    if (!s || !rgba || fb_w <= 0 || fb_h <= 0) {
        return;
    }
    scx = (int)s->scroll_x;
    scy = (int)s->scroll_y;

    gfx_sprite_process_queue();

    /* Capacity = per-slot sprite draws (at most MAX_SLOTS) + tilemap cells. */
    cap = GFX_SPRITE_MAX_SLOTS + g_tm_show_count;
    if (cap <= 0) return;
    draws = (GfxSpriteDraw *)malloc((size_t)cap * sizeof(GfxSpriteDraw));
    if (!draws) return;

    for (i = 0; i < GFX_SPRITE_MAX_SLOTS; i++) {
        GfxSpriteSlot *sl = &g_sprite_slots[i];
        if (!sl->loaded || !sl->visible || !sl->draw_active) {
            continue;
        }
        if (nd >= cap) break;
        draws[nd].slot = i;
        draws[nd].x = sl->draw_x;
        draws[nd].y = sl->draw_y;
        draws[nd].z = sl->draw_z;
        draws[nd].sx = sl->draw_sx;
        draws[nd].sy = sl->draw_sy;
        draws[nd].sw = sl->draw_sw;
        draws[nd].sh = sl->draw_sh;
        draws[nd].mod_a = sl->mod_a;
        draws[nd].mod_r = sl->mod_r;
        draws[nd].mod_g = sl->mod_g;
        draws[nd].mod_b = sl->mod_b;
        draws[nd].mod_sx = sl->mod_sx;
        draws[nd].mod_sy = sl->mod_sy;
        nd++;
    }

    /* Append TILEMAP DRAW / SPRITE STAMP cells — each is a plain-
     * modulation draw (alpha 255, tint white, scale 1:1). They sort
     * together with the per-slot sprites so a player sprite at z=100
     * composites cleanly on top of a background tilemap at z=0.
     * Auto-clear after capture: cells are per-frame; callers must
     * re-submit each tick. */
    for (i = 0; i < g_tm_show_count && nd < cap; i++) {
        draws[nd++] = g_tm_show[i];
    }

    if (nd <= 0) {
        free(draws);
        return;
    }

    qsort(draws, (size_t)nd, sizeof(draws[0]), cmp_sprite_draw_z);

    for (i = 0; i < nd; i++) {
        GfxSpriteDraw *d = &draws[i];
        int sidx = d->slot;
        GfxSpriteSlot *sl;
        float sx, sy, sw, sh;
        int src_x0, src_y0, iw, ih;
        int dw, dh;
        int x0, y0, x1, y1;
        int ma, mr, mg, mb;

        if (sidx < 0 || sidx >= GFX_SPRITE_MAX_SLOTS) {
            continue;
        }
        sl = &g_sprite_slots[sidx];
        if (!sl->loaded || !sl->visible || !sl->rgba) {
            continue;
        }

        sx = (float)d->sx;
        sy = (float)d->sy;
        if (d->sw <= 0 || d->sh <= 0) {
            sw = (float)(sl->w - d->sx);
            sh = (float)(sl->h - d->sy);
        } else {
            sw = (float)d->sw;
            sh = (float)d->sh;
        }
        if (sw <= 0 || sh <= 0) {
            continue;
        }
        if (sx < 0 || sy < 0 || sx + sw > (float)sl->w + 0.01f ||
            sy + sh > (float)sl->h + 0.01f) {
            continue;
        }

        src_x0 = (int)sx;
        src_y0 = (int)sy;
        iw = (int)sw;
        ih = (int)sh;
        ma = d->mod_a;
        mr = d->mod_r;
        mg = d->mod_g;
        mb = d->mod_b;
        if (ma <= 0) {
            continue;
        }

        dw = (int)(sw * d->mod_sx + 0.5f);
        dh = (int)(sh * d->mod_sy + 0.5f);
        if (dw < 1) {
            dw = 1;
        }
        if (dh < 1) {
            dh = 1;
        }

        x0 = (int)d->x - scx;
        y0 = (int)d->y - scy;
        x1 = x0 + dw - 1;
        y1 = y0 + dh - 1;

        if (x1 < 0 || y1 < 0 || x0 >= fb_w || y0 >= fb_h) {
            continue;
        }

        /* Fast-path: no scaling, skip bilinear interpolation */
        if (dw == iw && dh == ih) {
            /* Super-fast inner loop: no colour modulate (ma==mr==mg==mb==255) */
            if (ma == 255 && mr == 255 && mg == 255 && mb == 255) {
                for (dy = 0; dy < dh; dy++) {
                    int dst_y = y0 + dy;
                    int src_y = src_y0 + dy;
                    size_t src_row_off;
                    int clip_x0 = dx, clip_x1 = dw; /* dx reused as clip start */
                    size_t drow_off;
                    if (dst_y < 0 || dst_y >= fb_h) {
                        continue;
                    }
                    /* clip x range once per row */
                    clip_x0 = (x0 < 0) ? -x0 : 0;
                    clip_x1 = (x0 + dw > fb_w) ? fb_w - x0 : dw;
                    if (clip_x0 >= clip_x1) {
                        continue;
                    }
                    src_row_off = ((size_t)src_y * (size_t)sl->w + (size_t)(src_x0 + clip_x0)) * 4u;
                    drow_off = ((size_t)dst_y * (size_t)fb_w + (size_t)(x0 + clip_x0)) * 4u;
                    for (dx = clip_x0; dx < clip_x1; dx++) {
                        unsigned pa;
                        size_t soff = src_row_off + (size_t)(dx - clip_x0) * 4u;
                        size_t doff = drow_off + (size_t)(dx - clip_x0) * 4u;
                        pa = (unsigned)sl->rgba[soff + 3];
                        if (pa == 0) {
                            continue;
                        }
                        if (pa == 255) {
                            rgba[doff + 0] = sl->rgba[soff + 0];
                            rgba[doff + 1] = sl->rgba[soff + 1];
                            rgba[doff + 2] = sl->rgba[soff + 2];
                            rgba[doff + 3] = 0xFF;
                        } else {
                            unsigned inv = 255 - pa;
                            rgba[doff + 0] = (unsigned char)(((unsigned)sl->rgba[soff + 0] * pa + rgba[doff + 0] * inv + 127) / 255);
                            rgba[doff + 1] = (unsigned char)(((unsigned)sl->rgba[soff + 1] * pa + rgba[doff + 1] * inv + 127) / 255);
                            rgba[doff + 2] = (unsigned char)(((unsigned)sl->rgba[soff + 2] * pa + rgba[doff + 2] * inv + 127) / 255);
                            rgba[doff + 3] = 0xFF;
                        }
                    }
                }
            } else {
            /* Fast-path with colour modulate */
            for (dy = 0; dy < dh; dy++) {
                int dst_y = y0 + dy;
                int src_y = src_y0 + dy;
                size_t src_row_off;
                if (dst_y < 0 || dst_y >= fb_h) {
                    continue;
                }
                src_row_off = ((size_t)src_y * (size_t)sl->w + (size_t)src_x0) * 4u;
                for (dx = 0; dx < dw; dx++) {
                    int dst_x = x0 + dx;
                    unsigned pr, pg, pb, pa, inv;
                    size_t soff, doff;
                    if (dst_x < 0 || dst_x >= fb_w) {
                        continue;
                    }
                    soff = src_row_off + (size_t)dx * 4u;
                    pa = (unsigned)sl->rgba[soff + 3];
                    pa = (pa * (unsigned)ma + 127) / 255;
                    if (pa == 0) {
                        continue;
                    }
                    pr = (unsigned)sl->rgba[soff + 0];
                    pg = (unsigned)sl->rgba[soff + 1];
                    pb = (unsigned)sl->rgba[soff + 2];
                    pr = (pr * (unsigned)mr + 127) / 255;
                    pg = (pg * (unsigned)mg + 127) / 255;
                    pb = (pb * (unsigned)mb + 127) / 255;
                    doff = ((size_t)dst_y * (size_t)fb_w + (size_t)dst_x) * 4u;
                    if (pa == 255) {
                        rgba[doff + 0] = (unsigned char)pr;
                        rgba[doff + 1] = (unsigned char)pg;
                        rgba[doff + 2] = (unsigned char)pb;
                        rgba[doff + 3] = 0xFF;
                    } else {
                        inv = (unsigned)(255 - pa);
                        rgba[doff + 0] = (unsigned char)((pr * pa + rgba[doff + 0] * inv + 127) / 255);
                        rgba[doff + 1] = (unsigned char)((pg * pa + rgba[doff + 1] * inv + 127) / 255);
                        rgba[doff + 2] = (unsigned char)((pb * pa + rgba[doff + 2] * inv + 127) / 255);
                        rgba[doff + 3] = 0xFF;
                    }
                }
            }
            } /* end modulate fast-path */
        } else {
        /* Scaled path: full bilinear interpolation */
        for (dy = 0; dy < dh; dy++) {
            float v = ((float)dy + 0.5f) / (float)dh;
            float src_yf = (float)src_y0 + v * (float)ih - 0.5f;
            int dst_y = y0 + dy;
            int sya, syb;
            float fy;
            if (dst_y < 0 || dst_y >= fb_h) {
                continue;
            }
            sya = (int)floorf(src_yf);
            syb = sya + 1;
            fy = src_yf - (float)sya;
            if (sya < 0) {
                sya = 0;
            }
            if (syb >= sl->h) {
                syb = sl->h - 1;
            }
            for (dx = 0; dx < dw; dx++) {
                float u = ((float)dx + 0.5f) / (float)dw;
                float src_xf = (float)src_x0 + u * (float)iw - 0.5f;
                int dst_x = x0 + dx;
                int sxa, sxb;
                float fx;
                unsigned c00, c01, c10, c11;
                unsigned r0, g0, b0, a0, r1, g1, b1, a1;
                unsigned pr, pg, pb, pa, inv;
                size_t doff;

                if (dst_x < 0 || dst_x >= fb_w) {
                    continue;
                }
                sxa = (int)floorf(src_xf);
                sxb = sxa + 1;
                fx = src_xf - (float)sxa;
                if (sxa < 0) {
                    sxa = 0;
                }
                if (sxb >= sl->w) {
                    sxb = sl->w - 1;
                }
#define PIX(ix, iy) (sl->rgba + (((size_t)(iy) * (size_t)sl->w + (size_t)(ix)) * 4u))
                c00 = PIX(sxa, sya)[0];
                c01 = PIX(sxb, sya)[0];
                c10 = PIX(sxa, syb)[0];
                c11 = PIX(sxb, syb)[0];
                r0 = (unsigned)((1.0f - fx) * (float)c00 + fx * (float)c01 + 0.5f);
                r1 = (unsigned)((1.0f - fx) * (float)c10 + fx * (float)c11 + 0.5f);
                pr = (unsigned)((1.0f - fy) * (float)r0 + fy * (float)r1 + 0.5f);
                c00 = PIX(sxa, sya)[1];
                c01 = PIX(sxb, sya)[1];
                c10 = PIX(sxa, syb)[1];
                c11 = PIX(sxb, syb)[1];
                g0 = (unsigned)((1.0f - fx) * (float)c00 + fx * (float)c01 + 0.5f);
                g1 = (unsigned)((1.0f - fx) * (float)c10 + fx * (float)c11 + 0.5f);
                pg = (unsigned)((1.0f - fy) * (float)g0 + fy * (float)g1 + 0.5f);
                c00 = PIX(sxa, sya)[2];
                c01 = PIX(sxb, sya)[2];
                c10 = PIX(sxa, syb)[2];
                c11 = PIX(sxb, syb)[2];
                b0 = (unsigned)((1.0f - fx) * (float)c00 + fx * (float)c01 + 0.5f);
                b1 = (unsigned)((1.0f - fx) * (float)c10 + fx * (float)c11 + 0.5f);
                pb = (unsigned)((1.0f - fy) * (float)b0 + fy * (float)b1 + 0.5f);
                c00 = PIX(sxa, sya)[3];
                c01 = PIX(sxb, sya)[3];
                c10 = PIX(sxa, syb)[3];
                c11 = PIX(sxb, syb)[3];
                a0 = (unsigned)((1.0f - fx) * (float)c00 + fx * (float)c01 + 0.5f);
                a1 = (unsigned)((1.0f - fx) * (float)c10 + fx * (float)c11 + 0.5f);
                pa = (unsigned)((1.0f - fy) * (float)a0 + fy * (float)a1 + 0.5f);
#undef PIX
                pa = (pa * (unsigned)ma + 127) / 255;
                if (pa == 0) {
                    continue;
                }
                pr = (pr * (unsigned)mr + 127) / 255;
                pg = (pg * (unsigned)mg + 127) / 255;
                pb = (pb * (unsigned)mb + 127) / 255;

                doff = ((size_t)dst_y * (size_t)fb_w + (size_t)dst_x) * 4u;
                if (pa == 255) {
                    rgba[doff + 0] = (unsigned char)pr;
                    rgba[doff + 1] = (unsigned char)pg;
                    rgba[doff + 2] = (unsigned char)pb;
                    rgba[doff + 3] = 0xFF;
                } else {
                    inv = (unsigned)(255 - pa);
                    rgba[doff + 0] = (unsigned char)((pr * pa + rgba[doff + 0] * inv + 127) / 255);
                    rgba[doff + 1] = (unsigned char)((pg * pa + rgba[doff + 1] * inv + 127) / 255);
                    rgba[doff + 2] = (unsigned char)((pb * pa + rgba[doff + 2] * inv + 127) / 255);
                    rgba[doff + 3] = 0xFF;
                }
            }
        }
        } /* end scaled path */
    }
    free(draws);
}

/* ── JS Canvas2D sprite accessor API ───────────────────────────────────────
 * These let the JS layer query slot state so it can draw sprites via
 * ctx.drawImage() instead of the software compositor.  Only used in the
 * WASM canvas build; compiled out elsewhere via #ifdef guards in basic.c.
 */

/* Returns the RGBA pixel data pointer for slot (NULL if not loaded). */
unsigned char *gfx_sprite_slot_rgba_ptr(int slot)
{
    if (slot < 0 || slot >= GFX_SPRITE_MAX_SLOTS) return NULL;
    if (!g_sprite_slots[slot].loaded) return NULL;
    return g_sprite_slots[slot].rgba;
}

/* Returns slot dimensions; 0 if not loaded. */
int gfx_sprite_slot_w(int slot)
{
    if (slot < 0 || slot >= GFX_SPRITE_MAX_SLOTS) return 0;
    return g_sprite_slots[slot].w;
}
int gfx_sprite_slot_h(int slot)
{
    if (slot < 0 || slot >= GFX_SPRITE_MAX_SLOTS) return 0;
    return g_sprite_slots[slot].h;
}

/* Returns 1 if slot is loaded and draw_active. */
int gfx_sprite_slot_draw_active(int slot)
{
    if (slot < 0 || slot >= GFX_SPRITE_MAX_SLOTS) return 0;
    GfxSpriteSlot *sl = &g_sprite_slots[slot];
    return (sl->loaded && sl->visible && sl->draw_active) ? 1 : 0;
}

/* Fills draw params for slot. Returns 0 on success, -1 if not active. */
int gfx_sprite_slot_draw_params(int slot,
    float *out_x, float *out_y, int *out_z,
    int *out_dw, int *out_dh,
    int *out_ma, int *out_mr, int *out_mg, int *out_mb,
    float *out_sx, float *out_sy)
{
    GfxSpriteSlot *sl;
    float sw, sh;
    if (slot < 0 || slot >= GFX_SPRITE_MAX_SLOTS) return -1;
    sl = &g_sprite_slots[slot];
    if (!sl->loaded || !sl->visible || !sl->draw_active) return -1;
    sw = (sl->draw_sw > 0) ? (float)sl->draw_sw : (float)(sl->w - sl->draw_sx);
    sh = (sl->draw_sh > 0) ? (float)sl->draw_sh : (float)(sl->h - sl->draw_sy);
    *out_x  = sl->draw_x;
    *out_y  = sl->draw_y;
    *out_z  = sl->draw_z;
    *out_dw = (int)(sw * sl->mod_sx + 0.5f);
    *out_dh = (int)(sh * sl->mod_sy + 0.5f);
    *out_ma = sl->mod_a;
    *out_mr = sl->mod_r;
    *out_mg = sl->mod_g;
    *out_mb = sl->mod_b;
    *out_sx = sl->mod_sx;
    *out_sy = sl->mod_sy;
    return 0;
}

/* Version counter incremented whenever slot RGBA data changes (load/copy/unload).
 * JS uses this to know when to rebuild its ImageBitmap cache for a slot. */
static unsigned int g_sprite_slot_version[GFX_SPRITE_MAX_SLOTS];

unsigned int gfx_sprite_slot_version(int slot)
{
    if (slot < 0 || slot >= GFX_SPRITE_MAX_SLOTS) return 0;
    return g_sprite_slot_version[slot];
}

void gfx_sprite_slot_bump_version(int slot)
{
    if (slot < 0 || slot >= GFX_SPRITE_MAX_SLOTS) return;
    g_sprite_slot_version[slot]++;
}
