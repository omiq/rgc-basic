/* basic_api.h – Public interface for embedding the RGC-BASIC interpreter.
 *
 * Used by the gfx build (basic-gfx) so that gfx_raylib.c can drive the
 * interpreter from its own main().  The terminal build ignores this header
 * entirely; its own main() in basic.c is compiled when GFX_VIDEO is not
 * defined.
 */

#ifndef BASIC_API_H
#define BASIC_API_H

#ifdef GFX_VIDEO
#include "gfx_video.h"
#endif

/* Parse interpreter flags (-petscii, -palette, …) from argv.
 * Returns the index of the first non-flag argument (the .bas path),
 * or -1 on error (message already printed to stderr).               */
int basic_parse_args(int argc, char **argv);

/* Same flag parsing starting at argv[start]; if expect_program_path, first
 * non-option is the .bas path (return its index). If not, all args must be
 * flags; return 0 on success, -1 on error.                           */
int basic_parse_arg_flags(int argc, char **argv, int start, int expect_program_path);

/* Load a .bas program from disk into the interpreter's line store.   */
void basic_load(const char *path);

/* Execute the loaded program.  script_path is used for ARG$(0);
 * nargs / args are the trailing command-line arguments.              */
void basic_run(const char *script_path, int nargs, char **args);

/* Non-zero once the interpreter has finished (END / error / fell off). */
int basic_halted(void);

#ifdef GFX_VIDEO
/* Set the shared video state pointer so POKE/PEEK in the interpreter
 * can reach the graphics memory.  Must be called before basic_run(). */
void basic_set_video(GfxVideoState *vs);

/* Character ROM: 0 = C64 PETSCII (default), 1 = PET-style alt font (pet_*.64c). */
int basic_get_charrom_family(void);

/* Window title for basic-gfx. NULL = use default "RGC-BASIC GFX". */
void basic_set_gfx_window_title(const char *title);
const char *basic_get_gfx_window_title(void);

/* Border padding (pixels) around the graphical area. 0 = no border (edge-to-edge). */
void basic_set_gfx_border(int pixels);
int basic_get_gfx_border(void);
/* Border colour: palette index 0-15, or -1 to use background colour. */
void basic_set_gfx_border_color(int idx);
int basic_get_gfx_border_color(void);

/* Fullscreen: 1 = stretch to monitor with letterbox (preserve aspect). */
void basic_set_gfx_fullscreen(int on);
int  basic_get_gfx_fullscreen(void);

/* Directory for relative PNG paths in LOADSPRITE (program file’s folder). */
void gfx_set_sprite_base_dir(const char *dir);

/* tile_w/tile_h > 0: sheet is a grid of that tile size (LOADSPRITE …, tw, th). */
void gfx_sprite_enqueue_load_ex(int slot, const char *path, int tile_w, int tile_h);

/* Number of tiles in a loaded sheet (0 if not tilemap or unloaded). */
int gfx_sprite_slot_tile_count(int slot);

/* Sheet grid geometry (SHEET COLS/ROWS/WIDTH/HEIGHT intrinsics).
 * Returns 0 when slot is unloaded, out-of-range, or non-tilemap. */
int gfx_sprite_slot_sheet_cols(int slot);
int gfx_sprite_slot_sheet_rows(int slot);
int gfx_sprite_slot_sheet_cell_w(int slot);
int gfx_sprite_slot_sheet_cell_h(int slot);

/* Batched tile grid stamp (TILEMAP DRAW). `tiles` is a row-major buffer
 * of 1-based tile indices of length cols*rows (truncated to tile_count);
 * index 0 = transparent (skip). x0,y0 are pixel coords of the top-left
 * cell; each cell is cell_w x cell_h (from the slot's loaded sheet).
 * Appends to the per-frame cell list, so multiple calls layer and the
 * compositor drains the list after each render pass. */
void gfx_draw_tilemap(int slot, float x0, float y0, int cols, int rows, int z,
                      const int *tiles, int tile_count);

