/*
 *
 *    _____ ____  __  __        ____           _____ _____ _____ 
 *   / ____|  _ \|  \/  |      |  _ \   /\    / ____|_   _/ ____|
 *  | |    | |_) | \  / |______| |_) | /  \  | (___   | || |     
 *  | |    |  _ <| |\/| |______|  _ < / /\ \  \___ \  | || |     
 *  | |____| |_) | |  | |      | |_) / ____ \ ____) |_| || |____ 
 *   \_____|____/|_|  |_|      |____/_/    \_\_____/|_____\_____|                                                           
 *  .............................................................
 *
 *  [Version 0.1.0]
 * 
 * BASIC interpreter targeting CBM BASIC v2 style programs.
 * Copyright (C) 2024  Davepl with various AI assists
 *
 * Based on the original by David Plummer:
 * https://github.com/davepl/pdpsrc/tree/main/bsd/basic
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 *
 * BASIC banner: implements a minimal 6502 Microsoft/CBM BASIC v2 compatible
 * interpreter (PRINT, INPUT, IF/THEN, FOR/NEXT, GOTO, GOSUB, DIM, etc.).
 */

#if (defined(__unix__) || defined(__linux__) || defined(__APPLE__) || defined(__MACH__)) && !defined(_POSIX_C_SOURCE) && !defined(_GNU_SOURCE)
#define _POSIX_C_SOURCE 200809L
#endif
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <math.h>
#include <time.h>
#include "petscii.h"

#ifdef GFX_VIDEO
#include "gfx_video.h"
#endif
#if defined(_WIN32)
#include <windows.h>
#include <conio.h>
#else
#if defined(__unix__) || defined(__APPLE__) || defined(__MACH__)
#include <unistd.h>
#include <termios.h>
#endif
#ifndef HAVE_USLEEP
#include <sys/types.h>
#include <sys/times.h>
#include <sys/param.h>
#include <sys/time.h>
#endif
#ifndef HAVE_USLEEP
#if defined(__APPLE__) || defined(__MACH__) || defined(__linux__) || defined(_POSIX_VERSION)
#define HAVE_USLEEP 1
#endif
#endif
#endif

/* Helper structures for token expansion inside BASIC strings
 * (e.g., translating {RED} to CHR$(28) at source level).
 */
typedef struct {
    char *buf;
    size_t len;
    size_t cap;
} StrBuf;

typedef struct {
    const char *name;
    int code;
} TokenMap;

static int is_ident_char(int c)
{
    return isalpha((unsigned char)c) || isdigit((unsigned char)c) || c == '$' || c == '_';
}

static const TokenMap token_map[] = {
    {"WHITE", 5},
    {"RED", 28},
    {"CYAN", 159},
    {"PURPLE", 156},
    {"GREEN", 30},
    {"BLUE", 31},
    {"YELLOW", 158},
    {"ORANGE", 129},
    {"BROWN", 149},
    {"PINK", 150},
    {"GRAY1", 151},
    {"GREY1", 151},
    {"GRAY2", 152},
    {"GREY2", 152},
    {"LIGHTGREEN", 153},
    {"LIGHT GREEN", 153},
    {"LIGHTBLUE", 154},
    {"LIGHT BLUE", 154},
    {"GRAY3", 155},
    {"GREY3", 155},
    {"BLACK", 144},

    {"HOME", 19},
    {"DOWN", 17},
    {"UP", 145},
    {"LEFT", 157},
    {"RIGHT", 29},
    {"DEL", 20},
    {"DELETE", 20},
    {"INS", 148},
    {"INSERT", 148},
    {"CLR", 147},
    {"CLEAR", 147},

    {"RVS", 18},
    {"REVERSE ON", 18},
    {"RVS OFF", 146},
    {"REVERSE OFF", 146},

    {NULL, 0}
};

/* PETSCII/ANSI mode (set by -petscii, #OPTION); declared early for gfx_put_byte. */
static int petscii_mode = 0;

static void sb_init(StrBuf *sb)
{
    sb->cap = 256;
    sb->len = 0;
    sb->buf = (char *)malloc(sb->cap);
    if (!sb->buf) {
        fprintf(stderr, "Out of memory\n");
        exit(1);
    }
    sb->buf[0] = '\0';
}

static void sb_reserve(StrBuf *sb, size_t extra)
{
    if (sb->len + extra + 1 <= sb->cap) {
        return;
    }
    while (sb->len + extra + 1 > sb->cap) {
        sb->cap *= 2;
    }
    {
        char *newbuf = (char *)realloc(sb->buf, sb->cap);
        if (!newbuf) {
            free(sb->buf);
            fprintf(stderr, "Out of memory\n");
            exit(1);
        }
        sb->buf = newbuf;
    }
}

static void sb_append_char(StrBuf *sb, char c)
{
    sb_reserve(sb, 1);
    sb->buf[sb->len++] = c;
    sb->buf[sb->len] = '\0';
}

static void sb_append_mem(StrBuf *sb, const char *s, size_t n)
{
    sb_reserve(sb, n);
    memcpy(sb->buf + sb->len, s, n);
    sb->len += n;
    sb->buf[sb->len] = '\0';
}

static void sb_append_str(StrBuf *sb, const char *s)
{
    sb_append_mem(sb, s, strlen(s));
}

static char *dup_upper_trim(const char *src, size_t len)
{
    char *out;
    size_t i;

    while (len > 0 && isspace((unsigned char)*src)) {
        src++;
        len--;
    }
    while (len > 0 && isspace((unsigned char)src[len - 1])) {
        len--;
    }

    out = (char *)malloc(len + 1);
    if (!out) {
        fprintf(stderr, "Out of memory\n");
        exit(1);
    }

    for (i = 0; i < len; i++) {
        out[i] = (char)toupper((unsigned char)src[i]);
    }
    out[len] = '\0';
    return out;
}

static int lookup_token_code(const char *token, int *code_out)
{
    char *endptr = NULL;
    long n;

    n = strtol(token, &endptr, 10);
    if (*token != '\0' && *endptr == '\0') {
        if (n >= 0 && n <= 255) {
            *code_out = (int)n;
            return 1;
        }
        return 0;
    }

    {
        int i;
        for (i = 0; token_map[i].name != NULL; i++) {
            if (strcmp(token, token_map[i].name) == 0) {
                *code_out = token_map[i].code;
                return 1;
            }
        }
    }

    return 0;
}

static void append_quoted(StrBuf *out, const char *text, size_t len)
{
    sb_append_char(out, '\"');
    sb_append_mem(out, text, len);
    sb_append_char(out, '\"');
}

/* Transform a BASIC source line so that tokens inside quoted strings of the form
 *   "HELLO {RED}WORLD"
 * are expanded to:
 *   "HELLO ";CHR$(28);"WORLD"
 * Tokens map either to explicit numeric CHR$ codes or to named PETSCII
 * control/color names in token_map[].
 */
static char *transform_basic_line(const char *input)
{
    StrBuf out;
    int in_string = 0;
    const char *segment_start = NULL;
    int piece_count = 0;
    size_t i;

    sb_init(&out);

    for (i = 0; input[i] != '\0'; i++) {
        char c = input[i];

        if (!in_string) {
            if (c == '\"') {
                in_string = 1;
                segment_start = input + i + 1;
                piece_count = 0;
            } else {
                sb_append_char(&out, c);
            }
            continue;
        }

        if (c == '{') {
            size_t j = i + 1;
            while (input[j] != '\0' && input[j] != '}') {
                j++;
            }

            if (input[j] == '}') {
                char *token = dup_upper_trim(input + i + 1, j - (i + 1));
                int code = 0;

                if (lookup_token_code(token, &code)) {
                    size_t seg_len = (size_t)((input + i) - segment_start);

                    if (seg_len > 0) {
                        if (piece_count > 0) {
                            sb_append_char(&out, '+');
                        }
                        append_quoted(&out, segment_start, seg_len);
                        piece_count++;
                    }

                    if (piece_count > 0) {
                        sb_append_char(&out, '+');
                    }

                    {
                        char tmp[32];
                        sprintf(tmp, "CHR$(%d)", code);
                        sb_append_str(&out, tmp);
                    }
                    piece_count++;

                    segment_start = input + j + 1;
                    i = j;
                    free(token);
                    continue;
                }

                free(token);
            }

            continue;
        }

        if (c == '\"') {
            size_t seg_len = (size_t)((input + i) - segment_start);

            if (seg_len > 0 || piece_count == 0) {
                if (piece_count > 0) {
                    sb_append_char(&out, '+');
                }
                append_quoted(&out, segment_start, seg_len);
            }

            in_string = 0;
            segment_start = NULL;
            piece_count = 0;
            continue;
        }
    }

    if (in_string) {
        sb_append_char(&out, '\"');
        if (segment_start) {
            sb_append_str(&out, segment_start);
        }
    }

    return out.buf;
}

/* Normalize certain keywords in a BASIC source line to restore
 * CBM-style whitespace that may have been stripped, e.g.:
 *   IFB3<1THENIFE>10ORD(7)=0THEN GOTO 890
 * becomes:
 *   IF B3<1 THEN IF E>10 OR D(7)=0 THEN GOTO 890
 * The transformation is applied only outside of quoted strings.
 */
static char *normalize_keywords_line(const char *input)
{
    StrBuf out;
    int in_string = 0;
    size_t i = 0;

    sb_init(&out);

    while (input[i] != '\0') {
        char c = input[i];

        if (c == '\"') {
            in_string = !in_string;
            sb_append_char(&out, c);
            i++;
            continue;
        }

        if (!in_string) {
            char c1 = (char)toupper((unsigned char)c);
            char c2 = (char)toupper((unsigned char)input[i + 1]);
            char c3 = (char)toupper((unsigned char)input[i + 2]);
            char c4 = (char)toupper((unsigned char)input[i + 3]);

            /* IF followed immediately by identifier/digit without space */
            if (c1 == 'I' && c2 == 'F') {
                char next = input[i + 2];
                if (next != '\0' && !isspace((unsigned char)next) && next != ':' ) {
                    /* Insert space before IF if needed */
                    if (out.len > 0) {
                        char prev = out.buf[out.len - 1];
                        if (!isspace((unsigned char)prev) && prev != ':' && prev != '(') {
                            sb_append_char(&out, ' ');
                        }
                    }
                    sb_append_str(&out, "IF");
                    i += 2;
                    /* Ensure space after IF */
                    sb_append_char(&out, ' ');
                    continue;
                }
            }

            /* FOR followed immediately by identifier/digit: FORI=1TO9 -> FOR I=1TO9 */
            if (c1 == 'F' && c2 == 'O' && c3 == 'R') {
                char next = input[i + 3];
                if (next != '\0' && !isspace((unsigned char)next) && next != ':' ) {
                    if (out.len > 0) {
                        char prev = out.buf[out.len - 1];
                        if (!isspace((unsigned char)prev) && prev != ':' && prev != '(') {
                            sb_append_char(&out, ' ');
                        }
                    }
                    sb_append_str(&out, "FOR");
                    i += 3;
                    sb_append_char(&out, ' ');
                    continue;
                }
            }

            /* GOTO followed immediately by digit: GOTO410 -> GOTO 410 */
            if (c1 == 'G' && c2 == 'O' && c3 == 'T' && (char)toupper((unsigned char)input[i + 3]) == 'O') {
                char next = input[i + 4];
                if (next != '\0' && !isspace((unsigned char)next) && next != ':' ) {
                    if (out.len > 0) {
                        char prev = out.buf[out.len - 1];
                        if (!isspace((unsigned char)prev) && prev != ':' && prev != '(') {
                            sb_append_char(&out, ' ');
                        }
                    }
                    sb_append_str(&out, "GOTO");
                    i += 4;
                    sb_append_char(&out, ' ');
                    continue;
                }
            }

            /* GOSUB followed immediately by digit: GOSUB410 -> GOSUB 410 */
            if (c1 == 'G' && c2 == 'O' && c3 == 'S' && c4 == 'U' &&
                (char)toupper((unsigned char)input[i + 4]) == 'B') {
                char next = input[i + 5];
                if (next != '\0' && !isspace((unsigned char)next) && next != ':' ) {
                    if (out.len > 0) {
                        char prev = out.buf[out.len - 1];
                        if (!isspace((unsigned char)prev) && prev != ':' && prev != '(') {
                            sb_append_char(&out, ' ');
                        }
                    }
                    sb_append_str(&out, "GOSUB");
                    i += 5;
                    sb_append_char(&out, ' ');
                    continue;
                }
            }

            /* NEXT followed immediately by identifier: NEXTI -> NEXT I */
            if (c1 == 'N' && c2 == 'E' && c3 == 'X' && c4 == 'T') {
                char next = input[i + 4];
                if (out.len > 0) {
                    char prev = out.buf[out.len - 1];
                    if (!isspace((unsigned char)prev) && prev != ':' && prev != '(') {
                        sb_append_char(&out, ' ');
                    }
                }
                sb_append_str(&out, "NEXT");
                i += 4;
                if (next != '\0' && !isspace((unsigned char)next) && next != ':' ) {
                    sb_append_char(&out, ' ');
                }
                continue;
            }

            /* THEN */
            if (c1 == 'T' && c2 == 'H' && c3 == 'E' && c4 == 'N') {
                /* Insert space before THEN if needed */
                if (out.len > 0) {
                    char prev = out.buf[out.len - 1];
                    if (!isspace((unsigned char)prev) && prev != ':' && prev != '(') {
                        sb_append_char(&out, ' ');
                    }
                }
                sb_append_str(&out, "THEN");
                i += 4;
                /* Skip any existing spaces after THEN */
                while (isspace((unsigned char)input[i])) {
                    i++;
                }
                /* Ensure one space after THEN if next char is non-separator */
                if (input[i] != '\0' && input[i] != ':' && !isspace((unsigned char)input[i])) {
                    sb_append_char(&out, ' ');
                }
                continue;
            }

            /* TO inside numeric ranges: 1TO9 -> 1 TO 9, but never split GOTO. */
            if (c1 == 'T' && c2 == 'O') {
                size_t j;
                char prev_ns = ' ';
                char next_ns = '\0';

                /* Skip if this is the TO in GOTO (e.g. ...GOTO 100). */
                if (i >= 2) {
                    char g = (char)toupper((unsigned char)input[i - 2]);
                    char o = (char)toupper((unsigned char)input[i - 1]);
                    if (g == 'G' && o == 'O') {
                        /* fall through to normal character handling */
                    } else {
                        /* Find previous non-space character. */
                        j = i;
                        while (j > 0) {
                            j--;
                            if (!isspace((unsigned char)input[j])) {
                                prev_ns = input[j];
                                break;
                            }
                        }
                        /* Find next non-space character after TO. */
                        j = i + 2;
                        while (input[j] != '\0' && isspace((unsigned char)input[j])) {
                            j++;
                        }
                        next_ns = input[j];

                        /* Treat as TO only when between numeric-ish tokens, like 1TO9. */
                        if ((isdigit((unsigned char)prev_ns) || prev_ns == ')') &&
                            (isdigit((unsigned char)next_ns) || next_ns == '+' || next_ns == '-')) {
                            if (out.len > 0) {
                                char prev = out.buf[out.len - 1];
                                if (!isspace((unsigned char)prev) && prev != '(') {
                                    sb_append_char(&out, ' ');
                                }
                            }
                            sb_append_str(&out, "TO");
                            i += 2;
                            if (next_ns != '\0' && !isspace((unsigned char)next_ns) &&
                                next_ns != ':' && next_ns != ')') {
                                sb_append_char(&out, ' ');
                            }
                            continue;
                        }
                    }
                }
            }

            /* AND / OR infix operators without spaces.
             * Only treat as operators when they are not embedded in identifiers
             * (e.g., avoid splitting FOR into F OR, or ORD into OR D).
             */
            if (c1 == 'A' && c2 == 'N' && c3 == 'D') {
                char prev_in = (i > 0) ? input[i - 1] : ' ';
                char next_in = input[i + 3];
                if (!is_ident_char(prev_in) && !is_ident_char(next_in)) {
                    /* Surround AND with spaces */
                    if (out.len > 0) {
                        char prev = out.buf[out.len - 1];
                        if (!isspace((unsigned char)prev) && prev != '(') {
                            sb_append_char(&out, ' ');
                        }
                    }
                    sb_append_str(&out, "AND");
                    i += 3;
                    if (input[i] != '\0' && !isspace((unsigned char)input[i]) && input[i] != ')') {
                        sb_append_char(&out, ' ');
                    }
                    continue;
                }
            }
            if (c1 == 'O' && c2 == 'R') {
                char prev_in = (i > 0) ? input[i - 1] : ' ';
                char next_in = input[i + 2];
                if (!is_ident_char(prev_in) && !is_ident_char(next_in)) {
                    if (out.len > 0) {
                        char prev = out.buf[out.len - 1];
                        if (!isspace((unsigned char)prev) && prev != '(') {
                            sb_append_char(&out, ' ');
                        }
                    }
                    sb_append_str(&out, "OR");
                    i += 2;
                    if (input[i] != '\0' && !isspace((unsigned char)input[i]) && input[i] != ')') {
                        sb_append_char(&out, ' ');
                    }
                    continue;
                }
            }
        }

        sb_append_char(&out, c);
        i++;
    }

    return out.buf;
}

/* Platform-specific handling for ANSI escape sequences.
 * On Unix-like systems (macOS/Linux), standard ANSI escapes work in most terminals.
 * On Windows, we enable virtual terminal processing where available so that
 * ANSI color/control sequences render correctly instead of being printed literally. */
#if defined(_WIN32)
static int ansi_enabled = 0;

static void init_console_ansi(void)
{
    HANDLE hOut;
    DWORD mode;

    hOut = GetStdHandle(STD_OUTPUT_HANDLE);
    if (hOut == INVALID_HANDLE_VALUE || hOut == NULL) {
        return;
    }
    if (!GetConsoleMode(hOut, &mode)) {
        return;
    }
    mode |= ENABLE_VIRTUAL_TERMINAL_PROCESSING;
    if (!SetConsoleMode(hOut, mode)) {
        return;
    }
    ansi_enabled = 1;
}
#else
static void init_console_ansi(void)
{
    /* Standard ANSI escapes are generally supported on macOS/Linux terminals. */
}
#endif

// DEFINES

#define MAX_LINES 1024
#define MAX_LINE_LEN 256
#define MAX_INCLUDE_DEPTH 16
#define MAX_INCLUDE_PATH  512

static char include_path_store[MAX_INCLUDE_DEPTH][MAX_INCLUDE_PATH];
#define MAX_VARS 128
#define VAR_NAME_MAX 32
#define MAX_GOSUB 64
#define MAX_FOR 32
#define MAX_STR_LEN 256
#define DEFAULT_ARRAY_SIZE 11
#define PRINT_WIDTH 40
#ifndef TICKS_PER_SEC_FALLBACK
#ifdef HZ
#define TICKS_PER_SEC_FALLBACK HZ
#else
#define TICKS_PER_SEC_FALLBACK 60
#endif
#endif

enum value_type { VAL_NUM = 0, VAL_STR = 1 };

struct value {
    int type;
    double num;
    char str[MAX_STR_LEN];
};

struct line {
    int number;
    char *text;
};

#define MAX_DIMS 3

struct var {
    char name[VAR_NAME_MAX];
    int is_string;
    int is_array;
    int dims;                      /* 0 for scalar, >=1 for arrays */
    int dim_sizes[MAX_DIMS];       /* per-dimension sizes */
    int size;                      /* total number of elements (product of dim_sizes) */
    struct value scalar;
    struct value *array;           /* flat buffer of length size */
};

struct gosub_frame {
    int line_index;
    char *position;
};

struct for_frame {
    char name[VAR_NAME_MAX];
    int is_string;
    double end_value;
    double step;
    int line_index;
    char *resume_pos;
    struct value *var;
};

static struct line *program_lines[MAX_LINES];
static int line_count = 0;

static struct var vars[MAX_VARS];
static int var_count = 0;

static struct gosub_frame gosub_stack[MAX_GOSUB];
static int gosub_top = 0;

static struct for_frame for_stack[MAX_FOR];
static int for_top = 0;

/* IF ELSE END IF block stack */
#define MAX_IF_DEPTH 16
struct if_block {
    int took_then;    /* 1 if we executed THEN branch, 0 if we skipped to ELSE/END IF */
};
static struct if_block if_stack[MAX_IF_DEPTH];
static int if_depth = 0;

/* WHILE WEND block stack */
#define MAX_WHILE_DEPTH 16
struct while_frame {
    int line_index;
    char *position;
};
static struct while_frame while_stack[MAX_WHILE_DEPTH];
static int while_top = 0;

/* DO LOOP block stack */
#define MAX_DO_DEPTH 16
struct do_frame {
    int line_index;
    char *position;
};
static struct do_frame do_stack[MAX_DO_DEPTH];
static int do_top = 0;

#define MAX_UDF_PARAMS 16
#define MAX_UDF_FUNCS  32
#define MAX_UDF_DEPTH  16

struct udf_func {
    char name[VAR_NAME_MAX];
    int param_count;
    char param_names[MAX_UDF_PARAMS][VAR_NAME_MAX];
    int param_is_string[MAX_UDF_PARAMS];
    int body_line;
    char *body_pos;
};

static struct udf_func udf_funcs[MAX_UDF_FUNCS];
static int udf_func_count = 0;

static int udf_call_depth = 0;
static struct value udf_return_value;
static int udf_returned = 0;

struct udf_call_frame {
    int func_index;
    int saved_line;
    char *saved_pos;
    struct value saved_params[MAX_UDF_PARAMS];
};

static struct udf_call_frame udf_call_stack[MAX_UDF_DEPTH];

/* User-defined functions created with DEF FN. */
#define MAX_USER_FUNCS 32

struct user_func {
    char name[8];           /* Function name, e.g. "FNY" (uppercased) */
    char param_name[8];     /* Parameter variable name, e.g. "X" (uppercased) */
    int param_is_string;    /* Non-zero if parameter is string type */
    char *body;             /* Duplicated expression text after '=' */
};

static struct user_func user_funcs[MAX_USER_FUNCS];
static int user_func_count = 0;

/* DATA/READ support */
#define MAX_DATA_ITEMS 256
static struct value data_items[MAX_DATA_ITEMS];
static int data_count = 0;
static int data_index = 0;

/* File I/O: logical file numbers 1-255, CBM-style OPEN/CLOSE/PRINT#/INPUT#/GET#.
 * Device 1 = disk/file (filename required). Secondary: 0=read, 1=write, 2=append.
 * ST (status) is updated after INPUT#/GET#: 0=ok, 64=EOF, 1=error/not open. */
#define MAX_OPEN_FILES 16
static FILE *open_files[256];   /* 1-based; [0] unused; NULL = closed */
static void set_io_status(int st);

static int current_line = 0;
static char *statement_pos = NULL;
static volatile int halted = 0;
static int print_col = 0;

#ifdef GFX_VIDEO
static GfxVideoState *gfx_vs = NULL;

/* GFX text output state (mirrors a C64-like 40x25 text screen). */
#define GFX_COLS 40
#define GFX_ROWS 25
static int gfx_x = 0;
static int gfx_y = 0;
static uint8_t gfx_fg = 14;      /* default light blue */
static uint8_t gfx_bg = 6;       /* default blue background */
static int gfx_reverse = 0;
static int gfx_raw_screen_codes = 0;  /* when set, bytes 0–255 are screen codes */

static uint8_t gfx_ascii_to_screencode(unsigned char c)
{
    if (c >= 'A' && c <= 'Z') return (uint8_t)(c - 'A' + 1);
    if (c >= 'a' && c <= 'z') return (uint8_t)(c - 'a' + 1);
    if (c == '@') return 0;
    if (c >= ' ' && c <= '?') return (uint8_t)c;
    return 32;
}

