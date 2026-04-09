## Portable Makefile for RGC-BASIC (Retro Game Coders BASIC)
##
## Targets:
##   make         - build native binary for the current host
##   make clean   - remove built binary

TARGET = basic
SRCS   = basic.c petscii.c

# Optional gfx/test modules (feature/raylib-gfx branch)
GFX_SRCS = gfx/gfx_video.c tests/gfx_video_test.c

# Raylib-based graphics demo (Phase 1 skeleton, no interpreter)
GFX_DEMO_SRCS = gfx/gfx_video.c gfx/gfx_charrom.c gfx/gfx_raylib.c
RAYLIB_CFLAGS  = $(shell pkg-config --cflags raylib 2>/dev/null)
RAYLIB_LDFLAGS = $(shell pkg-config --libs raylib 2>/dev/null) -lpthread

# Integrated graphics build: BASIC interpreter + raylib window
GFX_BIN_SRCS = basic.c petscii.c gfx/gfx_video.c gfx/gfx_charrom.c gfx/gfx_gamepad.c gfx/gfx_raylib.c

# Reasonable defaults for modern systems; can be overridden on the command line.
CC      ?= cc
# `-w` silences compiler warnings (errors still print). For diagnostics: `make CFLAGS='-Wall -Wextra -std=c99 -O2'`
CFLAGS  ?= -w -std=c99 -O2
LDFLAGS ?= -lm
# Emscripten driver (override if `emcc` is not on PATH, e.g. EMSDK_QUIET=1 source emsdk_env.sh)
EMCC    ?= emcc
# WASM: same as native; override e.g. `make basic-wasm WASM_CFLAGS='-Wall -Wextra'`
WASM_CFLAGS ?= -w

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

all: $(TARGET)$(EXE)

$(TARGET)$(EXE): $(SRCS)
	$(CC) $(CFLAGS) -o $@ $(SRCS) $(LDFLAGS)

gfx_video_test: $(GFX_SRCS)
	$(CC) $(CFLAGS) -Igfx -o $@$(EXE) $(GFX_SRCS) $(LDFLAGS)

gfx-demo: $(GFX_DEMO_SRCS)
	$(CC) $(CFLAGS) -Igfx $(RAYLIB_CFLAGS) -o $@$(EXE) $(GFX_DEMO_SRCS) $(LDFLAGS) $(RAYLIB_LDFLAGS)

basic-gfx: $(GFX_BIN_SRCS)
	$(CC) $(CFLAGS) -DGFX_VIDEO -Igfx $(RAYLIB_CFLAGS) -o $@$(EXE) $(GFX_BIN_SRCS) $(LDFLAGS) $(RAYLIB_LDFLAGS)

EMCC ?= emcc

# Web/WASM build (Emscripten); outputs web/basic.js + web/basic.wasm
# Classic loader (no MODULARIZE): page sets window.Module before <script src="basic.js">.
# Requires: emcc (emsdk)
basic-wasm:
	@mkdir -p web
	$(EMCC) -w -O2 -s WASM=1 \
		-s EXPORTED_FUNCTIONS='["_basic_load","_basic_run","_basic_halted","_basic_load_and_run","_basic_apply_arg_string","_wasm_push_key"]' \
		-s EXPORTED_RUNTIME_METHODS='["ccall","cwrap","FS","HEAPU8","HEAP16","wasmMemory","getValue"]' \
		-s FORCE_FILESYSTEM=1 -s NO_EXIT_RUNTIME=1 \
		-s INITIAL_MEMORY=33554432 \
		-s STACK_SIZE=524288 \
		-s ASYNCIFY=1 -s ASYNCIFY_IMPORTS='["emscripten_sleep","__asyncjs__wasm_js_http_fetch_async"]' \
		-o web/basic.js basic.c petscii.c -lm
	@echo "Built web/basic.js and web/basic.wasm"

# Same interpreter as basic-wasm but MODULARIZE=1 for multiple instances (tutorial embeds).
# JS calls createBasicModular(opts).then(function(Module) { ... }).
basic-wasm-modular:
	@mkdir -p web
	$(EMCC) -w -O2 -s WASM=1 -s MODULARIZE=1 -s EXPORT_NAME=createBasicModular \
		-s EXPORTED_FUNCTIONS='["_basic_load","_basic_run","_basic_halted","_basic_load_and_run","_basic_apply_arg_string","_wasm_push_key"]' \
		-s EXPORTED_RUNTIME_METHODS='["ccall","cwrap","FS","HEAPU8","HEAP16","wasmMemory","getValue"]' \
		-s FORCE_FILESYSTEM=1 -s NO_EXIT_RUNTIME=1 \
		-s INITIAL_MEMORY=33554432 \
		-s STACK_SIZE=524288 \
		-s ASYNCIFY=1 -s ASYNCIFY_IMPORTS='["emscripten_sleep","__asyncjs__wasm_js_http_fetch_async"]' \
		-o web/basic-modular.js basic.c petscii.c -lm
	@echo "Built web/basic-modular.js and web/basic-modular.wasm"

# PETSCII canvas (GFX_VIDEO, no Raylib): web/basic-canvas.js + web/basic-canvas.wasm + canvas.html
basic-wasm-canvas:
	@mkdir -p web
	$(EMCC) -w -O2 -s WASM=1 -DGFX_VIDEO -Igfx \
		-s EXPORTED_FUNCTIONS='["_basic_apply_arg_string","_basic_load_and_run_gfx","_wasm_push_key","_wasm_gfx_rgba_ptr","_wasm_gfx_rgba_version_read","_wasm_gfx_screen_screencode_at","_wasm_gfx_key_state_set","_wasm_gfx_key_state_clear","_wasm_gfx_key_state_ptr","_wasm_gamepad_buttons_ptr","_wasm_gamepad_axes_ptr","_wasm_canvas_build_stamp","_wasm_canvas_set_debug","_wasm_canvas_set_debug_trace_for","_wasm_debug_log_stacks"]' \
		-s EXPORTED_RUNTIME_METHODS='["ccall","cwrap","FS","HEAPU8","HEAP16","wasmMemory","getValue"]' \
		-s FORCE_FILESYSTEM=1 -s NO_EXIT_RUNTIME=1 \
		-s INITIAL_MEMORY=67108864 \
		-s STACK_SIZE=524288 \
		-s ASYNCIFY=1 -s ASYNCIFY_IMPORTS='["emscripten_sleep","__asyncjs__wasm_js_http_fetch_async"]' \
		-o web/basic-canvas.js basic.c petscii.c gfx/gfx_video.c gfx/gfx_charrom.c gfx/gfx_gamepad.c gfx/gfx_canvas.c gfx/gfx_software_sprites.c -lm
	@echo "Built web/basic-canvas.js and web/basic-canvas.wasm"

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

clean:
	$(RM) $(TARGET)$(EXE) gfx_video_test$(EXE) gfx-demo$(EXE) basic-gfx$(EXE)
	$(RM) web/basic.js web/basic.wasm web/basic.wasm.map 2>/dev/null || true
	$(RM) web/basic-canvas.js web/basic-canvas.wasm web/basic-canvas.wasm.map 2>/dev/null || true
	$(RM) web/basic-modular.js web/basic-modular.wasm web/basic-modular.wasm.map 2>/dev/null || true

.PHONY: all clean gfx_video_test gfx-demo basic-gfx basic-wasm basic-wasm-modular basic-wasm-canvas wasm-test wasm-canvas-test verify-canvas-wasm wasm-canvas-charset-test wasm-tutorial-test

# End of Makefile