/* Single-sprite immediate draw (SPRITE STAMP). Appends one cell to the
 * same per-frame list as gfx_draw_tilemap, so N stamps of one slot in
 * one frame all render. `frame` is a 1-based tile index; 0 or a bad
 * index falls back to the slot's current SPRITEFRAME. `rot_deg` is
 * clockwise rotation in degrees (0 = none). */
void gfx_sprite_stamp(int slot, float x, float y, int frame, int z,
                      float rot_deg);

/* Double-buffered TILEMAP / SPRITE STAMP cell list.
 *
 * BASIC appends to the BUILD buffer; the renderer reads the SHOW
 * buffer. VSYNC copies build → show atomically and clears build, so
 * programs that build a fresh scene per tick never expose a
 * half-populated list to the renderer. gfx_cells_clear() only zeroes
 * the build buffer — useful when the program wants to start over
 * without committing. */
void gfx_cells_clear(void);
void gfx_cells_flip(void);

/* Blitter surfaces (IMAGE NEW / IMAGE FREE / IMAGE COPY) — Phase 1 of
 * docs/rgc-blitter-surface-spec.md. Slot 0 is the visible bitmap. */
struct GfxVideoState;
void gfx_image_bind_visible(struct GfxVideoState *s);
int gfx_image_new(int slot, int w, int h);
int gfx_image_free(int slot);
int gfx_image_copy(int src_slot, int sx, int sy, int sw, int sh,
                   int dst_slot, int dx, int dy);
int gfx_image_width(int slot);
int gfx_image_height(int slot);
int gfx_image_save_bmp(int slot, const char *path);
int gfx_image_save_png(int slot, const char *path);
int gfx_image_save(int slot, const char *path);
int gfx_image_load(int slot, const char *path);
/* LOADSCREEN — PNG/BMP/JPG straight into the live SCREEN 2 RGBA
 * plane or SCREEN 3 indexed plane. Clips to 320x200 at (dx, dy). */
int gfx_load_png_to_indexed(struct GfxVideoState *s, const char *path, int dx, int dy);
int gfx_load_png_to_rgba(struct GfxVideoState *s, const char *path, int dx, int dy);
/* SCREEN 1 (1bpp + per-pixel colour plane): Floyd-Steinberg dither to the
 * 16 C64 palette entries. Lights every bitmap bit and fills bitmap_color[]
 * with the per-pixel index (0..15). Clips to 320x200. */
int gfx_load_png_to_bitmap(struct GfxVideoState *s, const char *path, int dx, int dy);
/* SCREEN 0 (40x25 PETSCII): cell-quantise to 1 colour + block glyph per
 * 8x8 cell. Emits glyph indices into screen[] and attribute indices into
 * color_ram[]. Clips to 40x25 at character-cell (cx, cy). */
int gfx_load_png_to_text(struct GfxVideoState *s, const char *path, int cx, int cy);
int gfx_image_new_rgba(int slot, int w, int h);
unsigned char *gfx_image_rgba_buffer(int slot);
/* Porter-Duff "source over" composite of an RGBA src slot onto an RGBA
 * destination. dst_slot == GFX_IMAGE_SLOT_VISIBLE (0) routes to the
 * live SCREEN 2 bitmap_rgba plane; other slots must have been created
 * via gfx_image_new_rgba. Returns -1 if either slot isn't RGBA. */
int gfx_image_blend(int src_slot, int sx, int sy, int sw, int sh,
                    int dst_slot, int dx, int dy);

/* Request a synchronous grab of a region of the currently-displayed
 * framebuffer (visible slot 0) into slot. Blocks the caller (interpreter
 * thread) until the render thread fulfils the grab with the fully
 * composited frame — bitmap + text + sprites + tilemap cells all
 * included, full palette + alpha. Returns 0 on success, -1 otherwise.
 * Desktop basic-gfx only; other builds should use the 1bpp fallback. */
int gfx_grab_visible_rgba(int slot, int sx, int sy, int sw, int sh);

/* ANTIALIAS toggle (raylib only). Sets the texture-filter mode used
 * by subsequently-loaded sprites and the render target. 0 = nearest
 * (hard-pixel retro look — default); non-zero = bilinear (smooth).
 * Existing textures keep their prior filter; users who want to flip
 * mid-program should reload their sprites after calling this. The
 * canvas/software WASM path is always nearest and silently ignores
 * the call. */