static void gfx_scroll_up(void)
{
    int row;
    if (!gfx_vs) return;
    for (row = 0; row < GFX_ROWS - 1; row++) {
        memcpy(&gfx_vs->screen[row * GFX_COLS],
               &gfx_vs->screen[(row + 1) * GFX_COLS],
               GFX_COLS);
        memcpy(&gfx_vs->color[row * GFX_COLS],
               &gfx_vs->color[(row + 1) * GFX_COLS],
               GFX_COLS);
    }
    memset(&gfx_vs->screen[(GFX_ROWS - 1) * GFX_COLS], 32, GFX_COLS);
    memset(&gfx_vs->color[(GFX_ROWS - 1) * GFX_COLS], gfx_fg, GFX_COLS);
}

static void gfx_newline(void)
{
    gfx_x = 0;
    gfx_y++;
    if (gfx_y >= GFX_ROWS) {
        gfx_scroll_up();
        gfx_y = GFX_ROWS - 1;
    }
    print_col = gfx_x;
}

static void gfx_clear_screen(void)
{
    if (!gfx_vs) return;
    memset(gfx_vs->screen, 32, GFX_TEXT_SIZE);
    memset(gfx_vs->color, gfx_fg, GFX_COLOR_SIZE);
    gfx_x = 0;
    gfx_y = 0;
    print_col = 0;
}

static int gfx_apply_control_code(unsigned char code)
{
    /* Return non-zero if the code was handled as control/state. */
    switch (code) {
    case 14:  /* switch to lowercase/uppercase charset */
        if (gfx_vs) gfx_vs->charset_lowercase = 1;
        petscii_set_lowercase(1);
        return 1;
    case 142: /* switch to uppercase/graphics charset */
        if (gfx_vs) gfx_vs->charset_lowercase = 0;
        petscii_set_lowercase(0);
        return 1;
    case 13: /* CR */
    case 10: /* LF */
        /* Avoid double newline: gfx_put_byte already wraps at col 40, so when
         * the viewer sends CR after wrapping, we're already at col 0. */
        if (gfx_x != 0) gfx_newline();
        return 1;
    case 19: /* HOME */
        gfx_x = 0;
        gfx_y = 0;
        print_col = 0;
        return 1;
    case 147: /* CLR */
        gfx_clear_screen();
        return 1;
    case 17:  /* down */
        if (gfx_y < GFX_ROWS - 1) gfx_y++;
        return 1;
    case 145: /* up */
        if (gfx_y > 0) gfx_y--;
        return 1;
    case 29:  /* right */
        if (gfx_x < GFX_COLS - 1) gfx_x++;
        print_col = gfx_x;
        return 1;
    case 157: /* left */
        if (gfx_x > 0) gfx_x--;
        print_col = gfx_x;
        return 1;
    case 18:  /* reverse on */
        gfx_reverse = 1;
        return 1;
    case 146: /* reverse off */
        gfx_reverse = 0;
        return 1;
    case 20:  /* DEL: backspace — cursor left and erase (like C64) */
        if (gfx_x > 0 && gfx_vs) {
            int del_idx;
            gfx_x--;
            del_idx = gfx_y * GFX_COLS + gfx_x;
            if (del_idx >= 0 && del_idx < (int)GFX_TEXT_SIZE) {
                gfx_vs->screen[del_idx] = 32;
                gfx_vs->color[del_idx] = (uint8_t)(gfx_fg & 0x0F);
            }
            print_col = gfx_x;
        }
        return 1;
    /* PETSCII colour control codes -> set current foreground colour index. */
    case 144: gfx_fg = 0;  return 1; /* black */
    case 5:   gfx_fg = 1;  return 1; /* white */
    case 28:  gfx_fg = 2;  return 1; /* red */
    case 159: gfx_fg = 3;  return 1; /* cyan */
    case 156: gfx_fg = 4;  return 1; /* purple */
    case 30:  gfx_fg = 5;  return 1; /* green */
    case 31:  gfx_fg = 6;  return 1; /* blue */
    case 158: gfx_fg = 7;  return 1; /* yellow */
    case 129: gfx_fg = 8;  return 1; /* orange */
    case 149: gfx_fg = 9;  return 1; /* brown */
    case 150: gfx_fg = 10; return 1; /* light red */
    case 151: gfx_fg = 11; return 1; /* dark gray */
    case 152: gfx_fg = 12; return 1; /* medium gray */
    case 153: gfx_fg = 13; return 1; /* light green */
    case 154: gfx_fg = 14; return 1; /* light blue */
    case 155: gfx_fg = 15; return 1; /* light gray */
    default:
        break;
    }
    return 0;
}

/* Decode one UTF-8 character from *s, advance *s, return Unicode codepoint or -1. */
static int gfx_decode_utf8(const char **s)
{
    unsigned char c = (unsigned char)**s;
    int u;
    if (c < 0x80) {
        u = c;
        (*s)++;
        return u;
    }
    if ((c & 0xE0) == 0xC0 && (*s)[1]) {
        u = ((c & 0x1F) << 6) | ((*s)[1] & 0x3F);
        *s += 2;
        return u;
    }
    if ((c & 0xF0) == 0xE0 && (*s)[1] && (*s)[2]) {
        u = ((c & 0x0F) << 12) | (((*s)[1] & 0x3F) << 6) | ((*s)[2] & 0x3F);
        *s += 3;
        return u;
    }
    if ((c & 0xF8) == 0xF0 && (*s)[1] && (*s)[2] && (*s)[3]) {
        u = ((c & 0x07) << 18) | (((*s)[1] & 0x3F) << 12) | (((*s)[2] & 0x3F) << 6) | ((*s)[3] & 0x3F);
        *s += 4;
        return u;
    }
    (*s)++;
    return -1;
}

/* Unicode box-drawing and £ → PETSCII (for UTF-8 source like trek.bas). */
static int unicode_to_petscii(int u)
{
    switch (u) {
    case 0x00A3: return 0x5C;  /* £ */
    case 0x2500: return 0x60;  /* ─ */
    case 0x2502: return 0x9E;  /* │ */
    case 0x250C: return 0xA4;  /* ┌ */
    case 0x2510: return 0xAE;  /* ┐ */
    case 0x2514: return 0xAD;  /* └ */
    case 0x2518: return 0xBD;  /* ┘ */
    case 0x251C: return 0xAB;  /* ├ */
    case 0x2524: return 0xA7;  /* ┤ */
    case 0x252C: return 0xA6;  /* ┬ */
    case 0x2534: return 0xA5;  /* ┴ */
    case 0x253C: return 0x9B;  /* ┼ */
    default:     return -1;
    }
}

static void gfx_put_byte(unsigned char b)
{
    int idx;
    uint8_t sc;

    if (!gfx_vs) return;
    if (gfx_apply_control_code(b)) return;

    /* Convert to C64 screen code. petscii_to_screencode respects charset
     * (lower/upper) and handles the full PETSCII range. gfx_ascii_to_screencode
     * is a simple ASCII fallback when not in petscii mode. */
    if (gfx_raw_screen_codes || petscii_mode) {
        sc = petscii_to_screencode(b);
    } else if (b >= 32 && b <= 126) {
        sc = gfx_ascii_to_screencode(b);
    } else {
        sc = (uint8_t)b;
    }

    if (gfx_reverse && sc < 128) {
        sc |= 0x80;
    }

    if (gfx_x < 0) gfx_x = 0;
    if (gfx_x >= GFX_COLS) gfx_newline();
    if (gfx_y < 0) gfx_y = 0;
    if (gfx_y >= GFX_ROWS) gfx_y = GFX_ROWS - 1;

    idx = gfx_y * GFX_COLS + gfx_x;
    if (idx >= 0 && idx < (int)GFX_TEXT_SIZE) {
        gfx_vs->screen[idx] = sc;
        gfx_vs->color[idx]  = (uint8_t)(gfx_fg & 0x0F);
    }

    gfx_x++;
    if (gfx_x >= GFX_COLS) {
        gfx_newline();
    } else {
        print_col = gfx_x;
    }
}

static int gfx_keyq_pop(uint8_t *out)
{
    uint8_t head;
    if (!gfx_vs) return 0;
    head = gfx_vs->key_q_head;
    if (head == gfx_vs->key_q_tail) {
        return 0; /* empty */
    }
    *out = gfx_vs->key_queue[head];
    head++;
    if (head >= (uint8_t)sizeof(gfx_vs->key_queue)) head = 0;
    gfx_vs->key_q_head = head;
    return 1;
}
#endif

/* PETSCII/ANSI configuration (petscii_mode declared earlier for gfx_put_byte) */
/* When set, do not output ANSI (color/reverse/cursor); output is paste-friendly, no extra bytes. */
static int petscii_plain = 0;
/* When set (e.g. stdout is a pipe), do not insert newlines at PRINT_WIDTH. */
static int petscii_no_wrap = 0;

enum {
    PALETTE_ANSI = 0,       /* Standard ANSI SGR colors */
    PALETTE_C64_8BIT = 1    /* 8-bit palette approximating C64 colors */
};

static int palette_mode = PALETTE_ANSI;
static int cursor_hidden = 0;
static int petscii_lowercase_opt = 0;

/* Case-insensitive string compare. */
static int str_eq_ci(const char *a, const char *b)
{
    if (!a || !b) return (a == b);
    while (*a && *b) {
        if (toupper((unsigned char)*a) != toupper((unsigned char)*b)) return 0;
        a++; b++;
    }
    return (*a == *b);
}

/* Apply option from #OPTION directive (file overrides CLI). Returns 0 on success, -1 on error. */
static int apply_option_directive(const char *name, const char *value)
{
    if (!name || !name[0]) return -1;
    if (str_eq_ci(name, "petscii")) {
        petscii_mode = 1;
        petscii_plain = 0;
        petscii_no_wrap = 1;
        return 0;
    }
    if (str_eq_ci(name, "petscii-plain")) {
        petscii_mode = 1;
        petscii_plain = 1;
        petscii_no_wrap = 1;
        return 0;
    }
    if (str_eq_ci(name, "charset")) {
        if (!value || !value[0]) return -1;
        if (str_eq_ci(value, "upper") || str_eq_ci(value, "uc")) {
            petscii_lowercase_opt = 0;
            petscii_set_lowercase(0);
            return 0;
        }
        if (str_eq_ci(value, "lower") || str_eq_ci(value, "lc")) {
            petscii_lowercase_opt = 1;
            petscii_set_lowercase(1);
            return 0;
        }
        return -1;
    }
    if (str_eq_ci(name, "palette")) {
        if (!value || !value[0]) return -1;
        if (str_eq_ci(value, "ansi")) {
            palette_mode = PALETTE_ANSI;
            return 0;
        }
        if (str_eq_ci(value, "c64") || str_eq_ci(value, "c64-8bit")) {
            palette_mode = PALETTE_C64_8BIT;
            return 0;
        }
        return -1;
    }
    return -1;
}

/* Command-line arguments for the running script (after options and program path). */
static const char *script_path = NULL;   /* path to the .bas file */
static int script_argc = 0;              /* number of arguments after script path */
static char **script_argv = NULL;        /* argv entries after script path */

/* Run a shell command; returns exit status (0 = success, non-zero = failure). */
static int do_system(const char *cmd)
{
#if defined(_WIN32)
    return system(cmd);  /* MSVC: runs via cmd.exe */
#else
    return system(cmd);
#endif
}

/* Run a shell command and return its stdout (up to MAX_STR_LEN-1 chars). */
static void do_exec(const char *cmd, char *out, size_t out_size)
{
    FILE *fp;
    size_t n;
    if (out_size == 0) return;
    out[0] = '\0';
#if defined(_WIN32)
    fp = _popen(cmd, "rt");
#else
    fp = popen(cmd, "r");
#endif
    if (!fp) return;
    n = fread(out, 1, out_size - 1, fp);
    out[n] = '\0';
    /* Trim trailing newline if present */
    while (n > 0 && (out[n-1] == '\n' || out[n-1] == '\r')) { out[--n] = '\0'; }
#if defined(_WIN32)
    _pclose(fp);
#else
    pclose(fp);
#endif
}

static void runtime_error(const char *msg);
static void load_program(const char *path);
static void run_program(const char *script_path_arg, int nargs, char **args);
static int find_line_index(int number);
static void build_label_table(void);
static void build_udf_table(void);
static int find_label_line(const char *name);
static int udf_lookup(const char *name, int param_count);
static int starts_with_kw(char *p, const char *kw);
static void skip_spaces(char **p);
static int parse_number_literal(char **p, double *out);
static int read_identifier(char **p, char *buf, int buf_size);
static char *dupstr_local(const char *s);
static struct value eval_expr(char **p);
static int eval_condition(char **p);
static void execute_statement(char **p);
static struct value *get_var_reference(char **p, int *is_array_out, int *is_string_out);
static struct value make_num(double v);
static struct value make_str(const char *s);
static struct var *find_or_create_var(const char *name, int is_string, int want_array, int dims, const int *dim_sizes, int total_size);
static struct value eval_function(const char *name, char **p);
static int user_func_lookup(const char *name);
static void collect_data_from_program(void);
static void statement_read(char **p);
static void print_value(struct value *v);
static void print_spaces(int count);
static void statement_sleep(char **p);
static void statement_textat(char **p);
static void statement_def(char **p);
static void statement_get(char **p);
static void do_sleep_ticks(double ticks);
static void statement_locate(char **p);
static void statement_on(char **p);
static void statement_clr(char **p);
static void statement_open(char **p);
static void statement_close(char **p);
static void statement_print_hash(char **p);
static void statement_input_hash(char **p);
static void statement_get_hash(char **p);
static int function_lookup(const char *name, int len);
static void statement_cursor(char **p);
static void statement_color(char **p);
static void statement_background(char **p);
static void statement_screencodes(char **p);
static void statement_else(char **p);
static void statement_end_if(char **p);
static void statement_return(char **p);
static void statement_end_function(char **p);
static void skip_function_block(char **p);
static void statement_while(char **p, char *while_pos);
static void statement_wend(char **p);
static void statement_do(char **p);
static void statement_loop(char **p);
static void statement_exit_do(char **p);
static void skip_if_block_to_target(char **p, int want_else);
static void skip_while_to_wend(char **p);
static void skip_do_to_after_loop(char **p);

enum func_code {
    FN_NONE = 0,
    FN_SIN = 1,
    FN_COS = 2,
    FN_TAN = 3,
    FN_ABS = 4,
    FN_INT = 5,
    FN_SQR = 6,
    FN_SGN = 7,
    FN_EXP = 8,
    FN_LOG = 9,
    FN_RND = 10,
    FN_LEN = 11,
    FN_STR = 12,
    FN_CHR = 13,
    FN_ASC = 14,
    FN_VAL = 15,
    FN_TAB = 16,
    FN_SPC = 17,
    FN_MID = 18,
    FN_LEFT = 19,
    FN_RIGHT = 20,
    FN_UCASE = 21,
    FN_LCASE = 22,
    FN_SYSTEM = 23,
    FN_EXEC = 24,
    FN_ARGC = 25,
    FN_ARG = 26,
    FN_INSTR = 27,
    FN_DEC = 28,
    FN_HEX = 29,
    FN_STRINGFN = 30,
    FN_PEEK = 31,
    FN_INKEY = 32
};

/* Report an error and halt further execution.
 * If possible, include the BASIC line number (if present) and the
 * original source text with a caret pointing near the error location.
 */
static void runtime_error(const char *msg)
{
    int line_no = 0;
    const char *line_text = NULL;

    if (current_line >= 0 && current_line < line_count &&
        program_lines[current_line] != NULL) {
        line_no = program_lines[current_line]->number;
        line_text = program_lines[current_line]->text;
    }

    if (line_no > 0) {
        fprintf(stderr, "Error on line %d: %s\n", line_no, msg);
    } else {
        fprintf(stderr, "Error: %s\n", msg);
    }

    if (line_text && *line_text) {
        /* Print the full source line for context. */
        fprintf(stderr, "  %s\n", line_text);

        /* If we know roughly where in the line we are (statement_pos),
         * print a caret pointing near that column.
         */
        if (statement_pos &&
            statement_pos >= line_text &&
            statement_pos <= line_text + (int)strlen(line_text)) {
            const char *p = line_text;
            int col = 0;
            while (p < statement_pos && *p) {
                /* Treat tabs as a single column for simplicity. */
                col++;
                p++;
            }
            fprintf(stderr, "  ");
            /* Cap the number of spaces so very long lines do not spam. */
            if (col > 120) {
                col = 120;
            }
            for (int i = 0; i < col; i++) {
                fputc(' ', stderr);
            }
            fprintf(stderr, "^\n");
        }
    }

    halted = 1;
}

/* Strip trailing newline from a buffer if present. */
static void trim_newline(char *s)
{
    size_t len;
    len = strlen(s);
    while (len > 0 && (s[len - 1] == '\n' || s[len - 1] == '\r')) {
        s[--len] = '\0';
    }
}

/* Advance pointer past spaces/tabs. */
static void skip_spaces(char **p)
{
    while (**p == ' ' || **p == '\t') {
        (*p)++;
    }
}

/* Parse a numeric literal from the character stream. */
static int parse_number_literal(char **p, double *out)
{
    char buf[64];
    char *s;
    char *q;
    int len;
    s = *p;
    q = s;
    if (*q == '+' || *q == '-') {
        q++;
    }
    while (isdigit((unsigned char)*q)) {
        q++;
    }
    if (*q == '.') {
        q++;
        while (isdigit((unsigned char)*q)) {
            q++;
        }
    }
    if (*q == 'e' || *q == 'E') {
        char *e;
        e = q + 1;
        if (*e == '+' || *e == '-') {
            e++;
        }
        if (isdigit((unsigned char)*e)) {
            q = e;
            while (isdigit((unsigned char)*q)) {
                q++;
            }
        }
    }
    if (q == s || (s + 1 == q && (s[0] == '+' || s[0] == '-'))) {
        return 0;
    }
    len = q - s;
    if (len >= (int)sizeof(buf)) {
        len = sizeof(buf) - 1;
    }
    strncpy(buf, s, len);
    buf[len] = '\0';
    *out = atof(buf);
    *p = q;
    return 1;
}

/* Duplicate a string into heap memory. */
static char *dupstr_local(const char *s)
{
    size_t len;
    char *p;
    len = strlen(s) + 1;
    p = (char *)malloc(len);
    if (!p) {
        runtime_error("Out of memory");
        return NULL;
    }
    memcpy(p, s, len);
    return p;
}

/* Reserved words: identifiers that cannot be used as variable or label names. */
static const char *const reserved_words[] = {
    "AND", "ARG", "ARGC", "ASC", "BACKGROUND", "CHR", "CLOSE", "CLR", "COLOR",
    "COLOUR", "COS", "CURSOR", "DATA", "DEC", "DEF", "DIM", "DOWN", "END", "FUNCTION",
    "ELSE", "EXEC", "EXP", "FN", "FOR", "GET", "GOSUB", "GOTO", "HEX", "IF", "INK",
    "INKEY", "INPUT", "INSTR", "INT", "LEFT", "LEN", "LET", "LOCATE", "LOG",
    "LCASE", "MID", "NEXT", "OFF", "ON", "OPEN", "OR", "PEEK", "POKE", "PRINT",
    "READ", "REM", "RESTORE", "RETURN", "RIGHT", "RND", "RVS", "SCREENCODES",
    "SGN", "SIN", "SLEEP", "SPC", "SQR", "STEP", "STOP", "STR", "STRING",
    "SYSTEM", "TAB", "TAN", "TEXTAT", "THEN", "TI", "TO", "UCASE",     "VAL", "WEND", "WHILE",
    "DO", "LOOP", "UNTIL", "EXIT",
    NULL
};

static int is_reserved_word(const char *name)
{
    int i;
    char up[VAR_NAME_MAX];
    size_t len;
    if (!name || !name[0]) return 0;
    len = strlen(name);
    if (len >= VAR_NAME_MAX) return 0;
    for (i = 0; (unsigned char)name[i]; i++) {
        up[i] = (char)toupper((unsigned char)name[i]);
    }
    up[i] = '\0';
    for (i = 0; reserved_words[i]; i++) {
        if (strcmp(up, reserved_words[i]) == 0) return 1;
    }
    return 0;
}

/* Check if the input starts with the keyword (case-insensitive). */
static int starts_with_kw(char *p, const char *kw)
{
    int i;
    for (i = 0; kw[i]; i++) {
        if (toupper((unsigned char)p[i]) != kw[i]) {
            return 0;
        }
    }
    if (p[i] == '\0' || p[i] == ' ' || p[i] == '\t' || p[i] == ':' || p[i] == '(' || p[i] == '$' || p[i] == '\"' || p[i] == '#') {
        return 1;
    }
    return 0;
}

/* Construct a numeric value wrapper. */
static struct value make_num(double v)
{
    struct value out;
    out.type = VAL_NUM;
    out.num = v;
    out.str[0] = '\0';
    return out;
}

/* Construct a string value wrapper. */
static struct value make_str(const char *s)
{
    struct value out;
    out.type = VAL_STR;
    out.num = 0.0;
    strncpy(out.str, s, MAX_STR_LEN - 1);
    out.str[MAX_STR_LEN - 1] = '\0';
    return out;
}

/* Ensure the value is numeric or raise a runtime error. */
static void ensure_num(struct value *v)
{
    if (v->type != VAL_NUM) {
        runtime_error("Numeric value required");
    }
}

/* Ensure the value is string; auto-convert numeric to string when needed. */
static void ensure_str(struct value *v)
{
    if (v->type == VAL_STR) {
        return;
    }
    if (v->type == VAL_NUM) {
        char buf[64];
        sprintf(buf, "%g", v->num);
        *v = make_str(buf);
        return;
    }
    runtime_error("String value required");
}

/* Emit spaces and track current print column. */
static void print_spaces(int count)
{
    int i;
    for (i = 0; i < count; i++) {
#ifdef GFX_VIDEO
        if (gfx_vs) {
            gfx_put_byte(' ');
            continue;
        }
#endif
        fputc(' ', stdout);
        print_col++;
        if (print_col >= PRINT_WIDTH) {
            fputc('\n', stdout);
            print_col = 0;
        }
    }
}

