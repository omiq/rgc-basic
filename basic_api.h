/* basic_api.h – Public interface for embedding the CBM-BASIC interpreter.
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

/* Window title for basic-gfx. NULL = use default "CBM-BASIC GFX". */
void basic_set_gfx_window_title(const char *title);
const char *basic_get_gfx_window_title(void);

/* Border padding (pixels) around the graphical area. 0 = no border (edge-to-edge). */
void basic_set_gfx_border(int pixels);
int basic_get_gfx_border(void);
/* Border colour: palette index 0-15, or -1 to use background colour. */
void basic_set_gfx_border_color(int idx);
int basic_get_gfx_border_color(void);

/* Directory for relative PNG paths in LOADSPRITE (program file’s folder). */
void gfx_set_sprite_base_dir(const char *dir);

/* Sprite queue (thread-safe): worker enqueues, main thread loads textures & draws. */
void gfx_sprite_enqueue_load(int slot, const char *path);
void gfx_sprite_enqueue_unload(int slot);  /* BASIC: UNLOADSPRITE slot */
void gfx_sprite_enqueue_visible(int slot, int on);
/* sw/sh <= 0 means use full sub-texture from (sx,sy) to bottom-right. */
void gfx_sprite_enqueue_draw(int slot, float x, float y, int z, int sx, int sy, int sw, int sh);
int gfx_sprite_slot_width(int slot);
int gfx_sprite_slot_height(int slot);
#endif

#endif /* BASIC_API_H */
