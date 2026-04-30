## Portable Makefile for RGC-BASIC (Retro Game Coders BASIC)
##
## Targets:
##   make         - build native binary for the current host
##   make clean   - remove built binary

TARGET = basic
SRCS   = basic.c petscii.c

# Optional gfx/test modules (feature/raylib-gfx branch)
GFX_SRCS = gfx/gfx_video.c gfx/gfx_charrom.c gfx/pet_style_64c_data.c tests/gfx_video_test.c

# Raylib-based graphics demo (Phase 1 skeleton, no interpreter)
GFX_DEMO_SRCS = gfx/gfx_video.c gfx/gfx_charrom.c gfx/pet_style_64c_data.c gfx/gfx_raylib.c
RAYLIB_CFLAGS  = $(shell pkg-config --cflags raylib 2>/dev/null)
RAYLIB_LDFLAGS = $(shell pkg-config --libs raylib 2>/dev/null) -lpthread

# Integrated graphics build: BASIC interpreter + raylib window
GFX_BIN_SRCS = basic.c petscii.c gfx/gfx_video.c gfx/gfx_charrom.c gfx/pet_style_64c_data.c gfx/gfx_gamepad.c gfx/gfx_mouse.c gfx/gfx_raylib.c gfx/gfx_images.c gfx/gfx_sound.c

# Reasonable defaults for modern systems; can be overridden on the command line.
CC      ?= cc
# `-w` silences compiler warnings (errors still print). For diagnostics: `make CFLAGS='-Wall -Wextra -std=c99 -O2'`
CFLAGS  ?= -w -std=c99 -O2
LDFLAGS ?= -lm
# Emscripten driver (override if `emcc` is not on PATH, e.g. EMSDK_QUIET=1 source emsdk_env.sh)
EMCC    ?= emcc
# WASM: same as native; override e.g. `make basic-wasm WASM_CFLAGS='-Wall -Wextra'`
WASM_CFLAGS ?= -w

# ---------------------------------------------------------------
# Version injection. `basic --version` / `-v` prints the values
# below. Sourced at build time from git so release binaries report
# the exact tag they were built from; dev checkouts report
# "v2.0.0-3-gABCDEF[-dirty]" style. Release source tarballs (no
# .git directory) fall through to "dev" / "unknown" — override with
# `make RGC_BASIC_GIT_VERSION=v2.0.0 RGC_BASIC_GIT_DATE=2026-04-21`
# when packaging.
# ---------------------------------------------------------------
RGC_BASIC_GIT_VERSION := $(shell git describe --tags --dirty --always 2>/dev/null)
RGC_BASIC_GIT_DATE    := $(shell git log -1 --format=%as 2>/dev/null)
ifeq ($(strip $(RGC_BASIC_GIT_VERSION)),)
  RGC_BASIC_GIT_VERSION := dev
endif
ifeq ($(strip $(RGC_BASIC_GIT_DATE)),)
  RGC_BASIC_GIT_DATE := unknown
endif
VERSION_DEFINES = -DRGC_BASIC_VERSION='"$(RGC_BASIC_GIT_VERSION)"' -DRGC_BASIC_BUILD_DATE='"$(RGC_BASIC_GIT_DATE)"'

# Basic cross-platform tweaks for Windows vs POSIX
ifeq ($(OS),Windows_NT)
  EXE := .exe
  RM  := del /F /Q
  # MinGW: use static winpthread so basic-gfx.exe does not require libwinpthread-1.dll.
  RAYLIB_LDFLAGS = $(shell pkg-config --libs raylib 2>/dev/null) -Wl,-Bstatic -lwinpthread -Wl,-Bdynamic
else
  EXE :=
  RM  := rm -f
  RAYLIB_LDFLAGS = $(shell pkg-config --libs raylib 2>/dev/null) -ldl -lpthread
endif

# ---------------------------------------------------------------
# Patched raylib for native (basic-gfx). Built from third_party/raylib-native
# by scripts/build-raylib-native.sh with patches/*.patch applied — keeps
# basic-gfx and basic-wasm-raylib behaviourally in sync (e.g. the MOD-load
# freeze fix in raudio_mod_skip_max_samples.patch). System raylib from
# Homebrew / MinGW / apt is NOT used for basic-gfx because it lacks the
# patches and LoadMusicStream then hangs on .mod files. See
# scripts/build-raylib-native.sh and patches/README.md.
# ---------------------------------------------------------------
RAYLIB_NATIVE_DIR = third_party/raylib-native
RAYLIB_NATIVE_LIB = $(RAYLIB_NATIVE_DIR)/src/libraylib.a
RAYLIB_NATIVE_INC = -I$(RAYLIB_NATIVE_DIR)/src