/* Parse a DEF FN user-defined function definition. */
static void statement_def(char **p)
{
    char namebuf[8];
    char param_buf[8];
    int i;
    int idx;
    struct user_func *uf;
    char *body_start;

    skip_spaces(p);
    if (!isalpha((unsigned char)**p)) {
        runtime_error("Expected function name after DEF");
        return;
    }
    /* Read function name (e.g. FNY) and uppercase it */
    read_identifier(p, namebuf, sizeof(namebuf));
    for (i = 0; namebuf[i]; i++) {
        namebuf[i] = (char)toupper((unsigned char)namebuf[i]);
    }

    /* Require that the function name begins with FN, per classic BASIC. */
    if (!(namebuf[0] == 'F' && namebuf[1] == 'N')) {
        runtime_error("Function name must start with FN");
        return;
    }

    skip_spaces(p);
    if (**p != '(') {
        runtime_error("DEF FN requires parameter list");
        return;
    }
    (*p)++;
    skip_spaces(p);
    if (!isalpha((unsigned char)**p)) {
        runtime_error("Expected parameter name");
        return;
    }
    read_identifier(p, param_buf, sizeof(param_buf));
    for (i = 0; param_buf[i]; i++) {
        param_buf[i] = (char)toupper((unsigned char)param_buf[i]);
    }
    skip_spaces(p);
    if (**p != ')') {
        runtime_error("Missing ')' in DEF FN");
        return;
    }
    (*p)++;
    skip_spaces(p);
    if (**p != '=') {
        runtime_error("DEF FN missing '='");
        return;
    }
    (*p)++;
    body_start = *p;
    while (*body_start == ' ' || *body_start == '\t') {
        body_start++;
    }
    if (*body_start == '\0') {
        runtime_error("Empty function body in DEF FN");
        return;
    }

    /* Find or create function entry */
    idx = user_func_lookup(namebuf);
    if (idx < 0) {
        if (user_func_count >= MAX_USER_FUNCS) {
            runtime_error("Function table full");
            return;
        }
        idx = user_func_count++;
    }
    uf = &user_funcs[idx];
    if (uf->body) {
        free(uf->body);
    }
    strncpy(uf->name, namebuf, sizeof(uf->name) - 1);
    uf->name[sizeof(uf->name) - 1] = '\0';
    strncpy(uf->param_name, param_buf, sizeof(uf->param_name) - 1);
    uf->param_name[sizeof(uf->param_name) - 1] = '\0';
    uf->param_is_string = (param_buf[strlen(param_buf) - 1] == '$');
    uf->body = dupstr_local(body_start);

    /* DEF FN is a complete statement; skip to end of line. */
    *p += strlen(*p);
}

/* READ statement: READ A, B$, ... pulls from DATA pool */
static void statement_read(char **p)
{
    for (;;) {
        struct value *vp;
        int is_array;
        int is_string;

        skip_spaces(p);
        if (**p == '\0' || **p == ':') {
            break;
        }
        if (!isalpha((unsigned char)**p)) {
            runtime_error("Expected variable in READ");
            return;
        }
        vp = get_var_reference(p, &is_array, &is_string);
        if (!vp) {
            return;
        }
        if (data_index >= data_count) {
            runtime_error("Out of DATA");
            return;
        }
        {
            struct value src = data_items[data_index++];
            if (is_string) {
                if (src.type != VAL_STR) {
                    char buf[64];
                    sprintf(buf, "%g", src.num);
                    *vp = make_str(buf);
                } else {
                    *vp = src;
                }
            } else {
                if (src.type != VAL_NUM) {
                    double num = atof(src.str);
                    *vp = make_num(num);
                } else {
                    *vp = src;
                }
            }
        }
        skip_spaces(p);
        if (**p == ',') {
            (*p)++;
            continue;
        }
        break;
    }
}

/* Lookup a DEF FN user-defined function by name (already uppercased). */
static int user_func_lookup(const char *name)
{
    int i;
    for (i = 0; i < user_func_count; i++) {
        if (strcmp(user_funcs[i].name, name) == 0) {
            return i;
        }
    }
    return -1;
}

/* Simple label table for optional label-based GOTO/GOSUB.
 * A label is defined by writing it at the start of a line followed by ':'.
 * For example:
 *   START: PRINT "HELLO": GOTO START
 *
 * Labels are resolved to line indices after the program is loaded.
 */

#define MAX_LABELS 256

struct label_entry {
    char name[32];
    int line_index; /* index into program_lines[] */
};

static struct label_entry label_table[MAX_LABELS];
static int label_count = 0;

/* Build the label table by scanning program lines for leading "NAME:".
 * The label text is stripped from the stored line so execution sees only statements.
 */
static void build_label_table(void)
{
    int i;
    label_count = 0;
    for (i = 0; i < line_count; i++) {
        char *text;
        char *p;
        char *q;
        size_t len;

        if (!program_lines[i] || !program_lines[i]->text) {
            continue;
        }
        text = program_lines[i]->text;
        p = text;
        while (*p == ' ' || *p == '\t') {
            p++;
        }
        /* Label must start with a letter and consist of letters/digits/$,
         * immediately followed by ':' (optionally after spaces). This avoids
         * misinterpreting expressions like 'LB$=CHR$(154):' as labels.
         */
        if (!isalpha((unsigned char)*p)) {
            continue;
        }
        q = p;
        while (isalpha((unsigned char)*q) || isdigit((unsigned char)*q) || *q == '$' || *q == '_') {
            q++;
        }
        /* Skip optional spaces/tabs between label and ':' */
        {
            char *r = q;
            char *label_end = q;  /* end of identifier only, not including spaces */
            while (*r == ' ' || *r == '\t') {
                r++;
            }
            if (*r != ':') {
                continue;
            }
            len = (size_t)(label_end - p);
            q = r; /* q now points at ':' */
        }

        /* We have LABEL: at start of line. Extract the name. */
        if (len >= sizeof(label_table[0].name)) {
            len = sizeof(label_table[0].name) - 1;
        }
        if (label_count >= MAX_LABELS) {
            /* Too many labels; ignore extras. */
            continue;
        }
        /* Keywords like PRINT/CLR followed by ':' are statements, not labels. */
        {
            char tmp[32];
            size_t k;
            if (len >= sizeof(tmp)) tmp[sizeof(tmp)-1] = '\0';
            memcpy(tmp, p, len);
            tmp[len] = '\0';
            if (is_reserved_word(tmp)) {
                continue;
            }
            for (k = 0; k < len; k++) tmp[k] = (char)toupper((unsigned char)tmp[k]);
            for (k = 0; k < (size_t)label_count; k++) {
                if (strcmp(label_table[k].name, tmp) == 0) {
                    fprintf(stderr, "Duplicate label '%.*s' in program\n", (int)len, p);
                    exit(1);
                }
            }
        }
        memcpy(label_table[label_count].name, p, len);
        label_table[label_count].name[len] = '\0';
        /* Normalize to uppercase for case-insensitive matching. */
        {
            size_t k;
            for (k = 0; k < len; k++) {
                label_table[label_count].name[k] =
                    (char)toupper((unsigned char)label_table[label_count].name[k]);
            }
        }
        /* Labels may share names with keywords (e.g. CLR: in trek.bas); context is unambiguous. */
        label_table[label_count].line_index = i;
        label_count++;

        /* Strip the label from the stored line so execution sees only the statement. */
        q++; /* skip ':' */
        while (*q == ' ' || *q == '\t') {
            q++;
        }
        /* Duplicate the remainder into a new buffer. */
        {
            char *new_text = dupstr_local(q);
            if (new_text) {
                free(program_lines[i]->text);
                program_lines[i]->text = new_text;
            }
        }
    }
}

/* Find the line index for a given label name, or -1 if not found. */
static int find_label_line(const char *name)
{
    int i;
    char tmp[32];
    size_t len;

    if (!name || !*name) {
        return -1;
    }
    /* Uppercase a copy for case-insensitive comparison. */
    len = strlen(name);
    if (len >= sizeof(tmp)) {
        len = sizeof(tmp) - 1;
    }
    memcpy(tmp, name, len);
    tmp[len] = '\0';
    for (i = 0; tmp[i]; i++) {
        tmp[i] = (char)toupper((unsigned char)tmp[i]);
    }

    for (i = 0; i < label_count; i++) {
        if (strcmp(label_table[i].name, tmp) == 0) {
            return label_table[i].line_index;
        }
    }
    return -1;
}

/* Lookup UDF by name (uppercased) and param count. */
static int udf_lookup(const char *name, int param_count)
{
    int i;
    for (i = 0; i < udf_func_count; i++) {
        if (strcmp(udf_funcs[i].name, name) == 0 && udf_funcs[i].param_count == param_count) {
            return i;
        }
    }
    return -1;
}

/* Scan program for FUNCTION...END FUNCTION and build udf_funcs table. */
static void build_udf_table(void)
{
    int i, j, nesting;
    char *p, *q;
    char namebuf[VAR_NAME_MAX];
    int param_count;
    char *body_start;
    int body_line;

    udf_func_count = 0;
    for (i = 0; i < line_count && udf_func_count < MAX_UDF_FUNCS; i++) {
        if (!program_lines[i] || !program_lines[i]->text) continue;
        p = program_lines[i]->text;
        for (;;) {
            while (*p == ' ' || *p == '\t') p++;
            if (!*p) break;
            if ((toupper((unsigned char)p[0])=='F' && toupper((unsigned char)p[1])=='U' &&
                 toupper((unsigned char)p[2])=='N' && toupper((unsigned char)p[3])=='C' &&
                 toupper((unsigned char)p[4])=='T' && toupper((unsigned char)p[5])=='I' &&
                 toupper((unsigned char)p[6])=='O' && toupper((unsigned char)p[7])=='N') &&
                (p[8]=='\0' || p[8]==' ' || p[8]=='\t')) {
                q = p + 8;
                while (*q == ' ' || *q == '\t') q++;
                if (!isalpha((unsigned char)*q)) {
                    { char *n = strchr(p, ':'); p = n ? n + 1 : p + strlen(p); }
                    continue;
                }
                read_identifier((char**)&q, namebuf, sizeof(namebuf));
                { int k; for (k = 0; namebuf[k]; k++) namebuf[k] = (char)toupper((unsigned char)namebuf[k]); }
                while (*q == ' ' || *q == '\t') q++;
                param_count = 0;
                if (*q == '(') {
                    q++;
                    while (*q && *q != ')') {
                        while (*q == ' ' || *q == '\t') q++;
                        if (!isalpha((unsigned char)*q)) break;
                        if (param_count < MAX_UDF_PARAMS) {
                            read_identifier((char**)&q, udf_funcs[udf_func_count].param_names[param_count], VAR_NAME_MAX);
                            { int k; for (k = 0; udf_funcs[udf_func_count].param_names[param_count][k]; k++)
                                udf_funcs[udf_func_count].param_names[param_count][k] =
                                    (char)toupper((unsigned char)udf_funcs[udf_func_count].param_names[param_count][k]); }
                            udf_funcs[udf_func_count].param_is_string[param_count] =
                                (strlen(udf_funcs[udf_func_count].param_names[param_count]) > 0 &&
                                 udf_funcs[udf_func_count].param_names[param_count][strlen(udf_funcs[udf_func_count].param_names[param_count])-1] == '$');
                            param_count++;
                        }
                        while (*q == ' ' || *q == '\t') q++;
                        if (*q == ',') q++;
                    }
                    if (*q == ')') q++;
                }
                while (*q == ' ' || *q == '\t') q++;
                if (*q == ':') {
                    q++;
                    while (*q == ' ' || *q == '\t') q++;
                    body_start = q;
                    body_line = i;
                } else {
                    body_line = i + 1;
                    body_start = NULL;
                }
                /* Find matching END FUNCTION */
                nesting = 1;
                for (j = (body_start && *body_start) ? i : i + 1; j < line_count && nesting > 0; j++) {
                    char *r = (j == i && body_start) ? body_start : program_lines[j]->text;
                    if (!r) continue;
                    for (;;) {
                        while (r && (*r == ' ' || *r == '\t')) r++;
                        if (!r || !*r) break;
                        if ((toupper((unsigned char)r[0])=='F' && toupper((unsigned char)r[1])=='U' &&
                             toupper((unsigned char)r[2])=='N' && toupper((unsigned char)r[3])=='C' &&
                             toupper((unsigned char)r[4])=='T' && toupper((unsigned char)r[5])=='I' &&
                             toupper((unsigned char)r[6])=='O' && toupper((unsigned char)r[7])=='N') &&
                            (r[8]=='\0' || r[8]==' ' || r[8]=='\t')) {
                            nesting++;
                            r += 8;
                            while (*r && *r != ':') r++;
                            if (*r) r++;
                            continue;
                        }
                        if (toupper((unsigned char)r[0])=='E' && toupper((unsigned char)r[1])=='N' &&
                            toupper((unsigned char)r[2])=='D' && (r[3]=='\0' || r[3]==' ' || r[3]=='\t')) {
                            char *ef = r + 3;
                            while (*ef == ' ' || *ef == '\t') ef++;
                            if (toupper((unsigned char)ef[0])=='F' && toupper((unsigned char)ef[1])=='U' &&
                                toupper((unsigned char)ef[2])=='N' && toupper((unsigned char)ef[3])=='C' &&
                                toupper((unsigned char)ef[4])=='T' && toupper((unsigned char)ef[5])=='I' &&
                                toupper((unsigned char)ef[6])=='O' && toupper((unsigned char)ef[7])=='N' &&
                                (ef[8]=='\0' || ef[8]==' ' || ef[8]=='\t' || ef[8]==':')) {
                            nesting--;
                            if (nesting == 0) {
                                struct udf_func *uf = &udf_funcs[udf_func_count];
                                strncpy(uf->name, namebuf, VAR_NAME_MAX - 1);
                                uf->name[VAR_NAME_MAX - 1] = '\0';
                                uf->param_count = param_count;
                                uf->body_line = body_line;
                                uf->body_pos = body_start ? body_start : (program_lines[body_line] ? program_lines[body_line]->text : NULL);
                                udf_func_count++;
                                goto next_statement;
                            }
                            r = ef + 8;
                            while (*r && *r != ':') r++;
                            if (*r) r++;
                            continue;
                            }
                        }
                        {
                            char *next = strchr(r, ':');
                            if (!next) break;
                            r = next + 1;
                        }
                    }
                }
                fprintf(stderr, "FUNCTION %s: END FUNCTION not found\n", namebuf);
next_statement:
                { char *n = strchr(p, ':'); p = n ? n + 1 : p + strlen(p); }
                continue;
            }
            { char *n = strchr(p, ':'); p = n ? n + 1 : p + strlen(p); }
        }
    }
}

/* Scan all program lines and collect DATA items into data_items[] */
static void collect_data_from_program(void)
{
    int i;
    data_count = 0;
    data_index = 0;
    for (i = 0; i < line_count && data_count < MAX_DATA_ITEMS; i++) {
        char *p;
        if (!program_lines[i] || !program_lines[i]->text) {
            continue;
        }
        p = program_lines[i]->text;
        while (*p == ' ' || *p == '\t') {
            p++;
        }
        if (!starts_with_kw(p, "DATA")) {
            continue;
        }
        p += 4;
        for (;;) {
            struct value v;
            char token[MAX_STR_LEN];
            int tlen = 0;

            while (*p == ' ' || *p == '\t') {
                p++;
            }
            if (*p == '\0') {
                break;
            }
            if (*p == '\"') {
                /* Quoted string */
                p++;
                while (*p && *p != '\"' && tlen < (int)sizeof(token) - 1) {
                    token[tlen++] = *p++;
                }
                token[tlen] = '\0';
                if (*p == '\"') {
                    p++;
                }
                v = make_str(token);
            } else {
                /* Unquoted token up to comma or end */
                while (*p && *p != ',' && *p != ':' && tlen < (int)sizeof(token) - 1) {
                    token[tlen++] = *p++;
                }
                token[tlen] = '\0';
                /* Trim trailing spaces */
                while (tlen > 0 && (token[tlen - 1] == ' ' || token[tlen - 1] == '\t')) {
                    token[--tlen] = '\0';
                }
                if (tlen == 0) {
                    v = make_str("");
                } else {
                    char *endptr;
                    double num = strtod(token, &endptr);
                    if (endptr != token && *endptr == '\0') {
                        v = make_num(num);
                    } else {
                        v = make_str(token);
                    }
                }
            }
            if (data_count < MAX_DATA_ITEMS) {
                data_items[data_count++] = v;
            }
            while (*p == ' ' || *p == '\t') {
                p++;
            }
            if (*p == ',') {
                p++;
                continue;
            }
            break;
        }
    }
}

/* Emit a value (number or string) updating column tracking. */
static void print_value(struct value *v)
{
    if (v->type == VAL_STR) {
        char *s;
        s = v->str;
        while (*s) {
            unsigned char c = (unsigned char)*s;
#ifdef GFX_VIDEO
            if (gfx_vs) {
                /* Decode UTF-8 so Unicode box-drawing (┌─┐ etc.) and £
                 * from trek.bas and similar sources map to C64 PETSCII. */
                if (c >= 0xC2 && c <= 0xF4) {
                    int u = gfx_decode_utf8((const char **)&s);
                    if (u >= 0) {
                        int pet = unicode_to_petscii(u);
                        if (pet >= 0) {
                            uint8_t sc = (uint8_t)petscii_to_screencode((unsigned char)pet);
                            int idx;
                            if (gfx_reverse && sc < 128) sc |= 0x80;
                            if (gfx_x < 0) gfx_x = 0;
                            if (gfx_x >= GFX_COLS) gfx_newline();
                            if (gfx_y < 0) gfx_y = 0;
                            if (gfx_y >= GFX_ROWS) gfx_y = GFX_ROWS - 1;
                            idx = gfx_y * GFX_COLS + gfx_x;
                            if (idx >= 0 && idx < (int)GFX_TEXT_SIZE) {
                                gfx_vs->screen[idx] = sc;
                                gfx_vs->color[idx]  = (uint8_t)(gfx_fg & 0x0F);
                            }
                            gfx_x++;
                            if (gfx_x >= GFX_COLS) gfx_newline();
                            else print_col = gfx_x;
                            continue;
                        }
                        /* Unknown Unicode: output space to avoid garbage */
                        gfx_put_byte(' ');
                    }
                    continue;
                }
                gfx_put_byte(c);
                s++;
                continue;
            }
#endif
            /* Handle ANSI escape sequences specially so column tracking matches
             * what the terminal actually does. Most sequences are treated as
             * zero-width; cursor-right (C) / cursor-left (D) adjust print_col.
             */
            if (petscii_mode && c == 0x1b) {
                fputc(c, stdout);
                s++;
                if (!*s) {
                    break;
                }
                unsigned char d = (unsigned char)*s;
                fputc(d, stdout);
                if (d == '[') {
                    int n = 0;
                    int have_num = 0;
                    s++;
                    while (*s) {
                        d = (unsigned char)*s;
                        fputc(d, stdout);
                        if (d >= '0' && d <= '9') {
                            n = n * 10 + (d - '0');
                            have_num = 1;
                            s++;
                            continue;
                        }
                        if (d == ';' || d == '?' || d == ' ') {
                            s++;
                            continue;
                        }
                        /* Final byte of CSI sequence. */
                        if (!have_num) {
                            n = 1;
                        }
                        if (d == 'C') {
                            /* Cursor right */
                            print_col += n;
                            if (print_col >= PRINT_WIDTH && !petscii_no_wrap) {
                                fputc('\n', stdout);
                                print_col = 0;
                            }
                        } else if (d == 'D') {
                            /* Cursor left */
                            print_col -= n;
                            if (print_col < 0) {
                                print_col = 0;
                            }
                        } else if (d == 'H' || d == 'f') {
                            /* Cursor home/position: we don't track row, just reset column. */
                            print_col = 0;
                        }
                        s++;
                        break;
                    }
                } else {
                    /* Non-CSI escape; just emit next byte and treat as zero-width. */
                    s++;
                }
                continue;
            }
            fputc(c, stdout);
            if (c == '\n') {
                print_col = 0;
            } else {
                /* Count one column per UTF-8 character (glyph), not per byte, so
                 * wrap happens at 40 visible columns and we don't break mid-char. */
                if (c < 0x80 || (c & 0xC0) != 0x80) {
                    print_col++;
                    if (print_col >= PRINT_WIDTH && !petscii_no_wrap) {
                        fputc('\n', stdout);
                        print_col = 0;
                    }
                }
            }
            s++;
        }
    } else {
        char buf[64];
        sprintf(buf, "%g", v->num);
#ifdef GFX_VIDEO
        if (gfx_vs) {
            char *s = buf;
            while (*s) {
                gfx_put_byte((unsigned char)*s++);
            }
            return;
        }
#endif
        fputs(buf, stdout);
        print_col += (int)strlen(buf);
    }
}

/* Map function name to a small integer code for fast dispatch. */
static int function_lookup(const char *name, int len)
{
    char c1;
    c1 = name[0];
    switch (c1) {
    case 'S':
        if (len == 3 && name[0] == 'S' && name[1] == 'I' && name[2] == 'N') return FN_SIN;
        if (len == 3 && name[0] == 'S' && name[1] == 'G' && name[2] == 'N') return FN_SGN;
        if (len == 3 && name[0] == 'S' && name[1] == 'Q' && name[2] == 'R') return FN_SQR;
        if ((len == 3 && name[0] == 'S' && name[1] == 'T' && name[2] == 'R') ||
            (len == 4 && name[0] == 'S' && name[1] == 'T' && name[2] == 'R' && name[3] == '$')) return FN_STR;
        if (len == 3 && name[0] == 'S' && name[1] == 'P' && name[2] == 'C') return FN_SPC;
        if ((len == 6 && name[0] == 'S' && name[1] == 'T' && name[2] == 'R' && name[3] == 'I' && name[4] == 'N' && name[5] == 'G') ||
            (len == 7 && name[0] == 'S' && name[1] == 'T' && name[2] == 'R' && name[3] == 'I' && name[4] == 'N' && name[5] == 'G' && name[6] == '$'))
            return FN_STRINGFN;
        if (len == 6 && name[0] == 'S' && name[1] == 'Y' && name[2] == 'S' && name[3] == 'T' && name[4] == 'E' && name[5] == 'M') return FN_SYSTEM;
        return FN_NONE;
    case 'C':
        if ((len == 3 && name[0] == 'C' && name[1] == 'H' && name[2] == 'R') ||
            (len == 4 && name[0] == 'C' && name[1] == 'H' && name[2] == 'R' && name[3] == '$')) return FN_CHR;
        if (len == 3 && name[0] == 'C' && name[1] == 'O' && name[2] == 'S') return FN_COS;
        return FN_NONE;
    case 'T':
        if (len == 3 && name[0] == 'T' && name[1] == 'A' && name[2] == 'N') return FN_TAN;
        if (len == 3 && name[0] == 'T' && name[1] == 'A' && name[2] == 'B') return FN_TAB;
        return FN_NONE;
    case 'A':
        if (len == 3 && name[0] == 'A' && name[1] == 'B' && name[2] == 'S') return FN_ABS;
        if (len == 3 && name[0] == 'A' && name[1] == 'S' && name[2] == 'C') return FN_ASC;
        if (len == 4 && name[0] == 'A' && name[1] == 'R' && name[2] == 'G' && name[3] == 'C') return FN_ARGC;
        if ((len == 3 && name[0] == 'A' && name[1] == 'R' && name[2] == 'G') ||
            (len == 4 && name[0] == 'A' && name[1] == 'R' && name[2] == 'G' && name[3] == '$')) return FN_ARG;
        return FN_NONE;
    case 'I':
        if (len == 3 && name[0] == 'I' && name[1] == 'N' && name[2] == 'T') return FN_INT;
        if (len == 5 && name[0] == 'I' && name[1] == 'N' && name[2] == 'S' && name[3] == 'T' && name[4] == 'R') return FN_INSTR;
        if (len == 5 && name[0] == 'I' && name[1] == 'N' && name[2] == 'K' && name[3] == 'E' && name[4] == 'Y') return FN_INKEY;
        if (len == 6 && name[0] == 'I' && name[1] == 'N' && name[2] == 'K' && name[3] == 'E' && name[4] == 'Y' && name[5] == '$') return FN_INKEY;
        return FN_NONE;
    case 'E':
        if (len == 3 && name[0] == 'E' && name[1] == 'X' && name[2] == 'P') return FN_EXP;
        if ((len == 4 && name[0] == 'E' && name[1] == 'X' && name[2] == 'E' && name[3] == 'C') ||
            (len == 5 && name[0] == 'E' && name[1] == 'X' && name[2] == 'E' && name[3] == 'C' && name[4] == '$'))
            return FN_EXEC;
        return FN_NONE;
    case 'L':
        if (len == 3 && name[0] == 'L' && name[1] == 'O' && name[2] == 'G') return FN_LOG;
        if (len == 3 && name[0] == 'L' && name[1] == 'E' && name[2] == 'N') return FN_LEN;
        if ((len == 4 && name[0] == 'L' && name[1] == 'E' && name[2] == 'F' && name[3] == 'T') ||
            (len == 5 && name[0] == 'L' && name[1] == 'E' && name[2] == 'F' && name[3] == 'T' && name[4] == '$'))
            return FN_LEFT;
        if ((len == 5 && name[0] == 'L' && name[1] == 'C' && name[2] == 'A' && name[3] == 'S' && name[4] == 'E') ||
            (len == 6 && name[0] == 'L' && name[1] == 'C' && name[2] == 'A' && name[3] == 'S' && name[4] == 'E' && name[5] == '$'))
            return FN_LCASE;
        return FN_NONE;
    case 'M':
        if ((len == 3 && name[0] == 'M' && name[1] == 'I' && name[2] == 'D') ||
            (len == 4 && name[0] == 'M' && name[1] == 'I' && name[2] == 'D' && name[3] == '$'))
            return FN_MID;
        return FN_NONE;
    case 'R':
        if (len == 3 && name[0] == 'R' && name[1] == 'N' && name[2] == 'D') return FN_RND;
        if ((len == 5 && name[0] == 'R' && name[1] == 'I' && name[2] == 'G' && name[3] == 'H' && name[4] == 'T') ||
            (len == 6 && name[0] == 'R' && name[1] == 'I' && name[2] == 'G' && name[3] == 'H' && name[4] == 'T' && name[5] == '$'))
            return FN_RIGHT;
        return FN_NONE;
    case 'V':
        if (len == 3 && name[0] == 'V' && name[1] == 'A' && name[2] == 'L') return FN_VAL;
        return FN_NONE;
    case 'D':
        if (len == 3 && name[0] == 'D' && name[1] == 'E' && name[2] == 'C') return FN_DEC;
        return FN_NONE;
    case 'H':
        if ((len == 3 && name[0] == 'H' && name[1] == 'E' && name[2] == 'X') ||
            (len == 4 && name[0] == 'H' && name[1] == 'E' && name[2] == 'X' && name[3] == '$'))
            return FN_HEX;
        return FN_NONE;
    case 'P':
        if (len == 4 && name[0] == 'P' && name[1] == 'E' && name[2] == 'E' && name[3] == 'K') return FN_PEEK;
        return FN_NONE;
    case 'U':
        if ((len == 5 && name[0] == 'U' && name[1] == 'C' && name[2] == 'A' && name[3] == 'S' && name[4] == 'E') ||
            (len == 6 && name[0] == 'U' && name[1] == 'C' && name[2] == 'A' && name[3] == 'S' && name[4] == 'E' && name[5] == '$'))
            return FN_UCASE;
        return FN_NONE;
    default:
        return FN_NONE;
    }
}

