/* Software PNG sprites for headless / WASM canvas (no Raylib).
 * Mirrors gfx_raylib.c queue semantics: LOADSPRITE queues decode on the worker;
 * gfx_sprite_process_queue() applies pending commands (called from render + SPRITEW/H). */

#include "gfx_software_sprites.h"
#include "gfx_video.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"

#define GFX_SPRITE_MAX_SLOTS 64
#define GFX_SPRITE_Q_CAP 256
#define GFX_SPRITE_PATH_MAX 512

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
    int tile_w, tile_h;
} GfxSpriteCmd;

typedef struct {
    int loaded;
    int visible;
    int w, h;
    int tile_w, tile_h;
    int tiles_x, tiles_y;
    int tile_count;
    unsigned char *rgba; /* malloc'd w*h*4, straight alpha */
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

static char g_sprite_base_dir[GFX_SPRITE_PATH_MAX];
static GfxSpriteSlot g_sprite_slots[GFX_SPRITE_MAX_SLOTS];
static GfxSpriteCmd g_sprite_q[GFX_SPRITE_Q_CAP];
static int g_sprite_q_count;

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

            stbi_set_flip_vertically_on_load(0);
            pix = stbi_load(full, &w, &h, &comp, 4);
            if (pix && w > 0 && h > 0) {
                sl->rgba = pix;
                sl->w = w;
                sl->h = h;
                sl->loaded = 1;
                sl->visible = 1;
                sl->draw_active = 0;
                sl->tile_w = tw;
                sl->tile_h = th;
                if (tw > 0 && th > 0 && w >= tw && h >= th) {
                    sl->tiles_x = w / tw;
                    sl->tiles_y = h / th;
                    sl->tile_count = sl->tiles_x * sl->tiles_y;
                } else {
                    sl->tile_w = sl->tile_h = 0;
                    sl->tile_count = 1;
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
    GfxSpriteDraw draws[GFX_SPRITE_MAX_SLOTS];
    int nd = 0;
    int i, dx, dy;

    if (!s || !rgba || fb_w <= 0 || fb_h <= 0) {
        return;
    }

    gfx_sprite_process_queue();

    for (i = 0; i < GFX_SPRITE_MAX_SLOTS; i++) {
        GfxSpriteSlot *sl = &g_sprite_slots[i];
        if (!sl->loaded || !sl->visible || !sl->draw_active) {
            continue;
        }
        if (nd >= GFX_SPRITE_MAX_SLOTS) {
            break;
        }
        draws[nd].slot = i;
        draws[nd].x = sl->draw_x;
        draws[nd].y = sl->draw_y;
        draws[nd].z = sl->draw_z;
        draws[nd].sx = sl->draw_sx;
        draws[nd].sy = sl->draw_sy;
        draws[nd].sw = sl->draw_sw;
        draws[nd].sh = sl->draw_sh;
        nd++;
    }

    if (nd <= 0) {
        return;
    }

    qsort(draws, (size_t)nd, sizeof(draws[0]), cmp_sprite_draw_z);

    for (i = 0; i < nd; i++) {
        GfxSpriteDraw *d = &draws[i];
        int sidx = d->slot;
        GfxSpriteSlot *sl;
        float sx, sy, sw, sh;
        int src_x0, src_y0, iw, ih;
        int x0, y0, x1, y1;

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

        x0 = (int)d->x;
        y0 = (int)d->y;
        x1 = x0 + iw - 1;
        y1 = y0 + ih - 1;

        if (x1 < 0 || y1 < 0 || x0 >= fb_w || y0 >= fb_h) {
            continue;
        }

        for (dy = 0; dy < ih; dy++) {
            int syi = src_y0 + dy;
            int dst_y = y0 + dy;
            if (dst_y < 0 || dst_y >= fb_h) {
                continue;
            }
            for (dx = 0; dx < iw; dx++) {
                int sxi = src_x0 + dx;
                int dst_x = x0 + dx;
                unsigned char *sp;
                unsigned sa, inv;
                size_t doff;

                if (dst_x < 0 || dst_x >= fb_w) {
                    continue;
                }
                sp = sl->rgba + ((size_t)syi * (size_t)sl->w + (size_t)sxi) * 4u;
                sa = sp[3];
                if (sa == 0) {
                    continue;
                }

                doff = ((size_t)dst_y * (size_t)fb_w + (size_t)dst_x) * 4u;
                if (sa == 255) {
                    rgba[doff + 0] = sp[0];
                    rgba[doff + 1] = sp[1];
                    rgba[doff + 2] = sp[2];
                    rgba[doff + 3] = 0xFF;
                } else {
                    inv = (unsigned)(255 - sa);
                    rgba[doff + 0] = (unsigned char)((sp[0] * sa + rgba[doff + 0] * inv + 127) / 255);
                    rgba[doff + 1] = (unsigned char)((sp[1] * sa + rgba[doff + 1] * inv + 127) / 255);
                    rgba[doff + 2] = (unsigned char)((sp[2] * sa + rgba[doff + 2] * inv + 127) / 255);
                    rgba[doff + 3] = 0xFF;
                }
            }
        }
    }
}
