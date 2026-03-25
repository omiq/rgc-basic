/* No-op sprite queue for builds without Raylib (browser canvas). */

#include "gfx_video.h"

void gfx_set_sprite_base_dir(const char *dir)
{
    (void)dir;
}

void gfx_sprite_enqueue_load(int slot, const char *path)
{
    (void)slot;
    (void)path;
}

void gfx_sprite_enqueue_unload(int slot)
{
    (void)slot;
}

void gfx_sprite_enqueue_visible(int slot, int on)
{
    (void)slot;
    (void)on;
}

void gfx_sprite_enqueue_draw(int slot, float x, float y, int z, int sx, int sy, int sw, int sh)
{
    (void)slot;
    (void)x;
    (void)y;
    (void)z;
    (void)sx;
    (void)sy;
    (void)sw;
    (void)sh;
}

int gfx_sprite_slot_width(int slot)
{
    (void)slot;
    return 0;
}

int gfx_sprite_slot_height(int slot)
{
    (void)slot;
    return 0;
}