ifeq ($(OS),Windows_NT)
  # -lshell32 needed by raylib's own Makefile default; -lole32 -loleaut32 -luuid
  # pulled in for miniaudio's WASAPI backend (stops audio init from silently
  # hanging when WMMSystem isn't enough).
  RAYLIB_NATIVE_LDLIBS = -lopengl32 -lgdi32 -lwinmm -lshell32 -lole32 -loleaut32 -luuid -Wl,-Bstatic -lwinpthread -Wl,-Bdynamic
  RAYLIB_NATIVE_BUILD  = scripts\build-raylib-native.cmd
else
  UNAME_S := $(shell uname -s)
  ifeq ($(UNAME_S),Darwin)
    # -framework CoreAudio is required — without it miniaudio's InitAudioDevice
    # crashes LoadMusicStream with SIGSEGV inside the Core Audio backend init.
    RAYLIB_NATIVE_LDLIBS = -framework CoreVideo -framework IOKit -framework Cocoa -framework OpenGL -framework CoreAudio -framework AudioToolbox -lpthread
  else
    RAYLIB_NATIVE_LDLIBS = -lGL -lm -lpthread -ldl -lrt -lX11
  endif
  RAYLIB_NATIVE_BUILD = scripts/build-raylib-native.sh
endif

# `all:` must stay the first real target in the file — `make` with no args
# builds the first one it sees, and if $(RAYLIB_NATIVE_LIB) sneaks ahead, CI
# runners without X11 headers (e.g. ubuntu-latest with no libx11-dev) try to
# compile raylib-desktop and fail in rglfw.c.
all: $(TARGET)$(EXE)

$(TARGET)$(EXE): $(SRCS)
	$(CC) $(CFLAGS) $(VERSION_DEFINES) -o $@ $(SRCS) $(LDFLAGS)

gfx_video_test: $(GFX_SRCS)
	$(CC) $(CFLAGS) -Igfx -o $@$(EXE) $(GFX_SRCS) $(LDFLAGS)

gfx-demo: $(GFX_DEMO_SRCS)
	$(CC) $(CFLAGS) -Igfx $(RAYLIB_CFLAGS) -o $@$(EXE) $(GFX_DEMO_SRCS) $(LDFLAGS) $(RAYLIB_LDFLAGS)

$(RAYLIB_NATIVE_LIB):
	$(RAYLIB_NATIVE_BUILD)

basic-gfx: $(GFX_BIN_SRCS) $(RAYLIB_NATIVE_LIB)
	$(CC) $(CFLAGS) $(VERSION_DEFINES) -DGFX_VIDEO -Igfx $(RAYLIB_NATIVE_INC) -o $@$(EXE) $(GFX_BIN_SRCS) $(LDFLAGS) $(RAYLIB_NATIVE_LIB) $(RAYLIB_NATIVE_LDLIBS)

EMCC ?= emcc

# Web/WASM build (Emscripten); outputs web/basic.js + web/basic.wasm
# Classic loader (no MODULARIZE): page sets window.Module before <script src="basic.js">.
# Requires: emcc (emsdk)
basic-wasm:
	@mkdir -p web
	$(EMCC) -w -O2 $(VERSION_DEFINES) -s WASM=1 \
		-s EXPORTED_FUNCTIONS='["_basic_load","_basic_run","_basic_halted","_basic_load_and_run","_basic_apply_arg_string","_wasm_push_key"]' \
		-s EXPORTED_RUNTIME_METHODS='["ccall","cwrap","FS","HEAPU8","HEAP16","wasmMemory","getValue"]' \
		-s FORCE_FILESYSTEM=1 -s NO_EXIT_RUNTIME=1 \
		-s INITIAL_MEMORY=33554432 \
		-s STACK_SIZE=524288 \
		-s ASYNCIFY=1 -s ASYNCIFY_IMPORTS='["emscripten_sleep","__asyncjs__wasm_js_http_fetch_async","__asyncjs__wasm_js_http_fetch_to_file_async","__asyncjs__wasm_js_host_exec_async"]' \
		-o web/basic.js basic.c petscii.c -lm
	@echo "Built web/basic.js and web/basic.wasm"

