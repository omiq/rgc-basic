## Portable Makefile for cbm-basic
##
## Targets:
##   make         - build native binary for the current host
##   make clean   - remove built binary

TARGET = basic
SRCS   = basic.c petscii.c

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

clean:
	$(RM) $(TARGET)$(EXE)

.PHONY: all clean

# End of Makefile