#if defined(_WIN32)
/* Windows: sleep using Sleep() in milliseconds derived from 60Hz ticks. */
static void do_sleep_ticks(double ticks)
{
    DWORD ms;
    if (ticks <= 0.0) {
        return;
    }
    ms = (DWORD)(ticks * (1000.0 / 60.0) + 0.5);
    if (ms == 0) {
        return;
    }
    Sleep(ms);
}
#else
/* POSIX/Unix: select-based implementation for 60Hz ticks (no usleep dependency). */
static void do_sleep_ticks(double ticks)
{
    long usec;
    unsigned int sec;
    if (ticks <= 0.0) {
        return;
    }
    usec = (long)(ticks * (1000000.0 / 60.0) + 0.5);
    if (usec <= 0) {
        return;
    }
    sec = (unsigned int)(usec / 1000000L);
    usec = usec % 1000000L;
    /* Use select() for sub-second delay if available */
    {
        struct timeval tv;
        if (sec > 0) {
            sleep(sec);
        }
        if (usec > 0) {
            tv.tv_sec = 0;
            tv.tv_usec = usec;
            select(0, (fd_set *)0, (fd_set *)0, (fd_set *)0, &tv);
        }
    }
}
#endif

/* Parse SLEEP statement and pause execution. */
static void statement_sleep(char **p)
{
    struct value v;
    skip_spaces(p);
    if (**p == '(') {
        (*p)++;
        v = eval_expr(p);
        skip_spaces(p);
        if (**p == ')') {
            (*p)++;
        } else {
            runtime_error("Missing ')'");
            return;
        }
    } else {
        v = eval_expr(p);
    }
    ensure_num(&v);
    do_sleep_ticks(v.num);
}

static void statement_cursor(char **p)
{
    skip_spaces(p);
    if (starts_with_kw(*p, "ON")) {
        *p += 2;
        printf("\033[?25h");
        cursor_hidden = 0;
        fflush(stdout);
        return;
    }
    if (starts_with_kw(*p, "OFF")) {
        *p += 3;
        printf("\033[?25l");
        cursor_hidden = 1;
        fflush(stdout);
        return;
    }
    runtime_error("CURSOR expects ON or OFF");
}

static void statement_color(char **p)
{
    /* COLOR n: set foreground colour using ANSI SGR based on C64-style palette index 0-15. */
    struct value v;
    int idx;

    v = eval_expr(p);
    ensure_num(&v);
    idx = (int)v.num;
    if (idx < 0 || idx > 15) {
        runtime_error("COLOR index must be 0-15");
        return;
    }

#ifdef GFX_VIDEO
    if (gfx_vs) {
        gfx_fg = (uint8_t)idx;
        return;
    }
#endif

    /* Map C64 color index to ANSI foreground SGR. */
    switch (idx) {
    case 0:  printf("\033[30m"); break;       /* black */
    case 1:  printf("\033[37m"); break;       /* white */
    case 2:  printf("\033[31m"); break;       /* red */
    case 3:  printf("\033[36m"); break;       /* cyan */
    case 4:  printf("\033[35m"); break;       /* purple */
    case 5:  printf("\033[32m"); break;       /* green */
    case 6:  printf("\033[34m"); break;       /* blue */
    case 7:  printf("\033[33m"); break;       /* yellow */
    case 8:  printf("\033[38;5;208m"); break; /* orange */
    case 9:  printf("\033[33m"); break;       /* brown (approx) */
    case 10: printf("\033[91m"); break;       /* light red */
    case 11: printf("\033[90m"); break;       /* dark gray */
    case 12: printf("\033[37m"); break;       /* medium gray */
    case 13: printf("\033[92m"); break;       /* light green */
    case 14: printf("\033[94m"); break;       /* light blue */
    case 15: printf("\033[97m"); break;       /* light gray */
    default:
        break;
    }
    fflush(stdout);
}

static void statement_background(char **p)
{
    /* BACKGROUND n: set background colour using ANSI SGR based on C64-style palette index 0-15. */
    struct value v;
    int idx;

    v = eval_expr(p);
    ensure_num(&v);
    idx = (int)v.num;
    if (idx < 0 || idx > 15) {
        runtime_error("BACKGROUND index must be 0-15");
        return;
    }

#ifdef GFX_VIDEO
    if (gfx_vs) {
        gfx_bg = (uint8_t)idx;
        gfx_vs->bg_color = (uint8_t)idx;
        return;
    }
#endif

    /* Map C64 color index to ANSI background SGR. */
    switch (idx) {
    case 0:  printf("\033[40m"); break;        /* black */
    case 1:  printf("\033[47m"); break;        /* white */
    case 2:  printf("\033[41m"); break;        /* red */
    case 3:  printf("\033[46m"); break;        /* cyan */
    case 4:  printf("\033[45m"); break;        /* purple */
    case 5:  printf("\033[42m"); break;        /* green */
    case 6:  printf("\033[44m"); break;        /* blue */
    case 7:  printf("\033[43m"); break;        /* yellow */
    case 8:  printf("\033[48;5;208m"); break;  /* orange */
    case 9:  printf("\033[43m"); break;        /* brown (approx) */
    case 10: printf("\033[101m"); break;       /* light red */
    case 11: printf("\033[100m"); break;       /* dark gray */
    case 12: printf("\033[47m"); break;        /* medium gray */
    case 13: printf("\033[102m"); break;       /* light green */
    case 14: printf("\033[104m"); break;       /* light blue */
    case 15: printf("\033[107m"); break;       /* light gray */
    default:
        break;
    }
    fflush(stdout);
}

static void statement_screencodes(char **p)
{
    /* SCREENCODES ON|OFF: in gfx build, control whether PRINT outputs bytes
     * as raw screen codes (0–255) or maps ASCII to screen codes. */
    skip_spaces(p);
    if (starts_with_kw(*p, "ON")) {
        *p += 2;
        #ifdef GFX_VIDEO
        if (gfx_vs) gfx_raw_screen_codes = 1;
        #endif
        return;
    }
    if (starts_with_kw(*p, "OFF")) {
        *p += 3;
        #ifdef GFX_VIDEO
        if (gfx_vs) gfx_raw_screen_codes = 0;
        #endif
        return;
    }
    runtime_error("SCREENCODES expects ON or OFF");
}

/* GET statement: GET A$ reads a single character into a string variable.
 * This is a blocking read from standard input. Newlines are returned as
 * an empty string so programs can poll if they wish.
 *
 * We stay in raw mode (no echo) across successive GET calls until Enter is
 * read. Otherwise the terminal would echo each key in cooked mode between
 * GETs, causing duplicate/trailing characters (e.g. trek.bas "sls" showing
 * extra "s" on next line).
 */
#ifndef _WIN32
static struct termios get_saved_termios;
static int get_raw_mode_active = 0;
#endif

static int read_single_char(void)
{
#if defined(_WIN32)
    /* _getch() reads a single keypress without waiting for Enter and
     * without echoing it to the console.
     */
    int ch = _getch();
    if (ch == 0 || ch == 224) {
        /* Swallow extended key prefix and read the actual code. */
        ch = _getch();
    }
    return ch;
#else
    struct termios oldt, newt;
    int ch = EOF;

    if (tcgetattr(STDIN_FILENO, &oldt) != 0) {
        return getchar();
    }
    /* If we're not yet in raw mode, set it. Keep it across GET calls. */
    if (!get_raw_mode_active) {
        get_saved_termios = oldt;
        newt = oldt;
        newt.c_lflag &= ~(ICANON | ECHO);
        newt.c_cc[VMIN] = 1;
        newt.c_cc[VTIME] = 0;
        if (tcsetattr(STDIN_FILENO, TCSANOW, &newt) != 0) {
            return getchar();
        }
        get_raw_mode_active = 1;
    }
    ch = getchar();
    /* On Enter: restore cooked mode and consume CR/LF pair. */
    if (ch == '\r' || ch == '\n') {
        if (get_raw_mode_active) {
            get_raw_mode_active = 0;
            tcsetattr(STDIN_FILENO, TCSANOW, &get_saved_termios);
        }
        /* Consume trailing LF after CR (or CR after LF) so it does not leak. */
        {
            int pair = (ch == '\r') ? '\n' : '\r';
            fd_set rfds;
            struct timeval tv = { 0, 0 };
            FD_ZERO(&rfds);
            FD_SET(STDIN_FILENO, &rfds);
            if (select(STDIN_FILENO + 1, &rfds, (fd_set *)0, (fd_set *)0, &tv) > 0) {
                int c2 = getchar();
                if (c2 != pair && c2 != EOF) {
                    ungetc(c2, stdin);
                }
            }
        }
    }
    return ch;
#endif
}

/* Non-blocking key read.
 * Returns EOF if no key is available right now. */
static int read_single_char_nonblock(void)
{
#if defined(_WIN32)
    if (!_kbhit()) {
        return EOF;
    }
    return read_single_char();
#else
    int fd;
    fd_set rfds;
    struct timeval tv;

    fd = fileno(stdin);
    if (fd < 0) {
        return EOF;
    }
    FD_ZERO(&rfds);
    FD_SET(fd, &rfds);
    tv.tv_sec = 0;
    tv.tv_usec = 0;
    if (select(fd + 1, &rfds, (fd_set *)0, (fd_set *)0, &tv) <= 0) {
        return EOF;
    }
    return read_single_char();
#endif
}

static void statement_get(char **p)
{
    struct value *vp;
    int is_array;
    int is_string;
    int ch;

    skip_spaces(p);
    vp = get_var_reference(p, &is_array, &is_string);
    if (!vp) {
        return;
    }
    if (!is_string) {
        runtime_error("GET requires string variable");
        return;
    }

    fflush(stdout);
#ifdef GFX_VIDEO
    if (gfx_vs) {
        uint8_t b = 0;
        if (gfx_keyq_pop(&b)) {
            ch = (int)b;
        } else {
            ch = EOF;
        }
    } else
#endif
    {
        ch = read_single_char_nonblock();
    }
    if (ch == EOF) {
        *vp = make_str("");
    } else if (ch == '\n' || ch == '\r') {
        /* Map Enter/Return to PETSCII-style CHR$(13) so ASC(Y$)=13 works. */
        char buf[2];
        buf[0] = 13;
        buf[1] = '\0';
        *vp = make_str(buf);
    } else {
        char buf[2];
        buf[0] = (char)ch;
        buf[1] = '\0';
        *vp = make_str(buf);
    }
}

/* Case-insensitive string match helper for function names. */
/* Evaluate BASIC intrinsic functions (math/string/tab). */
static struct value eval_function(const char *name, char **p)
{
    char tmp[8];
    struct value arg;
    char outbuf[MAX_STR_LEN];
    int code;
    int len;

    /* Advance past function name */
    read_identifier(p, tmp, sizeof(tmp));
    for (len = 0; tmp[len]; len++) {
        tmp[len] = toupper((unsigned char)tmp[len]);
    }
    code = function_lookup(tmp, len);
    skip_spaces(p);
    if (**p != '(') {
        runtime_error("Function requires '('");
        return make_num(0.0);
    }
    (*p)++;
    skip_spaces(p);
    if (code == FN_ARGC) {
        if (**p != ')') {
            runtime_error("ARGC takes no arguments");
            return make_num(0.0);
        }
        (*p)++;
        skip_spaces(p);
        return make_num((double)script_argc);
    }
    if (code == FN_INKEY) {
        if (**p != ')') {
            runtime_error("INKEY$ takes no arguments");
            return make_str("");
        }
        (*p)++;
        skip_spaces(p);
#ifdef GFX_VIDEO
        if (gfx_vs) {
            uint8_t b;
            if (gfx_keyq_pop(&b)) {
                outbuf[0] = (char)b;
                outbuf[1] = '\0';
                return make_str(outbuf);
            }
            return make_str("");
        }
#endif
        /* Terminal build: no non-blocking key queue. */
        return make_str("");
    }
    arg = eval_expr(p);
    skip_spaces(p);

    /* Functions that accept multiple arguments (MID$, LEFT$, RIGHT$) parse
     * their full argument list themselves and are responsible for consuming
     * the closing ')'. For all other intrinsics we expect exactly one
     * argument and consume ')' here so the caller resumes after it.
     */
    if (code != FN_MID && code != FN_LEFT && code != FN_RIGHT && code != FN_INSTR && code != FN_STRINGFN) {
        if (**p == ')') {
            (*p)++;
        } else {
            runtime_error("Missing ')'");
            return make_num(0.0);
        }
        skip_spaces(p);
    }

    switch (code) {
    case FN_SIN:
        ensure_num(&arg);
        return make_num(sin(arg.num));
    case FN_COS:
        ensure_num(&arg);
        return make_num(cos(arg.num));
    case FN_TAN:
        ensure_num(&arg);
        return make_num(tan(arg.num));
    case FN_ABS:
        ensure_num(&arg);
        return make_num(fabs(arg.num));
    case FN_INT:
        ensure_num(&arg);
        return make_num(floor(arg.num));
    case FN_SQR:
        ensure_num(&arg);
        return make_num(sqrt(arg.num));
    case FN_SGN:
        ensure_num(&arg);
        if (arg.num > 0) {
            return make_num(1.0);
        } else if (arg.num < 0) {
            return make_num(-1.0);
        } else {
            return make_num(0.0);
        }
    case FN_EXP:
        ensure_num(&arg);
        return make_num(exp(arg.num));
    case FN_LOG:
        ensure_num(&arg);
        return make_num(log(arg.num));
    case FN_RND:
        ensure_num(&arg);
        if (arg.num < 0) {
            /* Reseed: C64-style RND(negative) starts a new sequence. We use time so each run gets a different sequence (like RND(-TI) on C64). */
            srand((unsigned int)time(NULL));
        }
        return make_num((double)rand() / (double)RAND_MAX);
    case FN_LEN:
        ensure_str(&arg);
        return make_num((double)strlen(arg.str));
    case FN_VAL:
        ensure_str(&arg);
        return make_num(atof(arg.str));
    case FN_STR:
        ensure_num(&arg);
        sprintf(outbuf, "%g", arg.num);
        return make_str(outbuf);
    case FN_CHR:
        ensure_num(&arg);
        {
            int code = (int)arg.num & 0xff;
#ifdef GFX_VIDEO
            /* In gfx mode we want raw bytes so screen/control codes can be
             * interpreted by the gfx output backend (including {TOKENS}). */
            if (gfx_vs) {
                outbuf[0] = (char)code;
                outbuf[1] = '\0';
                return make_str(outbuf);
            }
#endif
            if (petscii_mode) {
                /* -petscii-plain: no ANSI; control/color output nothing (invisible, like C64 - no visible space). */
                if (petscii_plain) {
                    if (code == 13) return make_str("\n");
                    if (code <= 31 && code != 10) return make_str("");
                    if (code >= 128 && code <= 159) return make_str("");
                    if (code == 127) return make_str("");
                    return make_str(petscii_code_to_utf8((unsigned char)code));
                }
                /* Optional 8-bit palette approximating C64 colors. */
                if (palette_mode == PALETTE_C64_8BIT) {
                    int idx = -1;
                    switch (code) {
                    /* Base C64 colors */
                    case 144: /* black */
                        idx = 16;  /* dark black-ish */
                        break;
                    case 28:  /* red */
                        idx = 196;
                        break;
                    case 30:  /* green */
                        idx = 46;
                        break;
                    case 31:  /* blue */
                        idx = 21;
                        break;
                    case 159: /* cyan */
                        idx = 51;
                        break;
                    case 156: /* purple */
                        idx = 93;
                        break;
                    case 158: /* yellow */
                        idx = 226;
                        break;
                    case 5:   /* white */
                        idx = 231;
                        break;
                    /* Extended C64 colors */
                    case 129: /* orange */
                        idx = 208;
                        break;
                    case 149: /* brown */
                        idx = 130;
                        break;
                    case 150: /* light red */
                        idx = 203;
                        break;
                    case 151: /* dark gray */
                        idx = 238;
                        break;
                    case 152: /* medium gray */
                        idx = 244;
                        break;
                    case 153: /* light green */
                        idx = 120;
                        break;
                    case 154: /* light blue */
                        idx = 81;
                        break;
                    case 155: /* light gray */
                        idx = 252;
                        break;
                    default:
                        break;
                    }
                    if (idx >= 0) {
                        sprintf(outbuf, "\033[38;5;%dm", idx);
                        return make_str(outbuf);
                    }
                }

                /* Default ANSI palette mapping for PETSCII control codes. */
                switch (code) {
                case 14:  /* switch to lowercase/uppercase charset */
                    petscii_set_lowercase(1);
                    return make_str("");
                case 142: /* switch to uppercase/graphics charset */
                    petscii_set_lowercase(0);
                    return make_str("");
                case 19:  /* HOME: home cursor */
                    return make_str("\033[H");
                case 147: /* CLR: clear screen, home cursor */
                    return make_str("\033[2J\033[H");
                case 17:  /* cursor down */
                    return make_str("\033[B");
                case 145: /* cursor up */
                    return make_str("\033[A");
                case 29:  /* cursor right */
                    return make_str("\033[C");
                case 20:  /* DEL: backspace — cursor left and erase character (like ^H) */
                    return make_str("\033[D\033[P");
                case 157: /* cursor left (no erase) */
                    return make_str("\033[D");
                case 18:  /* reverse on */
                    return make_str("\033[7m");
                case 146: /* reverse off */
                    return make_str("\033[27m");
                case 13:  /* carriage return -> newline */
                    return make_str("\n");
                /* Base colors */
                case 144: /* black */
                    return make_str("\033[30m");
                case 5:   /* white */
                    return make_str("\033[37m");
                case 28:  /* red */
                    return make_str("\033[31m");
                case 30:  /* green */
                    return make_str("\033[32m");
                case 31:  /* blue */
                    return make_str("\033[34m");
                case 159: /* cyan */
                    return make_str("\033[96m");
                case 156: /* purple */
                    return make_str("\033[35m");
                case 158: /* yellow */
                    return make_str("\033[33m");
                /* Extended colors (approximate mappings) */
                case 129: /* orange */
                    return make_str("\033[38;5;208m");
                case 149: /* brown */
                    return make_str("\033[33m");
                case 150: /* light red */
                    return make_str("\033[91m");
                case 151: /* dark gray */
                    return make_str("\033[90m");
                case 152: /* medium gray */
                    return make_str("\033[37m");
                case 153: /* light green */
                    return make_str("\033[92m");
                case 154: /* light blue */
                    return make_str("\033[94m");
                case 155: /* light gray */
                    return make_str("\033[97m");
                default:
                    break;
                }
                /* Control/color not in switch: output nothing (invisible, like C64). Table would give " " and break layout. */
                if (code <= 31 && code != 10 && code != 13) return make_str("");
                if (code == 127) return make_str("");
                if (code >= 128 && code <= 159) return make_str("");
                /* Printable PETSCII: map to UTF-8 for terminal (block graphics, etc.) */
                return make_str(petscii_code_to_utf8((unsigned char)code));
            }
            outbuf[0] = (char)code;
            outbuf[1] = '\0';
            return make_str(outbuf);
        }
    case FN_ASC:
        ensure_str(&arg);
        if (arg.str[0] == '\0') {
            return make_num(0.0);
        }
        return make_num((unsigned char)arg.str[0]);
    case FN_TAB: {
        int target;
        int cur;
        int width;
        ensure_num(&arg);
        target = (int)arg.num;
        width = PRINT_WIDTH;
        if (width <= 0) {
            width = 80;
        }
        target = target % width;
        if (target < 0) {
            target += width;
        }
        cur = print_col;
        if (target < cur) {
            fputc('\n', stdout);
            cur = 0;
        }
        while (cur < target) {
            fputc(' ', stdout);
            cur++;
        }
        print_col = cur;
        return make_str("");
    }
    case FN_SPC: {
        int count;
        ensure_num(&arg);
        count = (int)arg.num;
        if (count < 0) {
            count = 0;
        }
        print_spaces(count);
        return make_str("");
    }
    case FN_MID: {
        struct value src = arg;
        struct value v_start;
        struct value v_len;
        int start_pos;
        int sub_len;
        int s_len;

        ensure_str(&src);
        skip_spaces(p);
        if (**p != ',') {
            runtime_error("MID requires at least 2 arguments");
            return make_str("");
        }
        (*p)++;
        v_start = eval_expr(p);
        ensure_num(&v_start);
        skip_spaces(p);
        sub_len = -1;
        if (**p == ',') {
            (*p)++;
            v_len = eval_expr(p);
            ensure_num(&v_len);
            sub_len = (int)v_len.num;
        }
        skip_spaces(p);
        if (**p == ')') {
            (*p)++;
        } else {
            runtime_error("Missing ')'");
        }

        /* BASIC is 1-based for MID$, and negative/zero starts are treated as 1. */
        start_pos = (int)v_start.num;
        if (start_pos < 1) {
            start_pos = 1;
        }
        /* Convert to 0-based index. */
        start_pos -= 1;
        s_len = (int)strlen(src.str);
        if (start_pos >= s_len) {
            return make_str("");
        }
        if (sub_len < 0 || start_pos + sub_len > s_len) {
            sub_len = s_len - start_pos;
        }
        if (sub_len <= 0) {
            return make_str("");
        }
        if (sub_len >= MAX_STR_LEN) {
            sub_len = MAX_STR_LEN - 1;
        }
        {
            char out[MAX_STR_LEN];
            memcpy(out, src.str + start_pos, (size_t)sub_len);
            out[sub_len] = '\0';
            return make_str(out);
        }
    }
    case FN_LEFT: {
        struct value src = arg;
        struct value v_len;
        int sub_len;
        int s_len;

        ensure_str(&src);
        skip_spaces(p);
        if (**p != ',') {
            runtime_error("LEFT requires 2 arguments");
            return make_str("");
        }
        (*p)++;
        v_len = eval_expr(p);
        ensure_num(&v_len);
        skip_spaces(p);
        if (**p == ')') {
            (*p)++;
        } else {
            runtime_error("Missing ')'");
        }

        sub_len = (int)v_len.num;
        if (sub_len <= 0) {
            return make_str("");
        }
        s_len = (int)strlen(src.str);
        if (sub_len > s_len) {
            sub_len = s_len;
        }
        if (sub_len >= MAX_STR_LEN) {
            sub_len = MAX_STR_LEN - 1;
        }
        {
            char out[MAX_STR_LEN];
            memcpy(out, src.str, (size_t)sub_len);
            out[sub_len] = '\0';
            return make_str(out);
        }
    }
    case FN_RIGHT: {
        struct value src = arg;
        struct value v_len;
        int sub_len;
        int s_len;
        int start_pos;

        ensure_str(&src);
        skip_spaces(p);
        if (**p != ',') {
            runtime_error("RIGHT requires 2 arguments");
            return make_str("");
        }
        (*p)++;
        v_len = eval_expr(p);
        ensure_num(&v_len);
        skip_spaces(p);
        if (**p == ')') {
            (*p)++;
        } else {
            runtime_error("Missing ')'");
        }

        sub_len = (int)v_len.num;
        if (sub_len <= 0) {
            return make_str("");
        }
        s_len = (int)strlen(src.str);
        if (sub_len > s_len) {
            sub_len = s_len;
        }
        if (sub_len >= MAX_STR_LEN) {
            sub_len = MAX_STR_LEN - 1;
        }
        start_pos = s_len - sub_len;
        if (start_pos < 0) {
            start_pos = 0;
        }
        {
            char out[MAX_STR_LEN];
            memcpy(out, src.str + start_pos, (size_t)sub_len);
            out[sub_len] = '\0';
            return make_str(out);
        }
    }
    case FN_INSTR: {
        /* INSTR(source$, search$) -> 1-based index or 0 if not found. */
        struct value v_source = arg;
        struct value v_search;
        int s_len;
        int sub_len;
        int i;

        ensure_str(&v_source);
        skip_spaces(p);
        if (**p != ',') {
            runtime_error("INSTR requires 2 arguments");
            return make_num(0.0);
        }
        (*p)++;
        skip_spaces(p);
        v_search = eval_expr(p);
        ensure_str(&v_search);
        skip_spaces(p);
        if (**p == ')') {
            (*p)++;
        } else {
            runtime_error("Missing ')'");
            return make_num(0.0);
        }

        s_len = (int)strlen(v_source.str);
        sub_len = (int)strlen(v_search.str);
        if (sub_len == 0 || s_len == 0) {
            return make_num(0.0);
        }
        for (i = 0; i <= s_len - sub_len; i++) {
            if (strncmp(v_source.str + i, v_search.str, (size_t)sub_len) == 0) {
                return make_num((double)(i + 1));
            }
        }
        return make_num(0.0);
    }
    case FN_DEC: {
        /* DEC(s$): parse hexadecimal string into numeric value. */
        char *endptr;
        long v;
        ensure_str(&arg);
        if (arg.str[0] == '\0') {
            return make_num(0.0);
        }
        v = strtol(arg.str, &endptr, 16);
        if (endptr == arg.str) {
            return make_num(0.0);
        }
        return make_num((double)v);
    }
    case FN_HEX: {
        /* HEX$(n): format integer as uppercase hexadecimal string without prefix. */
        long v;
        ensure_num(&arg);
        v = (long)arg.num;
        sprintf(outbuf, "%lX", v);
        return make_str(outbuf);
    }
    case FN_STRINGFN: {
        /* STRING$(n, char$) or STRING$(n, code) */
        struct value v_count = arg;
        struct value v_ch;
        int count;
        char ch;

        ensure_num(&v_count);
        skip_spaces(p);
        if (**p != ',') {
            runtime_error("STRING$ requires 2 arguments");
            return make_str("");
        }
        (*p)++;
        v_ch = eval_expr(p);
        skip_spaces(p);
        if (**p == ')') {
            (*p)++;
        } else {
            runtime_error("Missing ')'");
            return make_str("");
        }

        count = (int)v_count.num;
        if (count <= 0) {
            return make_str("");
        }
        if (count >= MAX_STR_LEN) {
            count = MAX_STR_LEN - 1;
        }

        if (v_ch.type == VAL_STR) {
            if (v_ch.str[0] == '\0') {
                ch = ' ';
            } else {
                ch = v_ch.str[0];
            }
        } else {
            /* Treat numeric second arg as character code. */
            ch = (char)((int)v_ch.num & 0xff);
        }

        {
            char out[MAX_STR_LEN];
            int i;
            for (i = 0; i < count; i++) {
                out[i] = ch;
            }
            out[count] = '\0';
            return make_str(out);
        }
    }
    case FN_PEEK: {
        ensure_num(&arg);
#ifdef GFX_VIDEO
        if (gfx_vs) {
            return make_num((double)gfx_peek(gfx_vs,
                            (uint16_t)((int)arg.num & 0xFFFF)));
        }
#endif
        return make_num(0.0);
    }
    case FN_UCASE: {
        char out[MAX_STR_LEN];
        size_t i, n;
        ensure_str(&arg);
        n = strlen(arg.str);
        if (n >= MAX_STR_LEN) n = MAX_STR_LEN - 1;
        for (i = 0; i < n; i++)
            out[i] = (char)toupper((unsigned char)arg.str[i]);
        out[n] = '\0';
        return make_str(out);
    }
    case FN_LCASE: {
        char out[MAX_STR_LEN];
        size_t i, n;
        ensure_str(&arg);
        n = strlen(arg.str);
        if (n >= MAX_STR_LEN) n = MAX_STR_LEN - 1;
        for (i = 0; i < n; i++)
            out[i] = (char)tolower((unsigned char)arg.str[i]);
        out[n] = '\0';
        return make_str(out);
    }
    case FN_ARG: {
        int idx;
        ensure_num(&arg);
        idx = (int)arg.num;
        if (idx == 0)
            return make_str(script_path ? script_path : "");
        if (idx < 1 || idx > script_argc || !script_argv)
            return make_str("");
        return make_str(script_argv[idx - 1]);
    }
    case FN_SYSTEM: {
        ensure_str(&arg);
        return make_num((double)do_system(arg.str));
    }
    case FN_EXEC: {
        ensure_str(&arg);
        do_exec(arg.str, outbuf, sizeof(outbuf));
        return make_str(outbuf);
    }
    default:
        runtime_error("Unknown function");
        return make_num(0.0);
    }
}