# Same interpreter as basic-wasm but MODULARIZE=1 for multiple instances (tutorial embeds).
# JS calls createBasicModular(opts).then(function(Module) { ... }).
basic-wasm-modular:
	@mkdir -p web
	$(EMCC) -w -O2 $(VERSION_DEFINES) -s WASM=1 -s MODULARIZE=1 -s EXPORT_NAME=createBasicModular \
		-s EXPORTED_FUNCTIONS='["_basic_load","_basic_run","_basic_halted","_basic_load_and_run","_basic_apply_arg_string","_wasm_push_key"]' \
		-s EXPORTED_RUNTIME_METHODS='["ccall","cwrap","FS","HEAPU8","HEAP16","wasmMemory","getValue"]' \
		-s FORCE_FILESYSTEM=1 -s NO_EXIT_RUNTIME=1 \
		-s INITIAL_MEMORY=33554432 \
		-s STACK_SIZE=524288 \
		-s ASYNCIFY=1 -s ASYNCIFY_IMPORTS='["emscripten_sleep","__asyncjs__wasm_js_http_fetch_async","__asyncjs__wasm_js_http_fetch_to_file_async","__asyncjs__wasm_js_host_exec_async"]' \
		-o web/basic-modular.js basic.c petscii.c -lm
	@echo "Built web/basic-modular.js and web/basic-modular.wasm"

# PETSCII canvas (GFX_VIDEO, no Raylib): web/basic-canvas.js + web/basic-canvas.wasm + canvas.html
basic-wasm-canvas:
	@mkdir -p web
	$(EMCC) -w -O2 $(VERSION_DEFINES) -s WASM=1 -DGFX_VIDEO -Igfx \
		-s EXPORTED_FUNCTIONS='["_basic_apply_arg_string","_basic_load_and_run_gfx","_basic_load_and_run_gfx_argline","_wasm_push_key","_wasm_gfx_rgba_ptr","_wasm_gfx_rgba_version_read","_wasm_gfx_bitmap_pixel_at","_wasm_gfx_screen_screencode_at","_wasm_gfx_key_state_set","_wasm_gfx_key_state_clear","_wasm_gfx_key_state_ptr","_wasm_gamepad_buttons_ptr","_wasm_gamepad_axes_ptr","_wasm_mouse_js_frame","_wasm_canvas_build_stamp","_wasm_canvas_set_debug","_wasm_canvas_set_debug_trace_for","_wasm_debug_log_stacks","_wasm_gfx_set_js_sprite_backend","_wasm_gfx_get_js_sprite_backend","_wasm_gfx_sprite_rgba_ptr","_wasm_gfx_sprite_w","_wasm_gfx_sprite_h","_wasm_gfx_sprite_version","_wasm_gfx_sprite_draw_params","_malloc"]' \
		-s EXPORTED_RUNTIME_METHODS='["ccall","cwrap","FS","HEAPU8","HEAP16","wasmMemory","getValue"]' \
		-s FORCE_FILESYSTEM=1 -s NO_EXIT_RUNTIME=1 \
		-s INITIAL_MEMORY=67108864 \
		-s STACK_SIZE=524288 \
		-s ASYNCIFY=1 -s ASYNCIFY_STACK_SIZE=65536 -s ASYNCIFY_IMPORTS='["emscripten_sleep","__asyncjs__wasm_js_http_fetch_async","__asyncjs__wasm_js_http_fetch_to_file_async","__asyncjs__wasm_js_host_exec_async"]' \
		-o web/basic-canvas.js basic.c petscii.c gfx/gfx_video.c gfx/gfx_charrom.c gfx/pet_style_64c_data.c gfx/gfx_gamepad.c gfx/gfx_mouse.c gfx/gfx_canvas.c gfx/gfx_software_sprites.c gfx/gfx_images.c -lm
	@echo "Built web/basic-canvas.js and web/basic-canvas.wasm"

# Experimental: raylib-emscripten WebGL2 renderer for the WASM build.
# Produces web/basic-raylib.js + web/basic-raylib.wasm. Depends on a pre-built
# libraylib.a under third_party/raylib-src/ — run scripts/build-raylib-web.sh
# once to populate it. See docs/wasm-webgl-migration-plan.md.
RAYLIB_WEB_SRC = third_party/raylib-src/src
RAYLIB_WEB_LIB = $(RAYLIB_WEB_SRC)/libraylib.a

$(RAYLIB_WEB_LIB):
	@echo "raylib-web library missing — run scripts/build-raylib-web.sh"
	@echo "  e.g. EMSDK=~/emsdk scripts/build-raylib-web.sh"
	@exit 1

