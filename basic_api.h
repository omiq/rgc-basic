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
#endif

#endif /* BASIC_API_H */
