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
RAYLIB_LDFLAGS = $(shell pkg-config --libs raylib 2>/dev/null) -ldl -lpthread

# Integrated graphics build: BASIC interpreter + raylib window
GFX_BIN_SRCS = basic.c petscii.c gfx/gfx_video.c gfx/gfx_raylib.c

# Reasonable defaults for modern systems; can be overridden on the command line.
CC      ?= cc
CFLAGS  ?= -Wall -std=c99 -O2
LDFLAGS ?= -lm

# Basic cross-platform tweaks for Windows vs POSIX
ifeq ($(OS),Windows_NT)
  EXE := .exe
  RM  := del /F /Q
else
  EXE :=
  RM  := rm -f
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

clean:
	$(RM) $(TARGET)$(EXE) gfx_video_test$(EXE) gfx-demo$(EXE) basic-gfx$(EXE)

.PHONY: all clean gfx_video_test gfx-demo basic-gfx

# End of Makefile