void gfx_set_antialias(int on);

/* 1-based tile index into a tilemap sheet; sets source rect for DRAWSPRITE crop. Returns 0 on success. */
int gfx_sprite_tile_source_rect(int slot, int tile_index_1based, int *sx, int *sy, int *sw, int *sh);

/* Animation frame for tilemap sheets (1-based tile index for DRAWSPRITE when crop omitted). 0 = same as 1. */
void gfx_sprite_set_draw_frame(int slot, int frame_1based);
int gfx_sprite_get_draw_frame(int slot);
/* Full source rect for a slot (single image or current SPRITEFRAME tile). Returns 0 on success. */
int gfx_sprite_effective_source_rect(int slot, int *sx, int *sy, int *sw, int *sh);

/* Sprite queue (thread-safe): worker enqueues, main thread loads textures & draws. */
void gfx_sprite_enqueue_load(int slot, const char *path);
void gfx_sprite_enqueue_unload(int slot);  /* BASIC: UNLOADSPRITE slot */
void gfx_sprite_enqueue_visible(int slot, int on);
void gfx_sprite_enqueue_copy(int src_slot, int dst_slot);  /* BASIC: SPRITECOPY src, dst */
/* sw/sh <= 0 means use full sub-texture from (sx,sy) to bottom-right. */
void gfx_sprite_enqueue_draw(int slot, float x, float y, int z, int sx, int sy, int sw, int sh);
/* Per-slot draw tint/scale until next LOADSPRITE/UNLOADSPRITE (basic-gfx / canvas WASM).
 * alpha 0–255 (255 = opaque), r/g/b 0–255, scale 1.0 = natural pixel size of crop. */
void gfx_sprite_set_modulate(int slot, int alpha, int r, int g, int b, float scale_x, float scale_y);
int gfx_sprite_slot_width(int slot);
int gfx_sprite_slot_height(int slot);
/* Axis-aligned bounding box overlap of last DRAWSPRITE rects (basic-gfx / canvas). */
int gfx_sprite_slots_overlap_aabb(int slot_a, int slot_b);

/* Mouse-over hit test against the slot's last enqueued DRAWSPRITE rect.
 * Returns 1 if GETMOUSEX/Y are inside [x, x+w) × [y, y+h) and the slot has
 * been drawn at least once since LOADSPRITE. 0 otherwise. Bounding-rect
 * only (MVP); pixel-perfect follow-up is planned (see
 * docs/mouse-over-sprite-plan.md). The position cache is updated on the
 * interpreter thread inside gfx_sprite_enqueue_draw, so the result reflects
 * the most recent DRAWSPRITE without waiting for the render thread. */
int gfx_sprite_is_mouse_over(int slot);

/* Axis-aligned bounding hit test at an arbitrary world point — caller
 * passes (wx, wy) already compensated for SCROLL if relevant (sprite
 * positions are stored in world space, matching SPRITECOLLIDE). */
int gfx_sprite_hit_rect(int slot, int wx, int wy);

/* Pixel-perfect hit test: same inputs, plus inverse-scales the point
 * back into the sprite's source rect and samples the alpha channel of
 * the stored CPU-side pixel buffer. `alpha_cutoff` in [0, 255] — a
 * pixel passes if alpha > alpha_cutoff. Typical values: 0 (any
 * non-zero alpha), 16 (ignore PNG edge softening dust). Returns 1
 * when the bounding rect AND the alpha test pass, else 0. Sprites
 * loaded without CPU-side pixel data fall back to the bbox result. */
int gfx_sprite_hit_pixel(int slot, int wx, int wy, int alpha_cutoff);

/* Topmost visible slot whose rect contains the world point, or -1.
 * Same bounding-box semantics as gfx_sprite_hit_rect; ties broken by
 * the highest Z of the last enqueued DRAWSPRITE (then slot index). */
int gfx_sprite_at(int wx, int wy);
#endif

#endif /* BASIC_API_H */