/* Normalize variable name to uppercase in dest, strip trailing $ and set is_string. */
static void uppercase_name(const char *src, char *dest, int dest_size, int *is_string)
{
    int i, len;
    len = (int)strlen(src);
    *is_string = 0;
    if (len > 0 && src[len - 1] == '$') {
        *is_string = 1;
        len--;
    }
    if (len >= dest_size) len = dest_size - 1;
    for (i = 0; i < len; i++) {
        dest[i] = (char)toupper((unsigned char)src[i]);
    }
    dest[i] = '\0';
}

static struct var *find_or_create_var(const char *name, int is_string, int want_array, int dims, const int *dim_sizes, int total_size)
{
    int i, idx;
    struct var *v;
    for (i = 0; i < var_count; i++) {
        if (strcmp(vars[i].name, name) == 0 && vars[i].is_string == is_string) {
            v = &vars[i];
            if (want_array && !v->is_array) {
                v->is_array = 1;
                v->dims = dims;
                if (dims > 0 && dim_sizes) {
                    int d;
                    for (d = 0; d < dims && d < MAX_DIMS; d++) {
                        v->dim_sizes[d] = dim_sizes[d];
                    }
                }
                v->size = total_size;
                v->array = (struct value *)calloc(total_size, sizeof(struct value));
                if (!v->array) {
                    runtime_error("Out of memory");
                    return v;
                }
            }
            return v;
        }
    }
    if (var_count >= MAX_VARS) {
        runtime_error("Variable table full");
        return NULL;
    }
    idx = var_count++;
    v = &vars[idx];
    strncpy(v->name, name, VAR_NAME_MAX - 1);
    v->name[VAR_NAME_MAX - 1] = '\0';
    v->is_string = is_string;
    v->is_array = want_array;
    v->dims = want_array ? dims : 0;
    if (want_array && dims > 0 && dim_sizes) {
        int d;
        for (d = 0; d < dims && d < MAX_DIMS; d++) {
            v->dim_sizes[d] = dim_sizes[d];
        }
    } else {
        int d;
        for (d = 0; d < MAX_DIMS; d++) {
            v->dim_sizes[d] = 0;
        }
    }
    v->size = want_array ? total_size : 0;
    v->array = NULL;
    v->scalar = make_num(0.0);
    if (is_string) {
        v->scalar = make_str("");
    }
    if (want_array) {
        v->array = (struct value *)calloc(total_size, sizeof(struct value));
        if (!v->array) {
            runtime_error("Out of memory");
        }
    }
    return v;
}

/* Read an identifier (letters/digits/$/_) into buf, advancing the pointer. */
static int read_identifier(char **p, char *buf, int buf_size)
{
    int i;
    i = 0;
    while (isalpha((unsigned char)(**p)) || isdigit((unsigned char)(**p)) || **p == '$' || **p == '_') {
        if (i < buf_size - 1) {
            buf[i++] = **p;
        }
        (*p)++;
    }
    buf[i] = '\0';
    return i;
}

/* Resolve a variable (and optional array index) creating it if needed. */
static struct value *get_var_reference(char **p, int *is_array_out, int *is_string_out)
{
    char namebuf[VAR_NAME_MAX];
    int is_string;
    struct var *v;
    struct value *valp;
    int is_array;
    int dims;
    int indices[MAX_DIMS];
    int flat_index = 0;
    int stride = 1;
    struct value idx_val;

    skip_spaces(p);
    if (!isalpha((unsigned char)**p)) {
        runtime_error("Expected variable");
        return NULL;
    }
    read_identifier(p, namebuf, sizeof(namebuf));
    uppercase_name(namebuf, namebuf, sizeof(namebuf), &is_string);
    if (is_reserved_word(namebuf)) {
        runtime_error("Reserved word cannot be used as variable");
        return NULL;
    }
    if (is_string_out) {
        *is_string_out = is_string;
    }
    skip_spaces(p);
    is_array = 0;
    dims = 0;
    if (**p == '(') {
        is_array = 1;
        (*p)++;
        for (;;) {
            if (dims >= MAX_DIMS) {
                runtime_error("Too many subscripts");
                return NULL;
            }
            idx_val = eval_expr(p);
            ensure_num(&idx_val);
            indices[dims] = (int)(idx_val.num + 0.00001);
            if (indices[dims] < 0) {
                runtime_error("Negative array index");
                return NULL;
            }
            dims++;
            skip_spaces(p);
            if (**p == ',') {
                (*p)++;
                continue;
            }
            break;
        }
        if (**p != ')') {
            runtime_error("Missing ')'");
            return NULL;
        }
        (*p)++;
    }
    if (is_array_out) {
        *is_array_out = is_array;
    }
    v = find_or_create_var(namebuf, is_string, is_array, 0, NULL, 0);
    if (!v) {
        return NULL;
    }
    if (!is_array) {
        valp = &v->scalar;
    } else {
        int d;
        if (v->dims == 0) {
            /* First array use: assume 1-D and adopt current index as size hint. */
            v->dims = 1;
            v->dim_sizes[0] = (indices[0] + 1 > DEFAULT_ARRAY_SIZE) ? (indices[0] + 1) : DEFAULT_ARRAY_SIZE;
            v->size = v->dim_sizes[0];
            v->array = (struct value *)calloc(v->size, sizeof(struct value));
            if (!v->array) {
                runtime_error("Out of memory");
                return NULL;
            }
        }
        if (dims == 0) {
            runtime_error("Array subscript required");
            return NULL;
        }
        if (dims > v->dims) {
            runtime_error("Too many subscripts");
            return NULL;
        }
        /* For now we assume dimensions were fixed by DIM; no auto-resize for multi-dim. */
        flat_index = 0;
        stride = 1;
        for (d = v->dims - 1; d >= 0; d--) {
            int idx = (d < dims) ? indices[d] : 0;
            if (idx < 0 || idx >= v->dim_sizes[d]) {
                runtime_error("Subscript out of range");
                return NULL;
            }
            flat_index += idx * stride;
            stride *= v->dim_sizes[d];
        }
        if (flat_index >= v->size) {
            runtime_error("Subscript out of range");
            return NULL;
        }
        valp = &v->array[flat_index];
    }
    if (is_string && valp->type != VAL_STR) {
        *valp = make_str("");
    } else if (!is_string && valp->type != VAL_NUM) {
        *valp = make_num(0.0);
    }
    return valp;
}

/* Run statements until RETURN or END FUNCTION sets udf_returned. */
static void run_until_udf_return(void)
{
    char *p;
    udf_returned = 0;
    while (!udf_returned && !halted && current_line >= 0 && current_line < line_count) {
        if (statement_pos == NULL) {
            statement_pos = program_lines[current_line]->text;
        }
        p = statement_pos;
        skip_spaces(&p);
        if (*p == '\0') {
            current_line++;
            statement_pos = NULL;
            continue;
        }
        statement_pos = p;
        execute_statement(&statement_pos);
        if (udf_returned || halted) break;
        if (statement_pos == NULL) continue;
        skip_spaces(&statement_pos);
        if (*statement_pos == ':') {
            statement_pos++;
            continue;
        }
        skip_spaces(&statement_pos);
        if (*statement_pos == '\0') {
            current_line++;
            statement_pos = NULL;
        }
    }
}

/* Invoke UDF and return its value. Caller has already parsed name and '('; args evaluated. */
static struct value invoke_udf(int func_index, struct value *args, int nargs)
{
    struct udf_func *uf = &udf_funcs[func_index];
    struct var *param_var;
    int i;

    if (udf_call_depth >= MAX_UDF_DEPTH) {
        runtime_error("FUNCTION nesting too deep");
        return make_num(0.0);
    }
    udf_call_stack[udf_call_depth].func_index = func_index;
    udf_call_stack[udf_call_depth].saved_line = current_line;
    udf_call_stack[udf_call_depth].saved_pos = statement_pos;
    for (i = 0; i < uf->param_count; i++) {
        param_var = find_or_create_var(uf->param_names[i], uf->param_is_string[i], 0, 0, NULL, 0);
        if (param_var && i < nargs) {
            udf_call_stack[udf_call_depth].saved_params[i] = param_var->scalar;
            if (uf->param_is_string[i]) {
                ensure_str(&args[i]);
                param_var->scalar = args[i];
                param_var->scalar.type = VAL_STR;
            } else {
                ensure_num(&args[i]);
                param_var->scalar = args[i];
                param_var->scalar.type = VAL_NUM;
            }
        }
    }
    udf_call_depth++;
    current_line = uf->body_line;
    statement_pos = uf->body_pos;
    run_until_udf_return();
    /* statement_return/statement_end_function already pops; restore params from saved frame */
    for (i = 0; i < uf->param_count; i++) {
        param_var = find_or_create_var(uf->param_names[i], uf->param_is_string[i], 0, 0, NULL, 0);
        if (param_var) param_var->scalar = udf_call_stack[udf_call_depth].saved_params[i];
    }
    return udf_return_value;
}

/* Parse a factor: number, string, variable, function call, or parenthesized expr. */
static struct value eval_factor(char **p)
{
    struct value v;
    char buf[MAX_LINE_LEN];
    double num;
    skip_spaces(p);
    if (**p == '(') {
        (*p)++;
        v = eval_expr(p);
        skip_spaces(p);
        if (**p == ')') {
            (*p)++;
        } else {
            runtime_error("Missing ')'");
        }
        return v;
    }
    if (**p == '\"') {
        int i;
        (*p)++;
        i = 0;
        while (**p && **p != '\"' && i < MAX_STR_LEN - 1) {
            buf[i++] = **p;
            (*p)++;
        }
        buf[i] = '\0';
        if (**p == '\"') {
            (*p)++;
        } else {
            runtime_error("Unterminated string");
        }
        return make_str(buf);
    }
    if (isalpha((unsigned char)**p)) {
        /* System jiffy clock (C64-style): TI and TI$.
         * CBM BASIC resolves TIME, TICKS, etc. to TI due to 2-char name matching;
         * we do the same by keying off the first two characters. */
        {
            char namebuf[8];
            char *q = *p;
            int i, len;
            read_identifier(&q, namebuf, sizeof(namebuf));
            for (i = 0; namebuf[i]; i++) {
                namebuf[i] = (char)toupper((unsigned char)namebuf[i]);
            }
            len = i;
            if (len >= 2 && namebuf[0] == 'T' && namebuf[1] == 'I') {
                int is_str = (len > 0 && namebuf[len - 1] == '$');
#ifdef GFX_VIDEO
                if (gfx_vs) {
                    uint32_t t = gfx_vs->ticks60;
                    *p = q;
                    if (!is_str) {
                        return make_num((double)t);
                    } else {
                        unsigned long sec = (unsigned long)(t / 60u);
                        unsigned long h = (sec / 3600u) % 24u;
                        unsigned long m = (sec / 60u) % 60u;
                        unsigned long s = sec % 60u;
                        sprintf(buf, "%02lu%02lu%02lu", h, m, s);
                        return make_str(buf);
                    }
                } else
#endif
                {
                    /* Terminal fallback: use wall-clock time (e.g. for RND(-TI)). */
                    time_t tt = time(NULL);
                    *p = q;
                    if (is_str) {
                        struct tm *tm = localtime(&tt);
                        sprintf(buf, "%02d%02d%02d",
                                tm->tm_hour, tm->tm_min, tm->tm_sec);
                        return make_str(buf);
                    } else {
                        return make_num((double)(unsigned long)tt);
                    }
                }
            }
        }
    /* Function call? */
    if (starts_with_kw(*p, "SIN") || starts_with_kw(*p, "COS") || starts_with_kw(*p, "TAN") ||
            starts_with_kw(*p, "ABS") || starts_with_kw(*p, "INT") || starts_with_kw(*p, "SQR") ||
            starts_with_kw(*p, "SGN") || starts_with_kw(*p, "EXP") || starts_with_kw(*p, "LOG") ||
            starts_with_kw(*p, "RND") || starts_with_kw(*p, "LEN") || starts_with_kw(*p, "VAL") ||
            starts_with_kw(*p, "STR") || starts_with_kw(*p, "CHR") || starts_with_kw(*p, "ASC") ||
            starts_with_kw(*p, "TAB") || starts_with_kw(*p, "SPC") || starts_with_kw(*p, "MID") ||
            starts_with_kw(*p, "LEFT") || starts_with_kw(*p, "RIGHT") || starts_with_kw(*p, "STRING") ||
            starts_with_kw(*p, "UCASE") || starts_with_kw(*p, "LCASE") ||
            starts_with_kw(*p, "INSTR") || starts_with_kw(*p, "DEC") || starts_with_kw(*p, "HEX") ||
            starts_with_kw(*p, "ARGC") || starts_with_kw(*p, "ARG") ||
            starts_with_kw(*p, "SYSTEM") || starts_with_kw(*p, "EXEC") ||
            starts_with_kw(*p, "PEEK") || starts_with_kw(*p, "INKEY")) {
            char namebuf[8];
            char *q;
            q = *p;
            read_identifier(&q, namebuf, sizeof(namebuf));
            return eval_function(namebuf, p);
        } else {
            /* Check for user-defined FUNCTION or DEF FN, else variable */
            char namebuf[VAR_NAME_MAX];
            char *q;
            int i, arg_count, udf_idx, uf_index;
            struct value args[MAX_UDF_PARAMS];
            q = *p;
            read_identifier(&q, namebuf, sizeof(namebuf));
            for (i = 0; namebuf[i]; i++) {
                namebuf[i] = (char)toupper((unsigned char)namebuf[i]);
            }
            skip_spaces(&q);
            if (*q == '(') {
                char *saved_p = *p;
                *p = q + 1;
                skip_spaces(p);
                arg_count = 0;
                if (**p != ')') {
                    for (;;) {
                        if (arg_count >= MAX_UDF_PARAMS) {
                            runtime_error("Too many arguments");
                            return make_num(0.0);
                        }
                        args[arg_count] = eval_expr(p);
                        arg_count++;
                        skip_spaces(p);
                        if (**p == ')') break;
                        if (**p != ',') {
                            runtime_error("Expected ',' or ')'");
                            return make_num(0.0);
                        }
                        (*p)++;
                        skip_spaces(p);
                    }
                }
                if (**p == ')') (*p)++;
                udf_idx = udf_lookup(namebuf, arg_count);
                if (udf_idx >= 0) {
                    return invoke_udf(udf_idx, args, arg_count);
                }
                if (arg_count == 1) {
                    uf_index = user_func_lookup(namebuf);
                    if (uf_index >= 0) {
                        struct user_func *uf = &user_funcs[uf_index];
                        struct value result;
                        struct var *param_var;
                        struct value saved_scalar;
                        char pname_buf[VAR_NAME_MAX];

                        strncpy(pname_buf, uf->param_name, sizeof(pname_buf) - 1);
                        pname_buf[sizeof(pname_buf) - 1] = '\0';
                        param_var = find_or_create_var(pname_buf, uf->param_is_string, 0, 0, NULL, 0);
                        if (!param_var) return make_num(0.0);
                        saved_scalar = param_var->scalar;
                        if (uf->param_is_string) {
                            ensure_str(&args[0]);
                            param_var->scalar = args[0];
                            param_var->scalar.type = VAL_STR;
                        } else {
                            ensure_num(&args[0]);
                            param_var->scalar = args[0];
                            param_var->scalar.type = VAL_NUM;
                        }
                        { char *body_p = uf->body; result = eval_expr(&body_p); }
                        param_var->scalar = saved_scalar;
                        return result;
                    }
                }
                /* No UDF or DEF FN matched; treat as array/variable */
                *p = saved_p;
            }
            {
                struct value *vp;
                vp = get_var_reference(p, NULL, NULL);
                if (!vp) return make_num(0.0);
                return *vp;
            }
        }
    }
    if (**p == '+' || **p == '-') {
        char sign;
        struct value inner;
        sign = **p;
        (*p)++;
        inner = eval_factor(p);
        ensure_num(&inner);
        if (sign == '-') {
            inner.num = -inner.num;
        }
        return inner;
    }
    if (parse_number_literal(p, &num)) {
        return make_num(num);
    }
    runtime_error("Syntax error in expression");
    return make_num(0.0);
}

