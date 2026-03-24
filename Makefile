## Portable Makefile for cbm-basic
##
## Targets:
##   make         - build native binary for the current host
##   make clean   - remove built binary

TARGET = basic
SRCS   = basic.c petscii.c

# Optional gfx/test modules (feature/raylib-gfx branch)
GFX_SRCS = gfx/gfx_video.c tests/gfx_video_test.c

# Raylib-based graphics demo (Phase 1 skeleton, no interpreter)
GFX_DEMO_SRCS = gfx/gfx_video.c gfx/gfx_raylib.c
RAYLIB_CFLAGS  = $(shell pkg-config --cflags raylib 2>/dev/null)
RAYLIB_LDFLAGS = $(shell pkg-config --libs raylib 2>/dev/null) -lpthread

# Integrated graphics build: BASIC interpreter + raylib window
GFX_BIN_SRCS = basic.c petscii.c gfx/gfx_video.c gfx/gfx_raylib.c

# Reasonable defaults for modern systems; can be overridden on the command line.
CC      ?= cc
CFLAGS  ?= -Wall -Wextra -std=c99 -O2
LDFLAGS ?= -lm

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

# Web/WASM build (Emscripten); outputs web/basic.js + web/basic.wasm
# Requires: emcc (emsdk)
basic-wasm:
	@mkdir -p web
	emcc -O2 -s WASM=1 -s EXPORTED_FUNCTIONS='["_basic_load","_basic_run","_basic_halted","_basic_load_and_run","_basic_apply_arg_string"]' \
		-s EXPORTED_RUNTIME_METHODS='["ccall","cwrap","FS"]' \
		-s FORCE_FILESYSTEM=1 -s NO_EXIT_RUNTIME=1 \
		-s MODULARIZE=1 -s EXPORT_NAME='Basic' \
		-o web/basic.js basic.c petscii.c -lm
	@echo "Built web/basic.js and web/basic.wasm"

clean:
	$(RM) $(TARGET)$(EXE) gfx_video_test$(EXE) gfx-demo$(EXE) basic-gfx$(EXE)
	$(RM) web/basic.js web/basic.wasm web/basic.wasm.map 2>/dev/null || true

.PHONY: all clean gfx_video_test gfx-demo basic-gfx basic-wasm

# End of Makefile
