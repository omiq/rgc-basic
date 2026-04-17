/*
 * Temporary shim for the raylib-emscripten (GFX_USE_RAYLIB + __EMSCRIPTEN__)
 * WASM build.
 *
 * basic.c has a large canvas-renderer-specific block (wasm_gfx_state,
 * wasm_gfx_rgba, gfx_canvas_* sprite JS bridges, per-frame refresh calls) that
 * is compiled only for the legacy canvas build now that the narrow guard
 * excludes it when GFX_USE_RAYLIB is set. The interpreter still contains
 * scattered calls to a few entry points (wasm_gfx_refresh_js,
 * wasm_canvas_sync_charset_from_options, etc.) and the Makefile exports a few
 * names the IDE uses.
 *
 * This file provides the minimum set of stubs so the raylib-wasm target
 * links cleanly. The *real* implementations of these entry points for the
 * raylib-wasm path belong in gfx/gfx_raylib.c once the WASM main-loop shape
 * (emscripten_set_main_loop + yield-point render) is wired up — tracked in
 * docs/wasm-webgl-migration-plan.md.
 *
 * NOTHING IN THIS FILE IS CALLED BY THE CANVAS BUILD.
 */

#if defined(__EMSCRIPTEN__) && defined(GFX_USE_RAYLIB)

#include <emscripten.h>
#include <stdint.h>
#include <stddef.h>

/* basic.c calls this inside `#ifdef GFX_VIDEO` blocks after most state
 * changes. In the canvas build it rebuilds the RGBA framebuffer and bumps a
 * version counter that JS watches via requestAnimationFrame. In the raylib
 * build, raylib's own main-loop callback does the presenting — no explicit
 * refresh needed. No-op. */
void wasm_gfx_refresh_js(void)
{
}

/* basic.c calls this from #OPTION / CLI flag handlers to resync the glyph
 * tables after a charset change. The canvas build reloads gfx_charrom; the
 * raylib build reads the same GfxVideoState and will pick up the change on
 * the next render. No-op for now. */
void wasm_canvas_sync_charset_from_options(void)
{
}

/* basic.c's interpreter yields through this inside tight FOR/NEXT loops so
 * the browser event loop gets a chance to run (canvas build updates rAF,
 * pumps timers). For the raylib-wasm build the main loop will be driven by
 * emscripten_set_main_loop — yield by sleeping 0 ms for now. */
void wasm_maybe_yield_loop(void)
{
    emscripten_sleep(0);
}

/* IDE-exported entry points. These are the top-level "run a program" and
 * "query key state" calls from the iframe JS. Stubs until the raylib-wasm
 * main-loop shape is wired. Calling them today returns immediately with no
 * effect — the raylib-wasm build is not yet a usable runtime. */

extern void basic_load(const char *path);
extern void basic_run(const char *path, int nargs, char **args);

EMSCRIPTEN_KEEPALIVE
void basic_load_and_run_gfx(const char *path)
{
    /* TODO(raylib-wasm): initialise raylib window on first call, set up
     * GfxVideoState, drive render via emscripten_set_main_loop. */
    basic_load(path);
    basic_run(path, 0, NULL);
}

EMSCRIPTEN_KEEPALIVE
int basic_load_and_run_gfx_argline(const char *argline)
{
    (void)argline;
    /* TODO(raylib-wasm): parse argline, apply interpreter flags, load+run. */
    return -1;
}

/* Key-state scratch buffer; mirrors the shape of gfx_video.c's key_state[] so
 * JS can poke it directly. 256 bytes aligns with the existing PEEK(56320+n)
 * model. Real implementation will expose the actual gfx_video_state.key_state
 * pointer once gfx_raylib.c owns the state on the raylib-wasm path. */
static uint8_t g_wasm_key_state[256];

EMSCRIPTEN_KEEPALIVE
void wasm_gfx_key_state_set(int idx, int down)
{
    if (idx < 0 || idx >= 256) return;
    g_wasm_key_state[(unsigned)idx] = down ? 1 : 0;
}

EMSCRIPTEN_KEEPALIVE
void wasm_gfx_key_state_clear(void)
{
    int i;
    for (i = 0; i < 256; i++) g_wasm_key_state[i] = 0;
}

EMSCRIPTEN_KEEPALIVE
uint8_t *wasm_gfx_key_state_ptr(void)
{
    return g_wasm_key_state;
}

#endif /* __EMSCRIPTEN__ && GFX_USE_RAYLIB */