/* Parse exponentiation (right-associative ^). */
static struct value eval_power(char **p)
{
    struct value left, right;
    skip_spaces(p);
    left = eval_factor(p);
    skip_spaces(p);
    if (**p == '^') {
        (*p)++;
        right = eval_power(p);
        ensure_num(&left);
        ensure_num(&right);
        left.num = pow(left.num, right.num);
    }
    return left;
}

/* Parse *,/ terms. */
static struct value eval_term(char **p)
{
    struct value left, right;
    skip_spaces(p);
    left = eval_power(p);
    for (;;) {
        skip_spaces(p);
        if (**p == '*' || **p == '/') {
            char op;
            op = **p;
            (*p)++;
            right = eval_power(p);
            ensure_num(&left);
            ensure_num(&right);
            if (op == '*') {
                left.num *= right.num;
            } else {
                left.num /= right.num;
            }
        } else {
            break;
        }
    }
    return left;
}

/* Parse + and - expressions (with string concatenation on +). */
static struct value eval_expr(char **p)
{
    struct value left, right;
    skip_spaces(p);
    left = eval_term(p);
    for (;;) {
        skip_spaces(p);
        if (**p == '+' || **p == '-') {
            char op;
            op = **p;
            (*p)++;
            right = eval_term(p);
            if (op == '+') {
                if (left.type == VAL_STR || right.type == VAL_STR) {
                    ensure_str(&left);
                    ensure_str(&right);
                    strncat(left.str, right.str, MAX_STR_LEN - strlen(left.str) - 1);
                } else {
                    left.num += right.num;
                }
            } else {
                ensure_num(&left);
                ensure_num(&right);
                left.num -= right.num;
            }
        } else {
            break;
        }
    }
    return left;
}

/* Evaluate IF conditions with BASIC relational operators. */
/* Evaluate a single relational comparison (no AND/OR). */
static int eval_simple_condition(char **p)
{
    struct value left, right;
    char op1, op2;

    skip_spaces(p);
    left = eval_expr(p);
    skip_spaces(p);
    op1 = **p;
    op2 = *(*p + 1);

    if (op1 == '<' && op2 == '>') {
        *p += 2;
        right = eval_expr(p);
        if (left.type == VAL_STR || right.type == VAL_STR) {
            ensure_str(&left);
            ensure_str(&right);
            return strcmp(left.str, right.str) != 0;
        } else {
            return left.num != right.num;
        }
    }
    if (op1 == '<' && op2 == '=') {
        *p += 2;
        right = eval_expr(p);
        ensure_num(&left);
        ensure_num(&right);
        return left.num <= right.num;
    }
    if (op1 == '>' && op2 == '=') {
        *p += 2;
        right = eval_expr(p);
        ensure_num(&left);
        ensure_num(&right);
        return left.num >= right.num;
    }
    if (op1 == '<' || op1 == '>' || op1 == '=') {
        (*p)++;
        right = eval_expr(p);
        if (left.type == VAL_STR || right.type == VAL_STR) {
            ensure_str(&left);
            ensure_str(&right);
            if (op1 == '<') {
                return strcmp(left.str, right.str) < 0;
            } else if (op1 == '>') {
                return strcmp(left.str, right.str) > 0;
            } else {
                return strcmp(left.str, right.str) == 0;
            }
        } else {
            if (op1 == '<') {
                return left.num < right.num;
            } else if (op1 == '>') {
                return left.num > right.num;
            } else {
                return left.num == right.num;
            }
        }
    }
    /* No explicit relational operator: treat expression truthiness. */
    if (left.type == VAL_STR) {
        ensure_str(&left);
        return strlen(left.str) > 0;
    }
    return left.num != 0.0;
}

/* Evaluate IF conditions with BASIC relational operators and AND/OR. */
static int eval_condition(char **p)
{
    int result;

    result = eval_simple_condition(p);
    for (;;) {
        skip_spaces(p);
        if (starts_with_kw(*p, "AND")) {
            *p += 3;
            {
                int rhs = eval_simple_condition(p);
                result = result && rhs;
            }
            continue;
        }
        if (starts_with_kw(*p, "OR")) {
            *p += 2;
            {
                int rhs = eval_simple_condition(p);
                result = result || rhs;
            }
            continue;
        }
        break;
    }
    return result;
}

/* Skip rest of line (REM or ' comment). */
static void statement_rem(char **p)
{
    *p += strlen(*p);
}

/* PRINT / ? statement.
 * Semantics are CBM-like:
 * - Expressions separated by ';' print back-to-back with no extra spacing.
 * - Expressions separated by ',' advance to the next print "zone".
 * - If the last separator in the statement is ';' or ',', no newline is emitted.
 * - A bare PRINT (no expressions) always emits a newline.
 */
static void statement_print(char **p)
{
    int any_output;
    int ended_with_sep;
    struct value v;

    any_output = 0;
    ended_with_sep = 0;

    for (;;) {
        skip_spaces(p);
        if (**p == '\0' || **p == ':') {
            break;
        }

        /* Leading separators (e.g., PRINT , , "X") */
        if (**p == ';') {
            ended_with_sep = 1;
            (*p)++;
            continue;
        } else if (**p == ',') {
            int zone;
            int nextcol;
            ended_with_sep = 1;
            zone = 10;
            nextcol = ((print_col / zone) + 1) * zone;
            if (nextcol < print_col) {
                nextcol = print_col;
            }
            print_spaces(nextcol - print_col);
            (*p)++;
            continue;
        }

        v = eval_expr(p);
        print_value(&v);
        any_output = 1;
        ended_with_sep = 0;

        skip_spaces(p);
        if (**p == ';') {
            ended_with_sep = 1;
            (*p)++;
        } else if (**p == ',') {
            int zone;
            int nextcol;
            ended_with_sep = 1;
            zone = 10;
            nextcol = ((print_col / zone) + 1) * zone;
            if (nextcol < print_col) {
                nextcol = print_col;
            }
            print_spaces(nextcol - print_col);
            (*p)++;
        } else {
            break;
        }
    }

    /* Bare PRINT: always newline. */
    if (!any_output) {
#ifdef GFX_VIDEO
        if (gfx_vs) {
            gfx_newline();
            return;
        }
#endif
        fputc('\n', stdout);
        print_col = 0;
        fflush(stdout);
        return;
    }

    /* Trailing ';' or ',' suppresses newline. */
    if (!ended_with_sep) {
#ifdef GFX_VIDEO
        if (gfx_vs) {
            gfx_newline();
            return;
        }
#endif
        fputc('\n', stdout);
        print_col = 0;
    }
    fflush(stdout);
}


static void statement_textat(char **p)
{
    struct value vx, vy, vtext;
    int x, y;

    /* TEXTAT x, y, text */
    vx = eval_expr(p);
    ensure_num(&vx);
    skip_spaces(p);
    if (**p != ',') {
        runtime_error("TEXTAT: expected ',' after X");
        return;
    }
    (*p)++;

    vy = eval_expr(p);
    ensure_num(&vy);
    skip_spaces(p);
    if (**p != ',') {
        runtime_error("TEXTAT: expected ',' after Y");
        return;
    }
    (*p)++;

    vtext = eval_expr(p);
    ensure_str(&vtext);

    x = (int)vx.num;
    if (x < 0) x = 0;
    y = (int)vy.num;
    if (y < 0) y = 0;

#ifdef GFX_VIDEO
    if (gfx_vs) {
        gfx_x = x;
        gfx_y = y;
        print_col = gfx_x;
        {
            char *s = vtext.str;
            while (*s) {
                gfx_put_byte((unsigned char)*s++);
            }
        }
        return;
    }
#endif

    /* Move cursor with ANSI: rows/cols are 1-based */
    printf("\033[%d;%dH", y + 1, x + 1);
    fputs(vtext.str, stdout);
    fflush(stdout);
}


static void statement_locate(char **p)
{
    // Passed as LOCATE x, y
    struct value vx, vy;
    int x, y;

    // Validation
    vx = eval_expr(p);  ensure_num(&vx);
    skip_spaces(p);
    if (**p != ',') { runtime_error("LOCATE: expected ',' after X"); return; }
    (*p)++;
    vy = eval_expr(p);  ensure_num(&vy);
    skip_spaces(p);

    x = (int)vx.num; if (x < 0) x = 0;
    y = (int)vy.num; if (y < 0) y = 0;

#ifdef GFX_VIDEO
    if (gfx_vs) {
        gfx_x = x;
        gfx_y = y;
        print_col = gfx_x;
        return;
    }
#endif

    // Move cursor with ANSI: rows/cols are 1-based
    printf("\033[%d;%dH", y + 1, x + 1);
    fflush(stdout);
}

static void statement_input(char **p)
{
    char prompt[MAX_STR_LEN];
    char linebuf[MAX_LINE_LEN];
    int first_prompt;
    struct value *vp;
    int is_array;
    int is_string;

    prompt[0] = '\0';
    skip_spaces(p);
    first_prompt = 1;
    if (**p == '\"') {
        struct value s;
        s = eval_factor(p);
        ensure_str(&s);
        strncpy(prompt, s.str, sizeof(prompt) - 1);
        prompt[sizeof(prompt) - 1] = '\0';
        skip_spaces(p);
        if (**p == ';' || **p == ',') {
            (*p)++;
        }
    }
    for (;;) {
        skip_spaces(p);
        if (**p == '\0' || **p == ':') {
            break;
        }
        if (!isalpha((unsigned char)**p)) {
            runtime_error("Expected variable in INPUT");
            return;
        }
        vp = get_var_reference(p, &is_array, &is_string);
        if (!vp) {
            return;
        }
        if (prompt[0] != '\0' && first_prompt) {
            printf("%s", prompt);
        }
        printf("? ");
        fflush(stdout);
        if (!fgets(linebuf, sizeof(linebuf), stdin)) {
            runtime_error("Unexpected end of input");
            return;
        }
        trim_newline(linebuf);
        if (is_string) {
            *vp = make_str(linebuf);
        } else {
            *vp = make_num(atof(linebuf));
        }
        skip_spaces(p);
        if (**p == ',') {
            (*p)++;
            first_prompt = 0;
            continue;
        }
        break;
    }
}

/* ON expr GOTO line1, line2, ... / ON expr GOSUB line1, line2, ... */
static void statement_on(char **p)
{
    struct value idxv;
    int idx;
    int is_gosub = 0;

    /* Evaluate the selector expression (1-based index). */
    idxv = eval_expr(p);
    ensure_num(&idxv);
    idx = (int)idxv.num;

    skip_spaces(p);
    if (starts_with_kw(*p, "GOTO")) {
        is_gosub = 0;
        *p += 4;
    } else if (starts_with_kw(*p, "GOSUB")) {
        is_gosub = 1;
        *p += 5;
    } else {
        runtime_error("ON must be followed by GOTO or GOSUB");
        return;
    }

    /* Walk the comma-separated list of line numbers. */
    {
        int current = 1;
        while (1) {
            int target;

            skip_spaces(p);
            if (!isdigit((unsigned char)**p)) {
                runtime_error("Expected line number in ON");
                return;
            }
            target = atoi(*p);
            while (**p && isdigit((unsigned char)**p)) {
                (*p)++;
            }

            if (idx == current) {
                int line_index = find_line_index(target);
                if (line_index < 0) {
                    runtime_error("Target line not found");
                    return;
                }
                if (is_gosub) {
                    if (gosub_top >= MAX_GOSUB) {
                        runtime_error("GOSUB stack overflow");
                        return;
                    }
                    gosub_stack[gosub_top].line_index = current_line;
                    gosub_stack[gosub_top].position = *p;
                    gosub_top++;
                }
                current_line = line_index;
                statement_pos = NULL;
                return;
            }

            /* Not the selected entry; skip to next, if any. */
            skip_spaces(p);
            if (**p == ',') {
                (*p)++;
                current++;
                continue;
            }
            break;
        }
    }
    /* If index is out of range, ON expression simply falls through. */
}

/* RESTORE: reset DATA pointer so the next READ gets the first DATA value (C64 BASIC V2). */
static void statement_restore(char **p)
{
    (void)p;
    data_index = 0;
}

/* CLR: reset all variables to 0/empty, clear GOSUB/FOR stacks, reset DATA pointer.
 * DEF FN definitions are left intact (CBM-style). */
static void statement_clr(char **p)
{
    int i, j;
    (void)p;

    for (i = 0; i < var_count; i++) {
        struct var *v = &vars[i];
        v->scalar = v->is_string ? make_str("") : make_num(0.0);
        if (v->array && v->size > 0) {
            for (j = 0; j < v->size; j++) {
                v->array[j] = v->is_string ? make_str("") : make_num(0.0);
            }
        }
    }
    gosub_top = 0;
    for_top = 0;
    while_top = 0;
    do_top = 0;
    if_depth = 0;
    data_index = 0;
}

/* Set ST (I/O status) variable for file operations: 0=ok, 64=EOF, 1=error. */
static void set_io_status(int st)
{
    struct var *v = find_or_create_var("ST", 0, 0, 0, NULL, 0);
    if (v) {
        v->scalar.type = VAL_NUM;
        v->scalar.num = (double)st;
        v->scalar.str[0] = '\0';
    }
}

/* OPEN lfn [, device [, secondary [, "filename" ]]] */
static void statement_open(char **p)
{
    int lfn, device, secondary;
    char fname[MAX_STR_LEN];
    const char *mode;
    FILE *fp;

    skip_spaces(p);
    if (!isdigit((unsigned char)**p)) {
        runtime_error("OPEN: expected logical file number");
        return;
    }
    lfn = atoi(*p);
    while (isdigit((unsigned char)**p)) (*p)++;
    if (lfn < 1 || lfn > 255) {
        runtime_error("OPEN: file number must be 1-255");
        return;
    }
    skip_spaces(p);
    device = 1;
    secondary = 0;
    if (**p == ',') {
        (*p)++;
        skip_spaces(p);
        if (isdigit((unsigned char)**p)) {
            device = atoi(*p);
            while (isdigit((unsigned char)**p)) (*p)++;
        }
        skip_spaces(p);
        if (**p == ',') {
            (*p)++;
            skip_spaces(p);
            if (isdigit((unsigned char)**p)) {
                secondary = atoi(*p);
                while (isdigit((unsigned char)**p)) (*p)++;
            }
            skip_spaces(p);
        }
    }
    fname[0] = '\0';
    if (**p == ',') {
        (*p)++;
        skip_spaces(p);
        if (**p == '"') {
            (*p)++;
            size_t i = 0;
            while (**p && **p != '"' && i < sizeof(fname) - 1)
                fname[i++] = *(*p)++;
            fname[i] = '\0';
            if (**p == '"') (*p)++;
        }
    }
    if (open_files[lfn]) {
        fclose(open_files[lfn]);
        open_files[lfn] = NULL;
    }
    if (fname[0] == '\0') {
        runtime_error("OPEN: filename required");
        return;
    }
    if (device == 1 || device == 0) {
        if (secondary == 0) mode = "r";
        else if (secondary == 1) mode = "w";
        else mode = "a";
        fp = fopen(fname, mode);
        if (!fp) {
            set_io_status(1);
            runtime_error("OPEN: cannot open file");
            return;
        }
        open_files[lfn] = fp;
        set_io_status(0);
    } else {
        set_io_status(1);
        runtime_error("OPEN: unsupported device");
    }
}

/* CLOSE [lfn [, lfn ...]] or CLOSE (close all) */
static void statement_close(char **p)
{
    int lfn;
    skip_spaces(p);
    if (**p == '\0' || **p == ':') {
        for (lfn = 1; lfn < 256; lfn++) {
            if (open_files[lfn]) {
                fclose(open_files[lfn]);
                open_files[lfn] = NULL;
            }
        }
        return;
    }
    for (;;) {
        if (!isdigit((unsigned char)**p)) break;
        lfn = atoi(*p);
        while (isdigit((unsigned char)**p)) (*p)++;
        if (lfn >= 1 && lfn <= 255 && open_files[lfn]) {
            fclose(open_files[lfn]);
            open_files[lfn] = NULL;
        }
        skip_spaces(p);
        if (**p != ',') break;
        (*p)++;
        skip_spaces(p);
    }
}

/* PRINT# lfn, expr [,|; expr ...] — like PRINT but to file. */
static void statement_print_hash(char **p)
{
    int lfn;
    struct value v;
    int any_output = 0;
    int ended_with_sep = 0;

    skip_spaces(p);
    if (!isdigit((unsigned char)**p)) {
        runtime_error("PRINT#: expected file number");
        return;
    }
    lfn = atoi(*p);
    while (isdigit((unsigned char)**p)) (*p)++;
    if (lfn < 1 || lfn > 255 || !open_files[lfn]) {
        runtime_error("PRINT#: file not open");
        return;
    }
    skip_spaces(p);
    if (**p == ',') (*p)++;
    skip_spaces(p);

    for (;;) {
        if (**p == '\0' || **p == ':') break;
        if (**p == ';') { (*p)++; continue; }
        if (**p == ',') { fprintf(open_files[lfn], "\t"); (*p)++; continue; }
        v = eval_expr(p);
        any_output = 1;
        ended_with_sep = 0;
        if (v.type == VAL_STR) {
            fputs(v.str, open_files[lfn]);
        } else {
            fprintf(open_files[lfn], "%g", v.num);
        }
        skip_spaces(p);
        if (**p == ';') { ended_with_sep = 1; (*p)++; }
        else if (**p == ',') { fprintf(open_files[lfn], "\t"); ended_with_sep = 1; (*p)++; }
        else break;
        skip_spaces(p);
    }
    if (!ended_with_sep && any_output) fprintf(open_files[lfn], "\n");
    fflush(open_files[lfn]);
}

/* Read one token from file (skip spaces/newlines, read until comma or newline or EOF). */
static int read_file_token(FILE *fp, char *buf, int buf_size)
{
    int i = 0;
    int c;
    while ((c = fgetc(fp)) != EOF && (c == ' ' || c == '\t' || c == '\n' || c == '\r')) ;
    if (c == EOF) { buf[0] = '\0'; return 0; }
    if (c == ',') { buf[0] = '\0'; return 1; }
    if (c == '\n' || c == '\r') { buf[0] = '\0'; ungetc(c, fp); return 1; }
    while (i < buf_size - 1) {
        if (c == EOF || c == ',' || c == '\n' || c == '\r') break;
        buf[i++] = (char)(unsigned char)c;
        c = fgetc(fp);
    }
    buf[i] = '\0';
    if (c == ',' || c == '\n' || c == '\r') ungetc(c, fp);
    return 1;
}

/* INPUT# lfn, var [, var ...] — one token per variable (comma/newline separated). */
static void statement_input_hash(char **p)
{
    int lfn;
    char tokbuf[MAX_STR_LEN];
    struct value *vp;
    int is_array, is_string;

    skip_spaces(p);
    if (!isdigit((unsigned char)**p)) {
        runtime_error("INPUT#: expected file number");
        return;
    }
    lfn = atoi(*p);
    while (isdigit((unsigned char)**p)) (*p)++;
    if (lfn < 1 || lfn > 255 || !open_files[lfn]) {
        set_io_status(1);
        runtime_error("INPUT#: file not open");
        return;
    }
    skip_spaces(p);
    if (**p == ',') (*p)++;
    skip_spaces(p);

    for (;;) {
        if (**p == '\0' || **p == ':') break;
        if (!isalpha((unsigned char)**p)) break;
        vp = get_var_reference(p, &is_array, &is_string);
        if (!vp) return;
        if (is_array) {
            runtime_error("INPUT#: array not allowed");
            return;
        }
        if (!read_file_token(open_files[lfn], tokbuf, sizeof(tokbuf))) {
            set_io_status(64);
            *vp = is_string ? make_str("") : make_num(0.0);
        } else {
            set_io_status(0);
            if (is_string) {
                *vp = make_str(tokbuf);
            } else {
                *vp = make_num(atof(tokbuf));
            }
        }
        skip_spaces(p);
        if (**p == ',') (*p)++;
        else break;
    }
}

/* GET# lfn, stringvar — read one character. */
static void statement_get_hash(char **p)
{
    int lfn;
    int c;
    struct value *vp;
    int is_array, is_string;

    skip_spaces(p);
    if (!isdigit((unsigned char)**p)) {
        runtime_error("GET#: expected file number");
        return;
    }
    lfn = atoi(*p);
    while (isdigit((unsigned char)**p)) (*p)++;
    if (lfn < 1 || lfn > 255 || !open_files[lfn]) {
        set_io_status(1);
        runtime_error("GET#: file not open");
        return;
    }
    skip_spaces(p);
    if (**p == ',') (*p)++;
    skip_spaces(p);
    if (!isalpha((unsigned char)**p)) {
        runtime_error("GET#: expected string variable");
        return;
    }
    vp = get_var_reference(p, &is_array, &is_string);
    if (!vp || !is_string || is_array) {
        runtime_error("GET#: requires string variable");
        return;
    }
    c = fgetc(open_files[lfn]);
    if (c == EOF) {
        set_io_status(64);
        *vp = make_str("");
    } else {
        set_io_status(0);
        {
            char buf[2];
            buf[0] = (char)(unsigned char)c;
            buf[1] = '\0';
            *vp = make_str(buf);
        }
    }
}

static void statement_let(char **p)
{
    struct value *vp;
    struct value rhs;
    int is_array;
    int is_string;

    vp = get_var_reference(p, &is_array, &is_string);
    if (!vp) {
        return;
    }
    skip_spaces(p);
    if (**p != '=') {
        runtime_error("Expected '='");
        return;
    }
    (*p)++;
    rhs = eval_expr(p);
    if (is_string) {
        ensure_str(&rhs);
        rhs.type = VAL_STR;
    } else {
        ensure_num(&rhs);
        rhs.type = VAL_NUM;
    }
    *vp = rhs;
}

static void statement_goto(char **p)
{
    skip_spaces(p);
    if (isdigit((unsigned char)**p)) {
        int line_number;
        line_number = atoi(*p);
        while (**p && isdigit((unsigned char)**p)) {
            (*p)++;
        }
        current_line = find_line_index(line_number);
        if (current_line < 0) {
            runtime_error("Target line not found");
            return;
        }
        statement_pos = NULL;
    } else if (isalpha((unsigned char)**p)) {
        char namebuf[32];
        int len = 0;
        while ((isalpha((unsigned char)**p) || isdigit((unsigned char)**p) || **p == '_') &&
               len < (int)sizeof(namebuf) - 1) {
            namebuf[len++] = **p;
            (*p)++;
        }
        namebuf[len] = '\0';
        current_line = find_label_line(namebuf);
        if (current_line < 0) {
            runtime_error("Target label not found");
            return;
        }
        statement_pos = NULL;
    } else {
        runtime_error("Expected line number or label in GOTO");
    }
}

static void statement_gosub(char **p)
{
    int target_index = -1;
    char *return_pos;

    if (gosub_top >= MAX_GOSUB) {
        runtime_error("GOSUB stack overflow");
        return;
    }
    skip_spaces(p);
    if (isdigit((unsigned char)**p)) {
        int target_num;
        target_num = atoi(*p);
        while (**p && isdigit((unsigned char)**p)) {
            (*p)++;
        }
        target_index = find_line_index(target_num);
    } else if (isalpha((unsigned char)**p)) {
        char namebuf[32];
        int len = 0;
        while ((isalpha((unsigned char)**p) || isdigit((unsigned char)**p) || **p == '_') &&
               len < (int)sizeof(namebuf) - 1) {
            namebuf[len++] = **p;
            (*p)++;
        }
        namebuf[len] = '\0';
        target_index = find_label_line(namebuf);
    } else {
        runtime_error("Expected line number or label in GOSUB");
        return;
    }

    if (target_index < 0) {
        runtime_error("Target line/label not found");
        return;
    }

    return_pos = *p;
    gosub_stack[gosub_top].line_index = current_line;
    gosub_stack[gosub_top].position = return_pos;
    gosub_top++;
    current_line = target_index;
    statement_pos = NULL;
}