basic-wasm-raylib: $(RAYLIB_WEB_LIB)
	@mkdir -p web
	$(EMCC) -w -O2 $(VERSION_DEFINES) -s WASM=1 -DGFX_VIDEO -DGFX_USE_RAYLIB -Igfx -I$(RAYLIB_WEB_SRC) \
		-s USE_GLFW=3 -s FULL_ES2=1 -s ALLOW_MEMORY_GROWTH=1 \
		-s EXPORTED_FUNCTIONS='["_basic_apply_arg_string","_basic_load_and_run_gfx","_basic_load_and_run_gfx_argline","_wasm_push_key","_wasm_gfx_key_state_set","_wasm_gfx_key_state_clear","_wasm_gfx_key_state_ptr","_wasm_gamepad_buttons_ptr","_wasm_gamepad_axes_ptr","_malloc"]' \
		-s EXPORTED_RUNTIME_METHODS='["ccall","cwrap","FS","HEAPU8","HEAP16","HEAPF32","wasmMemory","getValue"]' \
		-s FORCE_FILESYSTEM=1 -s NO_EXIT_RUNTIME=1 \
		-s INITIAL_MEMORY=67108864 \
		-s STACK_SIZE=524288 \
		-s ASYNCIFY=1 -s ASYNCIFY_STACK_SIZE=65536 -s ASYNCIFY_IMPORTS='["emscripten_sleep","__asyncjs__wasm_js_http_fetch_async","__asyncjs__wasm_js_http_fetch_to_file_async","__asyncjs__wasm_js_host_exec_async"]' \
		-s ASYNCIFY_REMOVE=@scripts/asyncify-remove.txt \
		-o web/basic-raylib.js basic.c petscii.c gfx/gfx_video.c gfx/gfx_charrom.c gfx/pet_style_64c_data.c gfx/gfx_gamepad.c gfx/gfx_mouse.c gfx/gfx_raylib.c gfx/gfx_images.c gfx/gfx_sound.c $(RAYLIB_WEB_LIB) -lm
	@echo "Built web/basic-raylib.js and web/basic-raylib.wasm"

# Headless browser smoke test (needs: pip install -r tests/requirements-wasm.txt && playwright install chromium)
wasm-test: basic-wasm
	python3 tests/wasm_browser_test.py

wasm-canvas-test: basic-wasm-canvas
	python3 tests/wasm_browser_canvas_test.py

# Same as wasm-canvas-test; use after pull/build to confirm PEEK keyboard + TI + canvas parity.
verify-canvas-wasm: basic-wasm-canvas
	python3 tests/wasm_browser_canvas_test.py

wasm-canvas-charset-test: basic-wasm-canvas
	python3 tests/wasm_canvas_charset_test.py

wasm-tutorial-test: basic-wasm-modular
	python3 tests/wasm_tutorial_embed_test.py

# Run the full native test suite locally — mirrors the .github/workflows/ci.yml
# Unix steps so devs can verify before pushing. Builds basic + gfx_video_test,
# runs the C unit test, the shell wrappers, and the headless .bas suite using
# the same skip list as CI. WASM/Playwright tests are not included here; run
# `make wasm-test wasm-canvas-test wasm-tutorial-test` separately for those.
check: $(TARGET)$(EXE) gfx_video_test lint
	@echo "==> C unit tests"
	./gfx_video_test$(EXE)
	@echo "==> shell-wrapped .bas tests"
	sh tests/get_test.sh
	sh tests/trek_test.sh >/dev/null
	sh tests/then_compound_test.sh
	@echo "==> headless .bas suite"
	sh tests/run_bas_suite.sh ./$(TARGET)$(EXE)
	@echo "==> all checks passed"

# Portability linter — validates that examples in tests/portable/ stay
# inside the rgc-basic-portable subset (suitable for transpile to
# ugBASIC and on to retro targets), and that tests/non-portable/ each
# fail with at least one error. See docs/portability-spec.md.
lint:
	@echo "==> rgc-lint (portability linter)"
	@sh tools/rgc_lint/test_lint.sh

clean:
	$(RM) $(TARGET)$(EXE) gfx_video_test$(EXE) gfx-demo$(EXE) basic-gfx$(EXE)
	$(RM) web/basic.js web/basic.wasm web/basic.wasm.map 2>/dev/null || true
	$(RM) web/basic-canvas.js web/basic-canvas.wasm web/basic-canvas.wasm.map 2>/dev/null || true
	$(RM) web/basic-modular.js web/basic-modular.wasm web/basic-modular.wasm.map 2>/dev/null || true

.PHONY: all clean check lint gfx_video_test gfx-demo basic-gfx basic-wasm basic-wasm-modular basic-wasm-canvas basic-wasm-raylib wasm-test wasm-canvas-test verify-canvas-wasm wasm-canvas-charset-test wasm-tutorial-test

# End of Makefile
