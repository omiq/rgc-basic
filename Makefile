## Portable Makefile for cbm-basic
##
## Targets:
##   make         - build native binary for the current host
##   make clean   - remove built binary

TARGET = basic
SRCS   = basic.c

# Reasonable defaults for modern systems; can be overridden on the command line.
CC      ?= cc
CFLAGS  ?= -Wall -std=c99 -O2
LDFLAGS ?= -lm

all: $(TARGET)

$(TARGET): $(SRCS)
	@set -e; \
	M=`uname -m 2>/dev/null || echo unknown`; \
	U=`uname -s 2>/dev/null || echo unknown`; \
	case "$$U" in \
	*MINGW*|*MSYS*|*CYGWIN*) \
		PLATFORM="Windows (MinGW/Cygwin)"; \
		CC="$(CC)"; CFLAGS="$(CFLAGS)"; LDFLAGS="";; \
	Darwin) \
		PLATFORM="macOS"; \
		CC="$(CC)"; CFLAGS="$(CFLAGS)"; LDFLAGS="$(LDFLAGS)";; \
	Linux) \
		PLATFORM="Linux"; \
		CC="$(CC)"; CFLAGS="$(CFLAGS)"; LDFLAGS="$(LDFLAGS)";; \
	*) \
		PLATFORM="UNIX"; \
		CC="$(CC)"; CFLAGS="$(CFLAGS)"; LDFLAGS="$(LDFLAGS)";; \
	esac; \
	echo "Building for $$PLATFORM ($$M $$U)"; \
	$$CC $$CFLAGS -o $@ $(SRCS) $$LDFLAGS

clean:
	rm -f $(TARGET)

.PHONY: all clean

# End of Makefile