static void statement_return(char **p)
{
    if (udf_call_depth > 0) {
        skip_spaces(p);
        if (*p && **p && **p != ':' && (isalnum((unsigned char)**p) || **p == '(' || **p == '-' || **p == '+' || **p == '\"')) {
            udf_return_value = eval_expr(p);
        } else {
            udf_return_value = make_num(0.0);
        }
        udf_returned = 1;
        udf_call_depth--;
        current_line = udf_call_stack[udf_call_depth].saved_line;
        statement_pos = udf_call_stack[udf_call_depth].saved_pos;
        return;
    }
    if (gosub_top <= 0) {
        runtime_error("RETURN without GOSUB");
        return;
    }
    gosub_top--;
    current_line = gosub_stack[gosub_top].line_index;
    statement_pos = gosub_stack[gosub_top].position;
}

/* Skip forward from current position to ELSE (if want_else) or END IF.
 * Updates current_line, statement_pos, and *p. Handles nested IF blocks. */
static void skip_if_block_to_target(char **p, int want_else)
{
    int line = current_line;
    char *pos = *p;
    int nesting = 1;

    while (line >= 0 && line < line_count && program_lines[line]) {
        if (!pos) pos = program_lines[line]->text;
        while (pos && *pos) {
            char *q = pos;
            skip_spaces(&q);
            if (!*q) break;
            /* Nested IF: any IF ... THEN (block or inline) increments nesting. */
            if (starts_with_kw(q, "IF")) {
                char *r = q + 2;
                while (*r) {
                    skip_spaces(&r);
                    if (!*r) break;
                    if (starts_with_kw(r, "THEN")) {
                        nesting++;
                        r += 4;
                        break;
                    }
                    if (*r == '\"') { r++; while (*r && *r != '\"') r++; if (*r) r++; continue; }
                    if (*r == '(') { int pn = 1; r++; while (pn && *r) { if (*r == '(') pn++; else if (*r == ')') pn--; r++; } continue; }
                    r++;
                }
                pos = r;
                continue;
            }
            if (starts_with_kw(q, "END")) {
                char *r = q + 3;
                skip_spaces(&r);
                if (starts_with_kw(r, "IF")) {
                    r += 2;
                    skip_spaces(&r);
                    nesting--;
                    if (nesting == 0) {
                        current_line = line;
                        statement_pos = r;
                        *p = r;
                        if_depth--;
                        return;
                    }
                    pos = r;
                    continue;
                }
            }
            if (nesting == 1 && starts_with_kw(q, "ELSE")) {
                if (want_else) {
                    q += 4;
                    skip_spaces(&q);
                    current_line = line;
                    statement_pos = q;
                    *p = q;
                    return;
                }
                q += 4;
                skip_spaces(&q);
                pos = q;
                continue;
            }
            pos = strchr(pos, ':');
            pos = pos ? pos + 1 : NULL;
        }
        line++;
        pos = NULL;
    }
    runtime_error("END IF expected");
}

/* Skip forward from current position to matching WEND. Handles nested WHILE/WEND. */
static void skip_while_to_wend(char **p)
{
    int line = current_line;
    char *pos = *p;
    int nesting = 1;

    while (line >= 0 && line < line_count && program_lines[line]) {
        if (!pos) pos = program_lines[line]->text;
        while (pos && *pos) {
            char *q = pos;
            skip_spaces(&q);
            if (!*q) break;
            if (starts_with_kw(q, "WHILE")) {
                q += 5;
                skip_spaces(&q);
                if (*q && *q != ':') {
                    nesting++;
                    while (*q && *q != ':') q++;
                    pos = (*q == ':') ? q + 1 : q;
                    continue;
                }
            }
            if (starts_with_kw(q, "WEND")) {
                char *r = q + 4;
                skip_spaces(&r);
                nesting--;
                if (nesting == 0) {
                    if (!*r && line + 1 < line_count) {
                        current_line = line + 1;
                        statement_pos = program_lines[line + 1]->text;
                        *p = statement_pos;
                    } else {
                        current_line = line;
                        statement_pos = r;
                        *p = r;
                    }
                    return;
                }
                pos = r;
                continue;
            }
            pos = strchr(pos, ':');
            pos = pos ? pos + 1 : NULL;
        }
        line++;
        pos = NULL;
    }
    runtime_error("WEND expected");
}

static void statement_if(char **p)
{
    int cond_true;
    char *after_then;

    cond_true = eval_condition(p);
    skip_spaces(p);
    if (!starts_with_kw(*p, "THEN")) {
        runtime_error("Missing THEN");
        return;
    }
    *p += 4;
    skip_spaces(p);
    after_then = *p;
    /* Block mode: THEN at EOL or followed only by ':' then EOL */
    if (!*after_then || (*after_then == ':' && !after_then[1])) {
        if (if_depth >= MAX_IF_DEPTH) {
            runtime_error("IF nesting too deep");
            return;
        }
        if_stack[if_depth].took_then = cond_true ? 1 : 0;
        if_depth++;
        if (!cond_true) {
            skip_if_block_to_target(p, 1);
        }
        return;
    }
    if (!cond_true) {
        *p += strlen(*p);
        return;
    }
    if (isdigit((unsigned char)**p)) {
        int target;
        target = atoi(*p);
        while (**p && isdigit((unsigned char)**p)) {
            (*p)++;
        }
        current_line = find_line_index(target);
        if (current_line < 0) {
            runtime_error("Target line not found");
            return;
        }
        statement_pos = NULL;
    } else {
        skip_spaces(p);
        statement_pos = *p;
    }
}

static void statement_else(char **p)
{
    if (if_depth <= 0) {
        runtime_error("ELSE without IF");
        return;
    }
    skip_spaces(p);
    if (if_stack[if_depth - 1].took_then) {
        skip_if_block_to_target(p, 0);
    }
}

static void statement_end_if(char **p)
{
    if (if_depth <= 0) {
        runtime_error("END IF without matching IF");
        return;
    }
    skip_spaces(p);
    if_depth--;
}

/* Skip from FUNCTION to after matching END FUNCTION (top-level only). */
static void skip_function_block(char **p)
{
    int line = current_line;
    char *pos;
    int nesting = 1;

    *p += 8; /* past "FUNCTION" */
    while (**p && **p != ':') (*p)++;
    if (**p == ':') { (*p)++; skip_spaces(p); pos = *p; } else { line++; pos = NULL; }
    while (line >= 0 && line < line_count && program_lines[line]) {
        if (!pos) pos = program_lines[line]->text;
        while (pos && *pos) {
            char *q = pos;
            skip_spaces(&q);
            if (!*q) break;
            if ((toupper((unsigned char)q[0])=='F' && toupper((unsigned char)q[1])=='U' &&
                 toupper((unsigned char)q[2])=='N' && toupper((unsigned char)q[3])=='C' &&
                 toupper((unsigned char)q[4])=='T' && toupper((unsigned char)q[5])=='I' &&
                 toupper((unsigned char)q[6])=='O' && toupper((unsigned char)q[7])=='N') &&
                (q[8]=='\0' || q[8]==' ' || q[8]=='\t')) {
                nesting++;
                q += 8;
                while (*q && *q != ':') q++;
                pos = (*q == ':') ? q + 1 : q;
                continue;
            }
            if (toupper((unsigned char)q[0])=='E' && toupper((unsigned char)q[1])=='N' &&
                toupper((unsigned char)q[2])=='D' && (q[3]=='\0' || q[3]==' ' || q[3]=='\t')) {
                char *ef = q + 3;
                while (*ef == ' ' || *ef == '\t') ef++;
                if (toupper((unsigned char)ef[0])=='F' && toupper((unsigned char)ef[1])=='U' &&
                    toupper((unsigned char)ef[2])=='N' && toupper((unsigned char)ef[3])=='C' &&
                    toupper((unsigned char)ef[4])=='T' && toupper((unsigned char)ef[5])=='I' &&
                    toupper((unsigned char)ef[6])=='O' && toupper((unsigned char)ef[7])=='N' &&
                    (ef[8]=='\0' || ef[8]==' ' || ef[8]=='\t' || ef[8]==':')) {
                    nesting--;
                    if (nesting == 0) {
                        ef += 8;
                        skip_spaces(&ef);
                        current_line = line;
                        statement_pos = ef;
                        *p = ef;
                        return;
                    }
                    pos = ef + 8;
                    while (*pos && *pos != ':') pos++;
                    pos = (*pos == ':') ? pos + 1 : pos;
                    continue;
                }
            }
            pos = strchr(pos, ':');
            pos = pos ? pos + 1 : NULL;
        }
        line++;
        pos = NULL;
    }
    runtime_error("END FUNCTION expected");
}

static void statement_end_function(char **p)
{
    if (udf_call_depth <= 0) {
        runtime_error("END FUNCTION without FUNCTION");
        return;
    }
    skip_spaces(p);
    udf_return_value = make_num(0.0);
    udf_returned = 1;
    udf_call_depth--;
    current_line = udf_call_stack[udf_call_depth].saved_line;
    statement_pos = udf_call_stack[udf_call_depth].saved_pos;
}

static void statement_while(char **p, char *while_pos)
{
    int cond_true;

    cond_true = eval_condition(p);
    if (!cond_true) {
        skip_while_to_wend(p);
        return;
    }
    if (while_top >= MAX_WHILE_DEPTH) {
        runtime_error("WHILE nesting too deep");
        return;
    }
    while_stack[while_top].line_index = current_line;
    while_stack[while_top].position = while_pos;
    while_top++;
}

static void statement_wend(char **p)
{
    if (while_top <= 0) {
        runtime_error("WEND without WHILE");
        return;
    }
    *p += 4;
    skip_spaces(p);
    {
        int idx = while_top - 1;
        current_line = while_stack[idx].line_index;
        statement_pos = while_stack[idx].position;
        while_top--;
    }
}

/* Skip forward from current position to after the matching LOOP. Handles nested DO/LOOP. */
static void skip_do_to_after_loop(char **p)
{
    int line = current_line;
    char *pos = *p;
    int nesting = 1;

    while (line >= 0 && line < line_count && program_lines[line]) {
        if (!pos) pos = program_lines[line]->text;
        while (pos && *pos) {
            char *q = pos;
            skip_spaces(&q);
            if (!*q) break;
            if (starts_with_kw(q, "DO")) {
                nesting++;
                q += 2;
                skip_spaces(&q);
                pos = q;
                continue;
            }
            if (starts_with_kw(q, "LOOP")) {
                char *r = q + 4;
                skip_spaces(&r);
                nesting--;
                if (nesting == 0) {
                    /* Skip past LOOP [UNTIL expr] */
                    if (starts_with_kw(r, "UNTIL")) {
                        r += 5;
                        skip_spaces(&r);
                        if (*r && *r != ':') {
                            struct value dummy = eval_expr(&r);
                            (void)dummy;
                        }
                    }
                    skip_spaces(&r);
                    if (!*r && line + 1 < line_count) {
                        current_line = line + 1;
                        statement_pos = program_lines[line + 1]->text;
                        *p = statement_pos;
                    } else {
                        current_line = line;
                        statement_pos = r;
                        *p = r;
                    }
                    return;
                }
                pos = r;
                continue;
            }
            pos = strchr(pos, ':');
            pos = pos ? pos + 1 : NULL;
        }
        line++;
        pos = NULL;
    }
    runtime_error("LOOP expected");
}

static void statement_do(char **p)
{
    skip_spaces(p);
    if (do_top >= MAX_DO_DEPTH) {
        runtime_error("DO nesting too deep");
        return;
    }
    do_stack[do_top].line_index = current_line;
    do_stack[do_top].position = *p;
    do_top++;
}

static void statement_loop(char **p)
{
    int cond_true = 0;
    int has_until = 0;

    if (do_top <= 0) {
        runtime_error("LOOP without DO");
        return;
    }
    skip_spaces(p);
    if (starts_with_kw(*p, "UNTIL")) {
        has_until = 1;
        *p += 5;
        skip_spaces(p);
        cond_true = eval_condition(p);
    }
    if (has_until && cond_true) {
        /* Exit loop: pop and continue after LOOP UNTIL expr */
        do_top--;
        skip_spaces(p);
        if (!**p && current_line + 1 < line_count) {
            current_line++;
            statement_pos = program_lines[current_line]->text;
            *p = statement_pos;
        }
        return;
    }
    /* Loop back to DO (do not pop - we will hit this LOOP again) */
    {
        int idx = do_top - 1;
        current_line = do_stack[idx].line_index;
        statement_pos = do_stack[idx].position;
        *p = statement_pos;
    }
}

static void statement_exit_do(char **p)
{
    if (do_top <= 0) {
        runtime_error("EXIT without DO");
        return;
    }
    do_top--;
    skip_do_to_after_loop(p);
}

static void statement_for(char **p)
{
    struct value *vp;
    struct value startv, endv, stepv;
    int is_array;
    int is_string;
    int i;
    vp = get_var_reference(p, &is_array, &is_string);
    if (!vp) {
        return;
    }
    if (is_array) {
        runtime_error("FOR variable must be scalar");
        return;
    }
    if (is_string) {
        runtime_error("FOR variable must be numeric");
        return;
    }
    skip_spaces(p);
    if (**p != '=') {
        runtime_error("Expected '=' in FOR");
        return;
    }
    (*p)++;
    startv = eval_expr(p);
    ensure_num(&startv);
    skip_spaces(p);
    if (!starts_with_kw(*p, "TO")) {
        runtime_error("Expected TO in FOR");
        return;
    }
    *p += 2;
    endv = eval_expr(p);
    ensure_num(&endv);
    skip_spaces(p);
    if (starts_with_kw(*p, "STEP")) {
        *p += 4;
        stepv = eval_expr(p);
        ensure_num(&stepv);
    } else {
        stepv = make_num(1.0);
    }
    *vp = startv;

    /* Recover loop variable name from vp by searching var table. */
    for_stack[for_top].name[0] = '\0';
    if (var_count > 0) {
        for (i = 0; i < var_count; i++) {
            if (&vars[i].scalar == vp ||
                (vars[i].is_array && vp >= vars[i].array && vp < vars[i].array + vars[i].size)) {
                strncpy(for_stack[for_top].name, vars[i].name, VAR_NAME_MAX - 1);
                for_stack[for_top].name[VAR_NAME_MAX - 1] = '\0';
                break;
            }
        }
    }

    /* Abandon any outstanding FOR for the same control variable.
     * This models classic BASIC behaviour where jumping out of a loop
     * effectively discards it, so reusing the same variable does not
     * grow the FOR stack without bound.
     */
    for (i = for_top - 1; i >= 0; i--) {
        if (strcmp(for_stack[i].name, for_stack[for_top].name) == 0) {
            for_top = i;
            break;
        }
    }

    if (for_top >= MAX_FOR) {
        runtime_error("FOR stack overflow");
        return;
    }
    for_stack[for_top].end_value = endv.num;
    for_stack[for_top].step = stepv.num;
    for_stack[for_top].line_index = current_line;
    for_stack[for_top].resume_pos = *p;
    for_stack[for_top].var = vp;
    for_stack[for_top].is_string = is_string;
    for_top++;
}

static void statement_next(char **p)
{
    char namebuf[VAR_NAME_MAX];
    int i;
    struct value *vp;
    int is_string;
    skip_spaces(p);
    if (isalpha((unsigned char)**p)) {
        read_identifier(p, namebuf, sizeof(namebuf));
        uppercase_name(namebuf, namebuf, sizeof(namebuf), &is_string);
    } else {
        namebuf[0] = '\0';
    }
    for (i = for_top - 1; i >= 0; i--) {
        if (namebuf[0] == '\0' || strcmp(for_stack[i].name, namebuf) == 0) {
            break;
        }
    }
    if (i < 0) {
        runtime_error("NEXT without FOR");
        return;
    }
    for_top = i + 1;
    vp = for_stack[for_top - 1].var;
    if (!vp) {
        runtime_error("Loop variable missing");
        return;
    }
    vp->num += for_stack[for_top - 1].step;
    if ((for_stack[for_top - 1].step >= 0 && vp->num <= for_stack[for_top - 1].end_value) ||
        (for_stack[for_top - 1].step < 0 && vp->num >= for_stack[for_top - 1].end_value)) {
        current_line = for_stack[for_top - 1].line_index;
        statement_pos = for_stack[for_top - 1].resume_pos;
    } else {
        for_top--;
    }
}

static void statement_dim(char **p)
{
    for (;;) {
        char namebuf[VAR_NAME_MAX];
        int is_string;
        int dims = 0;
        int dim_sizes[MAX_DIMS];
        int total_size = 1;
        struct var *v;
        struct value sizev;
        skip_spaces(p);
        if (!isalpha((unsigned char)**p)) {
            runtime_error("Expected array name");
            return;
        }
        read_identifier(p, namebuf, sizeof(namebuf));
        uppercase_name(namebuf, namebuf, sizeof(namebuf), &is_string);
        if (is_reserved_word(namebuf)) {
            runtime_error("Reserved word cannot be used as variable");
            return;
        }
        skip_spaces(p);
        if (**p != '(') {
            runtime_error("DIM requires size");
            return;
        }
        (*p)++;
        for (;;) {
            if (dims >= MAX_DIMS) {
                runtime_error("Too many dimensions");
                return;
            }
            sizev = eval_expr(p);
            ensure_num(&sizev);
            dim_sizes[dims] = (int)sizev.num + 1;
            if (dim_sizes[dims] <= 0) {
                runtime_error("Invalid array size");
                return;
            }
            dims++;
            skip_spaces(p);
            if (**p == ',') {
                (*p)++;
                continue;
            }
            break;
        }
        if (**p != ')') {
            runtime_error("Missing ')'");
            return;
        }
        (*p)++;
        /* Compute total size as product of dimensions. */
        {
            int d;
            for (d = 0; d < dims; d++) {
                total_size *= dim_sizes[d];
            }
        }
        v = find_or_create_var(namebuf, is_string, 1, dims, dim_sizes, total_size);
        (void)v;
        skip_spaces(p);
        if (**p == ',') {
            (*p)++;
            continue;
        }
        break;
    }
}

static void execute_statement(char **p)
{
    char c;
    skip_spaces(p);
    if (**p == '\0') {
        return;
    }
    /* Explicit PRINT# / INPUT# / GET# (allow optional space before #). */
    if ((*p)[0] != '\0' && toupper((unsigned char)(*p)[0]) == 'P' && toupper((unsigned char)(*p)[1]) == 'R' &&
        toupper((unsigned char)(*p)[2]) == 'I' && toupper((unsigned char)(*p)[3]) == 'N' &&
        toupper((unsigned char)(*p)[4]) == 'T') {
        char *q = *p + 5;
        while (*q == ' ' || *q == '\t') q++;
        if (*q == '#') {
            *p = q + 1;
            statement_print_hash(p);
            return;
        }
    }
    if (toupper((unsigned char)(*p)[0]) == 'I' && toupper((unsigned char)(*p)[1]) == 'N' &&
        toupper((unsigned char)(*p)[2]) == 'P' && toupper((unsigned char)(*p)[3]) == 'U' &&
        toupper((unsigned char)(*p)[4]) == 'T') {
        char *q = *p + 5;
        while (*q == ' ' || *q == '\t') q++;
        if (*q == '#') {
            *p = q + 1;
            statement_input_hash(p);
            return;
        }
    }
    if (toupper((unsigned char)(*p)[0]) == 'G' && toupper((unsigned char)(*p)[1]) == 'E' &&
        toupper((unsigned char)(*p)[2]) == 'T') {
        char *q = *p + 3;
        while (*q == ' ' || *q == '\t') q++;
        if (*q == '#') {
            *p = q + 1;
            statement_get_hash(p);
            return;
        }
    }
    c = toupper((unsigned char)**p);
    if (c == '\0') {
        return;
    }
    if (c == '\'') {
        statement_rem(p);
        return;
    }
    if (c == '?') {
        (*p)++;
        statement_print(p);
        return;
    }
    if (c == 'R') {
        if (starts_with_kw(*p, "REM")) {
            *p += 3;
            statement_rem(p);
            return;
        }
        if (starts_with_kw(*p, "READ")) {
            *p += 4;
            statement_read(p);
            return;
        }
        if (starts_with_kw(*p, "RESTORE")) {
            *p += 7;
            statement_restore(p);
            return;
        }
        if (starts_with_kw(*p, "RETURN")) {
            *p += 6;
            statement_return(p);
            return;
        }
    }
    if (c == 'O') {
        if (starts_with_kw(*p, "OPEN")) {
            *p += 4;
            statement_open(p);
            return;
        }
    }
    if (c == 'C') {
        if (starts_with_kw(*p, "CLOSE")) {
            *p += 5;
            statement_close(p);
            return;
        }
    }
    if (c == 'P') {
        /* PRINT# must be recognized (starts_with_kw allows '#' as terminator for PRINT). */
        if (starts_with_kw(*p, "PRINT")) {
            *p += 5;
            skip_spaces(p);
            if (**p == '#') {
                (*p)++;
                statement_print_hash(p);
                return;
            }
            statement_print(p);
            return;
        }
        if (starts_with_kw(*p, "POKE")) {
            *p += 4;
#ifdef GFX_VIDEO
            {
                struct value v_addr, v_val;
                v_addr = eval_expr(p);
                ensure_num(&v_addr);
                skip_spaces(p);
                if (**p == ',') (*p)++;
                v_val = eval_expr(p);
                ensure_num(&v_val);
                if (gfx_vs) {
                    gfx_poke(gfx_vs,
                             (uint16_t)((int)v_addr.num & 0xFFFF),
                             (uint8_t)((int)v_val.num & 0xFF));
                }
            }
#else
            *p += strlen(*p);
#endif
            return;
        }
    }
    if (c == 'I' && starts_with_kw(*p, "INPUT")) {
        *p += 5;
        skip_spaces(p);
        if (**p == '#') {
            (*p)++;
            statement_input_hash(p);
            return;
        }
        statement_input(p);
        return;
    }
    if (c == 'L') {
        if (starts_with_kw(*p, "LOOP")) {
            *p += 4;
            statement_loop(p);
            return;
        }
        if (starts_with_kw(*p, "LET")) {
            *p += 3;
            statement_let(p);
            return;
        }
    }
    if (c == 'L' && starts_with_kw(*p, "LOCATE")) {
        *p += 6;
        statement_locate(p);
        return;
    }
    if (c == 'T' && starts_with_kw(*p, "TEXTAT")) {
        *p += 6;
        statement_textat(p);
        return;
    }
    if (c == 'G' && starts_with_kw(*p, "GET")) {
        *p += 3;
        skip_spaces(p);
        if (**p == '#') {
            (*p)++;
            statement_get_hash(p);
            return;
        }
        statement_get(p);
        return;
    }
    if (c == 'G' && starts_with_kw(*p, "GOTO")) {
        *p += 4;
        statement_goto(p);
        return;
    }
    if (c == 'G' && starts_with_kw(*p, "GOSUB")) {
        *p += 5;
        statement_gosub(p);
        return;
    }
    if (c == 'O' && starts_with_kw(*p, "ON")) {
        *p += 2;
        statement_on(p);
        return;
    }
    if (c == 'R' && starts_with_kw(*p, "RETURN")) {
        *p += 6;
        statement_return(p);
        return;
    }
    if (c == 'I' && starts_with_kw(*p, "IF")) {
        *p += 2;
        statement_if(p);
        return;
    }
    if (c == 'F' && starts_with_kw(*p, "FOR")) {
        *p += 3;
        statement_for(p);
        return;
    }
    if (c == 'N' && starts_with_kw(*p, "NEXT")) {
        *p += 4;
        statement_next(p);
        return;
    }
    if (c == 'W') {
        if (starts_with_kw(*p, "WHILE")) {
            char *while_pos = *p;
            *p += 5;
            skip_spaces(p);
            statement_while(p, while_pos);
            return;
        }
        if (starts_with_kw(*p, "WEND")) {
            statement_wend(p);
            return;
        }
    }
    if (c == 'D') {
        if (starts_with_kw(*p, "DO")) {
            *p += 2;
            statement_do(p);
            return;
        }
        /* DATA lines are non-executable (values were collected at load time). */
        if (starts_with_kw(*p, "DATA")) {
            *p += strlen(*p);
            return;
        }
        /* DIM arrays */
        if (starts_with_kw(*p, "DIM")) {
            *p += 3;
            statement_dim(p);
            return;
        }
        /* DEF FN user-defined function */
        {
            char *q;
            q = *p;
            if ((q[0] == 'D' || q[0] == 'd') &&
                (q[1] == 'E' || q[1] == 'e') &&
                (q[2] == 'F' || q[2] == 'f') &&
                (q[3] == '\0' || q[3] == ' ' || q[3] == '\t' || q[3] == '(' || q[3] == ':')) {
                *p += 3;
                statement_def(p);
                return;
            }
        }
    }
    if (c == 'S' && starts_with_kw(*p, "SLEEP")) {
        *p += 5;
        statement_sleep(p);
        return;
    }
    if (c == 'E') {
        if (starts_with_kw(*p, "EXIT")) {
            *p += 4;  /* consume EXIT */
            statement_exit_do(p);
            return;
        }
        if (starts_with_kw(*p, "ELSE")) {
            *p += 4;
            statement_else(p);
            return;
        }
        if (starts_with_kw(*p, "END")) {
            char *q = *p + 3;
            skip_spaces(&q);
            if (starts_with_kw(q, "IF")) {
                *p = q + 2;
                statement_end_if(p);
                return;
            }
            if (starts_with_kw(q, "FUNCTION")) {
                *p = q + 8;
                statement_end_function(p);
                return;
            }
            halted = 1;
            *p += strlen(*p);
            return;
        }
    }
    if (c == 'F') {
        if (starts_with_kw(*p, "FUNCTION") && ((*p)[8]=='\0' || (*p)[8]==' ' || (*p)[8]=='\t')) {
            skip_function_block(p);
            return;
        }
    }
    if (c == 'S' && starts_with_kw(*p, "STOP")) {
        halted = 1;
        *p += strlen(*p);
        return;
    }
    if (c == 'C') {
        if (starts_with_kw(*p, "CLR")) {
            *p += 3;
            statement_clr(p);
            return;
        }
        if (starts_with_kw(*p, "CURSOR")) {
            *p += 6;
            statement_cursor(p);
            return;
        }
        if (starts_with_kw(*p, "COLOR") || starts_with_kw(*p, "COLOUR")) {
            /* Accept both COLOR and COLOUR spellings. */
            if (toupper((unsigned char)(*p)[3]) == 'O' && toupper((unsigned char)(*p)[4]) == 'U') {
                *p += 6; /* COLOUR */
            } else {
                *p += 5; /* COLOR */
            }
            statement_color(p);
            return;
        }
    }
    if (c == 'B' && starts_with_kw(*p, "BACKGROUND")) {
        *p += 10;
        statement_background(p);
        return;
    }
    if (c == 'S' && starts_with_kw(*p, "SCREENCODES")) {
        *p += 11;
        statement_screencodes(p);
        return;
    }
    if (isalpha((unsigned char)c)) {
        /* Check for "name(...)" as UDF or DEF FN call (statement form, discard return). */
        {
            char namebuf[VAR_NAME_MAX];
            char *q = *p;
            int arg_count, udf_idx, uf_index, i;
            struct value args[MAX_UDF_PARAMS];
            read_identifier(&q, namebuf, sizeof(namebuf));
            for (i = 0; namebuf[i]; i++) namebuf[i] = (char)toupper((unsigned char)namebuf[i]);
            skip_spaces(&q);
            if (*q == '(') {
                char *saved_p = *p;
                *p = q + 1;
                skip_spaces(p);
                arg_count = 0;
                if (**p != ')') {
                    for (;;) {
                        if (arg_count >= MAX_UDF_PARAMS) {
                            runtime_error("Too many arguments");
                            return;
                        }
                        args[arg_count] = eval_expr(p);
                        arg_count++;
                        skip_spaces(p);
                        if (**p == ')') break;
                        if (**p != ',') {
                            runtime_error("Expected ',' or ')'");
                            return;
                        }
                        (*p)++;
                        skip_spaces(p);
                    }
                }
                if (**p == ')') (*p)++;
                udf_idx = udf_lookup(namebuf, arg_count);
                if (udf_idx >= 0) {
                    (void)invoke_udf(udf_idx, args, arg_count);
                    return;
                }
                if (arg_count == 1) {
                    uf_index = user_func_lookup(namebuf);
                    if (uf_index >= 0) {
                        struct user_func *uf = &user_funcs[uf_index];
                        struct var *param_var;
                        struct value saved_scalar;
                        char pname_buf[VAR_NAME_MAX];
                        strncpy(pname_buf, uf->param_name, sizeof(pname_buf) - 1);
                        pname_buf[sizeof(pname_buf) - 1] = '\0';
                        param_var = find_or_create_var(pname_buf, uf->param_is_string, 0, 0, NULL, 0);
                        if (param_var) {
                            saved_scalar = param_var->scalar;
                            if (uf->param_is_string) {
                                ensure_str(&args[0]);
                                param_var->scalar = args[0];
                                param_var->scalar.type = VAL_STR;
                            } else {
                                ensure_num(&args[0]);
                                param_var->scalar = args[0];
                                param_var->scalar.type = VAL_NUM;
                            }
                            { char *body_p = uf->body; (void)eval_expr(&body_p); }
                            param_var->scalar = saved_scalar;
                        }
                        return;
                    }
                }
                /* No match; restore and fall through to implicit LET */
                *p = saved_p;
            }
        }
        /* Fallback: treat as implicit LET (assignment). */
        statement_let(p);
        return;
    }
    /* As a last resort, treat unknown leading tokens as a no-op for this
     * statement, skipping to the end of the line. This avoids spurious
     * "Unknown statement" errors on otherwise valid programs that use
     * extended syntax we don't fully recognize yet.
     */
    *p += strlen(*p);
}

static void sort_program(void)
{
    int i, j;
    for (i = 0; i < line_count; i++) {
        for (j = i + 1; j < line_count; j++) {
            if (program_lines[j]->number < program_lines[i]->number) {
                struct line *tmp;
                tmp = program_lines[i];
                program_lines[i] = program_lines[j];
                program_lines[j] = tmp;
            }
        }
    }
}

static int find_line_index(int number)
{
    int i;
    for (i = 0; i < line_count; i++) {
        if (program_lines[i] && program_lines[i]->number == number) {
            return i;
        }
    }
    return -1;
}

static void add_or_replace_line(int number, const char *text)
{
    int i;
    for (i = 0; i < line_count; i++) {
        if (program_lines[i] && program_lines[i]->number == number) {
            if (program_lines[i]->text) {
                free(program_lines[i]->text);
            }
            program_lines[i]->text = dupstr_local(text);
            return;
        }
    }
    if (line_count >= MAX_LINES) {
        runtime_error("Program too large");
        return;
    }
    program_lines[line_count] = (struct line *)malloc(sizeof(struct line));
    if (!program_lines[line_count]) {
        runtime_error("Out of memory");
        return;
    }
    program_lines[line_count]->number = number;
    program_lines[line_count]->text = dupstr_local(text);
    line_count++;
}

/* Add line from included file; error if line number already exists. */
static void add_line_from_include(int number, const char *text)
{
    int i;
    for (i = 0; i < line_count; i++) {
        if (program_lines[i] && program_lines[i]->number == number) {
            fprintf(stderr, "Duplicate line number %d in include\n", number);
            exit(1);
        }
    }
    add_or_replace_line(number, text);
}

/* Get directory part of path. Returns "." if no directory. Writes to static buffer. */
static const char *get_base_dir(const char *path)
{
    static char dirbuf[MAX_INCLUDE_PATH];
    const char *last;
    last = strrchr(path, '/');
#if defined(_WIN32)
    {
        const char *b = strrchr(path, '\\');
        if (b && (!last || b > last)) last = b;
    }
#endif
    if (!last || last == path) {
        return ".";
    }
    if ((size_t)(last - path + 1) >= sizeof(dirbuf)) {
        return ".";
    }
    memcpy(dirbuf, path, (size_t)(last - path));
    dirbuf[last - path] = '\0';
    return dirbuf;
}

/* Resolve include path relative to base_dir. Writes to static buffer. */
static const char *resolve_include_path(const char *base_dir, const char *rel_path)
{
    static char buf[MAX_INCLUDE_PATH];
    if (!base_dir || !rel_path) return rel_path;
    if (strcmp(base_dir, ".") == 0) {
        if (strlen(rel_path) >= sizeof(buf)) return NULL;
        strncpy(buf, rel_path, sizeof(buf) - 1);
        buf[sizeof(buf) - 1] = '\0';
        return buf;
    }
    if (strlen(base_dir) + 1 + strlen(rel_path) >= sizeof(buf)) return NULL;
    snprintf(buf, sizeof(buf), "%s/%s", base_dir, rel_path);
    return buf;
}

static char loading_paths[MAX_INCLUDE_DEPTH][MAX_INCLUDE_PATH];
static int loading_count = 0;

/* Load a file into the program, with directive processing. Recursive for #INCLUDE. */
static void load_file_into_program(const char *path, const char *base_dir, int include_depth,
    int *use_explicit_numbers, int *auto_line_no, int *first_line_seen)
{
    FILE *f;
    char linebuf[MAX_LINE_LEN];
    char *p;
    int number;
    const char *resolved;
    int i;

    if (include_depth >= MAX_INCLUDE_DEPTH) {
        fprintf(stderr, "Include nesting too deep: %s\n", path);
        exit(1);
    }
    /* Circular include: check if we're already loading this path. */
    for (i = 0; i < loading_count; i++) {
        if (strcmp(loading_paths[i], path) == 0) {
            fprintf(stderr, "Circular include: %s\n", path);
            exit(1);
        }
    }
    if (loading_count >= MAX_INCLUDE_DEPTH || strlen(path) >= MAX_INCLUDE_PATH) {
        fprintf(stderr, "Include error: %s\n", path);
        exit(1);
    }
    strncpy(loading_paths[loading_count], path, MAX_INCLUDE_PATH - 1);
    loading_paths[loading_count][MAX_INCLUDE_PATH - 1] = '\0';
    loading_count++;

    f = fopen(path, "r");
    if (!f) {
        fprintf(stderr, "Cannot open %s\n", path);
        exit(1);
    }

    while (fgets(linebuf, sizeof(linebuf), f)) {
        trim_newline(linebuf);
        p = linebuf;
        while (*p == ' ' || *p == '\t') p++;
        if ((unsigned char)p[0] == 0xef && (unsigned char)p[1] == 0xbb && (unsigned char)p[2] == 0xbf)
            p += 3;
        if (*p == '\0') continue;

        /* Shebang: first line of first file only */
        if (!*first_line_seen && p[0] == '#' && p[1] == '!') {
            *first_line_seen = 1;
            continue;
        }

        /* Meta directives: #OPTION, #INCLUDE */
        if (p[0] == '#') {
            *first_line_seen = 1;
            p++;
            while (*p == ' ' || *p == '\t') p++;
            if ((toupper((unsigned char)p[0])=='O' && toupper((unsigned char)p[1])=='P' && toupper((unsigned char)p[2])=='T' && toupper((unsigned char)p[3])=='I' && toupper((unsigned char)p[4])=='O' && toupper((unsigned char)p[5])=='N') && (p[6]=='\0' || p[6]==' ' || p[6]=='\t')) {
                char opt_name[64], opt_val[64];
                char *q;
                p += 6;
                while (*p == ' ' || *p == '\t') p++;
                q = opt_name;
                while (*p && *p != ' ' && *p != '\t' && (size_t)(q - opt_name) < sizeof(opt_name) - 1)
                    *q++ = (char)*p++;
                *q = '\0';
                while (*p == ' ' || *p == '\t') p++;
                q = opt_val;
                while (*p && (size_t)(q - opt_val) < sizeof(opt_val) - 1) *q++ = (char)*p++;
                *q = '\0';
                while (q > opt_val && (q[-1] == ' ' || q[-1] == '\t')) *--q = '\0';
                if (apply_option_directive(opt_name, opt_val[0] ? opt_val : NULL) != 0) {
                    fprintf(stderr, "Unknown or invalid #OPTION: %s %s\n", opt_name, opt_val);
                    exit(1);
                }
                continue;
            }
            if ((toupper((unsigned char)p[0])=='I' && toupper((unsigned char)p[1])=='N' && toupper((unsigned char)p[2])=='C' && toupper((unsigned char)p[3])=='L' && toupper((unsigned char)p[4])=='U' && toupper((unsigned char)p[5])=='D' && toupper((unsigned char)p[6])=='E') && (p[7]=='\0' || p[7]==' ' || p[7]=='\t')) {
                char inc_file[MAX_INCLUDE_PATH];
                p += 7;
                while (*p == ' ' || *p == '\t') p++;
                if (*p != '"' && *p != '\'') {
                    fprintf(stderr, "Expected quoted path in #INCLUDE\n");
                    exit(1);
                }
                {
                    char quote = *p++;
                    char *q = inc_file;
                    while (*p && *p != quote && (size_t)(q - inc_file) < sizeof(inc_file) - 1)
                        *q++ = (char)*p++;
                    *q = '\0';
                    if (*p) p++;
                }
                resolved = resolve_include_path(base_dir, inc_file);
                if (!resolved) { fprintf(stderr, "Include path too long\n"); exit(1); }
                if (strlen(resolved) >= MAX_INCLUDE_PATH) { fprintf(stderr, "Include path too long\n"); exit(1); }
                /* Store resolved path so it survives the recursive call. */
                strncpy(include_path_store[MAX_INCLUDE_DEPTH - 1], resolved, MAX_INCLUDE_PATH - 1);
                include_path_store[MAX_INCLUDE_DEPTH - 1][MAX_INCLUDE_PATH - 1] = '\0';
                load_file_into_program(include_path_store[MAX_INCLUDE_DEPTH - 1], get_base_dir(include_path_store[MAX_INCLUDE_DEPTH - 1]), include_depth + 1,
                    use_explicit_numbers, auto_line_no, first_line_seen);
                continue;
            }
            fprintf(stderr, "Unknown directive: #%.*s\n", 60, p);
            exit(1);
        }

        *first_line_seen = 1;

        if (*use_explicit_numbers == -1) {
            *use_explicit_numbers = isdigit((unsigned char)*p) ? 1 : 0;
        }

        if (*use_explicit_numbers == 1) {
            char *transformed;
            if (!isdigit((unsigned char)*p)) {
                fprintf(stderr, "Line missing number: %s\n", linebuf);
                exit(1);
            }
            number = atoi(p);
            while (*p && !isspace((unsigned char)*p)) p++;
            while (*p == ' ' || *p == '\t') p++;
            transformed = transform_basic_line(p);
            {
                char *normalized = normalize_keywords_line(transformed);
                if (include_depth > 0) add_line_from_include(number, normalized);
                else add_or_replace_line(number, normalized);
                free(normalized);
            }
            free(transformed);
        } else {
            if (isdigit((unsigned char)*p)) {
                fprintf(stderr, "Mixed numbered and numberless lines are not supported: %s\n", linebuf);
                exit(1);
            }
            number = *auto_line_no;
            *auto_line_no += 10;
            {
                char *transformed = transform_basic_line(p);
                char *normalized = normalize_keywords_line(transformed);
                add_or_replace_line(number, normalized);
                free(normalized);
                free(transformed);
            }
        }
    }
    fclose(f);
    loading_count--;
}

static void load_program(const char *path)
{
    int auto_line_no = 10;
    int use_explicit_numbers = -1;
    int first_line_seen = 0;
    const char *base_dir = get_base_dir(path);

    load_file_into_program(path, base_dir, 0,
        &use_explicit_numbers, &auto_line_no, &first_line_seen);

    sort_program();
    collect_data_from_program();
    build_label_table();
    build_udf_table();
}

static void run_program(const char *script_path_arg, int nargs, char **args)
{
    script_path = script_path_arg;
    script_argc = nargs;
    script_argv = args;
    halted = 0;
    current_line = 0;
    statement_pos = NULL;
    print_col = 0;
    for_top = 0;
    while_top = 0;
    do_top = 0;
    if_depth = 0;
    while (!halted && current_line >= 0 && current_line < line_count) {
        char *p;
        if (statement_pos == NULL) {
            statement_pos = program_lines[current_line]->text;
        }
        p = statement_pos;
        skip_spaces(&p);
        if (*p == '\0') {
            current_line++;
            statement_pos = NULL;
            continue;
        }
        statement_pos = p;
        execute_statement(&statement_pos);
        if (halted) {
            break;
        }
        if (statement_pos == NULL) {
            continue;
        }
        skip_spaces(&statement_pos);
        if (*statement_pos == ':') {
            statement_pos++;
            continue;
        }
        skip_spaces(&statement_pos);
        if (*statement_pos == '\0') {
            current_line++;
            statement_pos = NULL;
        }
    }
    /* Close any files left open when program ends. */
    {
        int lfn;
        for (lfn = 1; lfn < 256; lfn++) {
            if (open_files[lfn]) {
                fclose(open_files[lfn]);
                open_files[lfn] = NULL;
            }
        }
    }
}

/* ── Public API for gfx builds ──────────────────────────────────── */

int basic_parse_args(int argc, char **argv)
{
    int i;
    init_console_ansi();
    for (i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-petscii") == 0 || strcmp(argv[i], "--petscii") == 0) {
            petscii_mode = 1;
            petscii_plain = 0;
            petscii_no_wrap = 1;
        } else if (strcmp(argv[i], "-petscii-plain") == 0 || strcmp(argv[i], "--petscii-plain") == 0) {
            petscii_mode = 1;
            petscii_plain = 1;
            petscii_no_wrap = 1;
        } else if (strcmp(argv[i], "-charset") == 0) {
            const char *name;
            if (i + 1 >= argc) {
                fprintf(stderr, "Missing value for -charset\n");
                return -1;
            }
            name = argv[++i];
            if (strcmp(name, "upper") == 0 || strcmp(name, "uc") == 0 || strcmp(name, "upper-graphics") == 0) {
                petscii_lowercase_opt = 0;
                petscii_set_lowercase(0);
            } else if (strcmp(name, "lower") == 0 || strcmp(name, "lc") == 0 || strcmp(name, "lowercase") == 0) {
                petscii_lowercase_opt = 1;
                petscii_set_lowercase(1);
            } else {
                fprintf(stderr, "Unknown charset '%s' (expected upper or lower)\n", name);
                return -1;
            }
        } else if (strcmp(argv[i], "-palette") == 0) {
            const char *name;
            if (i + 1 >= argc) {
                fprintf(stderr, "Missing value for -palette\n");
                return -1;
            }
            name = argv[++i];
            if (strcmp(name, "ansi") == 0) {
                palette_mode = PALETTE_ANSI;
            } else if (strcmp(name, "c64") == 0 || strcmp(name, "c64-8bit") == 0) {
                palette_mode = PALETTE_C64_8BIT;
            } else {
                fprintf(stderr, "Unknown palette '%s' (expected ansi or c64)\n", name);
                return -1;
            }
        } else if (argv[i][0] == '-') {
            fprintf(stderr, "Unknown option: %s\n", argv[i]);
            return -1;
        } else {
            return i;   /* index of the .bas path */
        }
    }
    return -1;  /* no program path found */
}

void basic_load(const char *path) { load_program(path); }

void basic_run(const char *script_path_arg, int nargs, char **args)
{
    run_program(script_path_arg, nargs, args);
}

int basic_halted(void) { return halted; }

#ifdef GFX_VIDEO
void basic_set_video(GfxVideoState *vs) { gfx_vs = vs; }
#endif

/* ── Terminal-mode entry point (not used when GFX_VIDEO is defined) ── */

#ifndef GFX_VIDEO
int main(int argc, char **argv)
{
    const char *prog_path = NULL;
    int i;

    /* Initialize console so ANSI colors/control codes behave consistently. */
    init_console_ansi();

    if (argc < 2) {
        fprintf(stderr, "Usage: %s [-petscii] [-petscii-plain] [-charset upper|lower] [-palette ansi|c64] <program.bas>\n", argv[0]);
        return 1;
    }

    for (i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-petscii") == 0 || strcmp(argv[i], "--petscii") == 0) {
            petscii_mode = 1;
            petscii_plain = 0;
            /* Disable our column-based wrap in PETSCII mode: many Unicode block/symbol
             * glyphs are "ambiguous" width (1 or 2 cols) so our count doesn't match
             * the terminal. Let the terminal wrap at its width to avoid misalignment. */
            petscii_no_wrap = 1;
        } else if (strcmp(argv[i], "-petscii-plain") == 0 || strcmp(argv[i], "--petscii-plain") == 0) {
            petscii_mode = 1;
            petscii_plain = 1;
            petscii_no_wrap = 1;
        } else if (strcmp(argv[i], "-charset") == 0) {
            const char *name;
            if (i + 1 >= argc) {
                fprintf(stderr, "Missing value for -charset\n");
                return 1;
            }
            name = argv[++i];
            if (strcmp(name, "upper") == 0 || strcmp(name, "uc") == 0 || strcmp(name, "upper-graphics") == 0) {
                petscii_lowercase_opt = 0;
                petscii_set_lowercase(0);
            } else if (strcmp(name, "lower") == 0 || strcmp(name, "lc") == 0 || strcmp(name, "lowercase") == 0) {
                petscii_lowercase_opt = 1;
                petscii_set_lowercase(1);
            } else {
                fprintf(stderr, "Unknown charset '%s' (expected upper or lower)\n", name);
                return 1;
            }
        } else if (strcmp(argv[i], "-palette") == 0) {
            const char *name;
            if (i + 1 >= argc) {
                fprintf(stderr, "Missing value for -palette\n");
                return 1;
            }
            name = argv[++i];
            if (strcmp(name, "ansi") == 0) {
                palette_mode = PALETTE_ANSI;
            } else if (strcmp(name, "c64") == 0 || strcmp(name, "c64-8bit") == 0) {
                palette_mode = PALETTE_C64_8BIT;
            } else {
                fprintf(stderr, "Unknown palette '%s' (expected ansi or c64)\n", name);
                return 1;
            }
        } else if (argv[i][0] == '-') {
            fprintf(stderr, "Unknown option: %s\n", argv[i]);
            fprintf(stderr, "Usage: %s [-petscii] [-petscii-plain] [-charset upper|lower] [-palette ansi|c64] <program.bas>\n", argv[0]);
            return 1;
        } else {
            prog_path = argv[i];
            break;
        }
    }

    if (!prog_path) {
        fprintf(stderr, "Usage: %s [-petscii] [-petscii-plain] [-charset upper|lower] [-palette ansi|c64] <program.bas>\n", argv[0]);
        return 1;
    }

    load_program(prog_path);
    run_program(prog_path, argc - (i + 1), (argc > (i + 1)) ? (argv + (i + 1)) : NULL);
    return 0;
}
#endif /* !GFX_VIDEO */
