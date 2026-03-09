/*
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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <math.h>
#if defined(_WIN32)
#include <windows.h>
#else
#if defined(__unix__) || defined(__APPLE__) || defined(__MACH__)
#include <unistd.h>
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

/* 211BSD-friendly BASIC interpreter targeting CBM BASIC v2 style programs.
 * Implements a minimal but compatible feature set: line-numbered programs,
 * PRINT/INPUT/LET (implicit), IF/THEN, GOTO, GOSUB/RETURN, FOR/NEXT, DIM,
 * REM, END/STOP and statement separators (:). */

#define MAX_LINES 1024
#define MAX_LINE_LEN 256
#define MAX_VARS 128
#define MAX_GOSUB 64
#define MAX_FOR 32
#define MAX_STR_LEN 256
#define DEFAULT_ARRAY_SIZE 11
#define PRINT_WIDTH 80
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

struct var {
    char name1;
    char name2;
    int is_string;
    int is_array;
    int size;
    struct value scalar;
    struct value *array;
};

struct gosub_frame {
    int line_index;
    char *position;
};

struct for_frame {
    char name1;
    char name2;
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

static int current_line = 0;
static char *statement_pos = NULL;
static int halted = 0;
static int print_col = 0;

static void runtime_error(const char *msg);
static void load_program(const char *path);
static int find_line_index(int number);
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
static struct var *find_or_create_var(char name1, char name2, int is_string, int want_array, int array_size);
static struct value eval_function(const char *name, char **p);
static int user_func_lookup(const char *name);
static void collect_data_from_program(void);
static void statement_read(char **p);
static void print_value(struct value *v);
static void print_spaces(int count);
static void statement_sleep(char **p);
static void statement_def(char **p);
static void do_sleep_ticks(double ticks);
static int function_lookup(const char *name, int len);

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
    FN_SPC = 17
};

/* Report an error and halt further execution. */
static void runtime_error(const char *msg)
{
    int line_no;
    line_no = 0;
    if (current_line >= 0 && current_line < line_count &&
        program_lines[current_line] != NULL) {
        line_no = program_lines[current_line]->number;
    }
    if (line_no > 0) {
        fprintf(stderr, "Error on line %d: %s\n", line_no, msg);
    } else {
        fprintf(stderr, "Error: %s\n", msg);
    }
    halted = 1;
}

/* Strip trailing newline from a buffer if present. */
static void trim_newline(char *s)
{
    char *p;
    p = strchr(s, '\n');
    if (p) {
        *p = '\0';
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

/* Check if the input starts with the keyword (case-insensitive). */
static int starts_with_kw(char *p, const char *kw)
{
    int i;
    for (i = 0; kw[i]; i++) {
        if (toupper((unsigned char)p[i]) != kw[i]) {
            return 0;
        }
    }
    if (p[i] == '\0' || p[i] == ' ' || p[i] == '\t' || p[i] == ':' || p[i] == '(') {
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

/* Ensure the value is string or raise a runtime error. */
static void ensure_str(struct value *v)
{
    if (v->type != VAL_STR) {
        runtime_error("String value required");
    }
}

/* Emit spaces and track current print column. */
static void print_spaces(int count)
{
    int i;
    for (i = 0; i < count; i++) {
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
            fputc(*s, stdout);
            if (*s == '\n') {
                print_col = 0;
            } else {
                print_col++;
                if (print_col >= PRINT_WIDTH) {
                    fputc('\n', stdout);
                    print_col = 0;
                }
            }
            s++;
        }
    } else {
        char buf[64];
        sprintf(buf, "%g", v->num);
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
        return FN_NONE;
    case 'I':
        if (len == 3 && name[0] == 'I' && name[1] == 'N' && name[2] == 'T') return FN_INT;
        return FN_NONE;
    case 'E':
        if (len == 3 && name[0] == 'E' && name[1] == 'X' && name[2] == 'P') return FN_EXP;
        return FN_NONE;
    case 'L':
        if (len == 3 && name[0] == 'L' && name[1] == 'O' && name[2] == 'G') return FN_LOG;
        if (len == 3 && name[0] == 'L' && name[1] == 'E' && name[2] == 'N') return FN_LEN;
        return FN_NONE;
    case 'R':
        if (len == 3 && name[0] == 'R' && name[1] == 'N' && name[2] == 'D') return FN_RND;
        return FN_NONE;
    case 'V':
        if (len == 3 && name[0] == 'V' && name[1] == 'A' && name[2] == 'L') return FN_VAL;
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
/* POSIX/Unix: original usleep/select-based implementation for 60Hz ticks. */
static void do_sleep_ticks(double ticks)
{
    long usec;
    unsigned int sec;
#ifndef HAVE_USLEEP
    long start;
    long target_ticks;
    int tps;
    struct tms tm;
    double remaining_ticks;
#endif
    if (ticks <= 0.0) {
        return;
    }
    usec = (long)(ticks * (1000000.0 / 60.0) + 0.5);
    if (usec <= 0) {
        return;
    }
    sec = (unsigned int)(usec / 1000000L);
    usec = usec % 1000000L;
#ifdef HAVE_USLEEP
    if (sec > 0) {
        sleep(sec);
    }
    if (usec > 0) {
        usleep((unsigned int)usec);
    }
#else
    /* No usleep; use select() for sub-second delay if available */
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
#endif
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
    arg = eval_expr(p);
    skip_spaces(p);
    if (**p == ')') {
        (*p)++;
    } else {
        runtime_error("Missing ')'");
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
            srand((unsigned int)(-arg.num));
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
        outbuf[0] = (char)((int)arg.num & 0xff);
        outbuf[1] = '\0';
        return make_str(outbuf);
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
    default:
        runtime_error("Unknown function");
        return make_num(0.0);
    }
}

/* Break a BASIC variable name into two-letter uppercase key and detect strings. */
static void uppercase_name(const char *src, char *n1, char *n2, int *is_string)
{
    int len;
    len = (int)strlen(src);
    *is_string = 0;
    if (len > 0 && src[len - 1] == '$') {
        *is_string = 1;
        len--;
    }
    if (len < 1) {
        *n1 = ' ';
        *n2 = ' ';
        return;
    }
    *n1 = toupper((unsigned char)src[0]);
    if (len > 1) {
        *n2 = toupper((unsigned char)src[1]);
    } else {
        *n2 = ' ';
    }
}

static struct var *find_or_create_var(char name1, char name2, int is_string, int want_array, int array_size)
{
    int i, idx;
    struct var *v;
    for (i = 0; i < var_count; i++) {
        if (vars[i].name1 == name1 && vars[i].name2 == name2 && vars[i].is_string == is_string) {
            v = &vars[i];
            if (want_array && !v->is_array) {
                v->is_array = 1;
                v->size = array_size;
                v->array = (struct value *)calloc(array_size, sizeof(struct value));
                if (!v->array) {
                    runtime_error("Out of memory");
                    return v;
                }
            } else if (want_array && array_size > v->size) {
                /* Resize array when needed */
                struct value *new_arr;
                new_arr = (struct value *)realloc(v->array, array_size * sizeof(struct value));
                if (new_arr) {
                    v->array = new_arr;
                    v->size = array_size;
                } else {
                    runtime_error("Out of memory");
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
    v->name1 = name1;
    v->name2 = name2;
    v->is_string = is_string;
    v->is_array = want_array;
    v->size = want_array ? array_size : 0;
    v->array = NULL;
    v->scalar = make_num(0.0);
    if (is_string) {
        v->scalar = make_str("");
    }
    if (want_array) {
        v->array = (struct value *)calloc(array_size, sizeof(struct value));
        if (!v->array) {
            runtime_error("Out of memory");
        }
    }
    return v;
}

/* Read an identifier (letters/digits/$) into buf, advancing the pointer. */
static int read_identifier(char **p, char *buf, int buf_size)
{
    int i;
    i = 0;
    while ((isalpha((unsigned char)(**p)) || isdigit((unsigned char)(**p)) || **p == '$') && i < buf_size - 1) {
        buf[i++] = **p;
        (*p)++;
    }
    buf[i] = '\0';
    return i;
}

/* Resolve a variable (and optional array index) creating it if needed. */
static struct value *get_var_reference(char **p, int *is_array_out, int *is_string_out)
{
    char namebuf[8];
    char n1, n2;
    int is_string;
    struct var *v;
    struct value *valp;
    int is_array;
    int array_size;
    int array_index;
    struct value idx_val;

    skip_spaces(p);
    if (!isalpha((unsigned char)**p)) {
        runtime_error("Expected variable");
        return NULL;
    }
    read_identifier(p, namebuf, sizeof(namebuf));
    uppercase_name(namebuf, &n1, &n2, &is_string);
    if (is_string_out) {
        *is_string_out = is_string;
    }
    skip_spaces(p);
    is_array = 0;
    array_size = 0;
    array_index = -1;
    if (**p == '(') {
        is_array = 1;
        (*p)++;
        idx_val = eval_expr(p);
        ensure_num(&idx_val);
        skip_spaces(p);
        if (**p != ')') {
            runtime_error("Missing ')'");
            return NULL;
        }
        (*p)++;
        array_index = (int)(idx_val.num + 0.00001);
        if (array_index < 0) {
            runtime_error("Negative array index");
            return NULL;
        }
        array_size = array_index + 1;
        if (array_size < DEFAULT_ARRAY_SIZE) {
            array_size = DEFAULT_ARRAY_SIZE;
        }
    }
    if (is_array_out) {
        *is_array_out = is_array;
    }
    v = find_or_create_var(n1, n2, is_string, is_array, is_array ? array_size : 0);
    if (!v) {
        return NULL;
    }
    if (!is_array) {
        valp = &v->scalar;
    } else {
        if (array_index >= v->size) {
            struct value *new_arr;
            new_arr = (struct value *)realloc(v->array, (array_index + 1) * sizeof(struct value));
            if (!new_arr) {
                runtime_error("Out of memory");
                return NULL;
            }
            memset(new_arr + v->size, 0, (array_index + 1 - v->size) * sizeof(struct value));
            v->array = new_arr;
            v->size = array_index + 1;
        }
        valp = &v->array[array_index];
    }
    if (is_string && valp->type != VAL_STR) {
        *valp = make_str("");
    } else if (!is_string && valp->type != VAL_NUM) {
        *valp = make_num(0.0);
    }
    return valp;
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
    /* Function call? */
    if (starts_with_kw(*p, "SIN") || starts_with_kw(*p, "COS") || starts_with_kw(*p, "TAN") ||
            starts_with_kw(*p, "ABS") || starts_with_kw(*p, "INT") || starts_with_kw(*p, "SQR") ||
            starts_with_kw(*p, "SGN") || starts_with_kw(*p, "EXP") || starts_with_kw(*p, "LOG") ||
            starts_with_kw(*p, "RND") || starts_with_kw(*p, "LEN") || starts_with_kw(*p, "VAL") ||
            starts_with_kw(*p, "STR") || starts_with_kw(*p, "CHR") || starts_with_kw(*p, "ASC") ||
            starts_with_kw(*p, "TAB") || starts_with_kw(*p, "SPC")) {
            char namebuf[8];
            char *q;
            q = *p;
            read_identifier(&q, namebuf, sizeof(namebuf));
            return eval_function(namebuf, p);
        } else {
            /* Check for user-defined DEF FN function call */
            char namebuf[8];
            char *q;
            int i;
            int uf_index;
            q = *p;
            read_identifier(&q, namebuf, sizeof(namebuf));
            for (i = 0; namebuf[i]; i++) {
                namebuf[i] = (char)toupper((unsigned char)namebuf[i]);
            }
            uf_index = user_func_lookup(namebuf);
            if (uf_index >= 0) {
                struct user_func *uf;
                struct value arg;
                struct value result;
                struct var *param_var;
                struct value saved_scalar;
                char pname_buf[8];
                char n1, n2;
                int dummy_is_string;

                uf = &user_funcs[uf_index];

                /* Advance original pointer past function name */
                *p = q;
                skip_spaces(p);
                if (**p != '(') {
                    runtime_error("Function requires '('");
                    return make_num(0.0);
                }
                (*p)++;
                arg = eval_expr(p);
                skip_spaces(p);
                if (**p == ')') {
                    (*p)++;
                } else {
                    runtime_error("Missing ')'");
                }

                /* Bind parameter variable, evaluate body, then restore */
                strncpy(pname_buf, uf->param_name, sizeof(pname_buf) - 1);
                pname_buf[sizeof(pname_buf) - 1] = '\0';
                uppercase_name(pname_buf, &n1, &n2, &dummy_is_string);
                param_var = find_or_create_var(n1, n2, uf->param_is_string, 0, 0);
                if (!param_var) {
                    return make_num(0.0);
                }
                saved_scalar = param_var->scalar;
                if (uf->param_is_string) {
                    ensure_str(&arg);
                    param_var->scalar = arg;
                    param_var->scalar.type = VAL_STR;
                } else {
                    ensure_num(&arg);
                    param_var->scalar = arg;
                    param_var->scalar.type = VAL_NUM;
                }

                {
                    char *body_p;
                    body_p = uf->body;
                    result = eval_expr(&body_p);
                }

                param_var->scalar = saved_scalar;
                return result;
            } else {
                struct value *vp;
                vp = get_var_reference(p, NULL, NULL);
                if (!vp) {
                    return make_num(0.0);
                }
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
static int eval_condition(char **p)
{
    struct value left, right;
    int result;
    char op1, op2;
    skip_spaces(p);
    left = eval_expr(p);
    skip_spaces(p);
    op1 = **p;
    op2 = *(*p + 1);
    result = 0;
    if (op1 == '<' && op2 == '>') {
        *p += 2;
        right = eval_expr(p);
        if (left.type == VAL_STR || right.type == VAL_STR) {
            ensure_str(&left);
            ensure_str(&right);
            result = strcmp(left.str, right.str) != 0;
        } else {
            result = left.num != right.num;
        }
        return result;
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
    if (left.type == VAL_STR) {
        ensure_str(&left);
        return strlen(left.str) > 0;
    }
    return left.num != 0.0;
}

/* Skip rest of line (REM or ' comment). */
static void statement_rem(char **p)
{
    *p += strlen(*p);
}

static void statement_print(char **p)
{
    int newline;
    struct value v;
    newline = 1;
    for (;;) {
        skip_spaces(p);
        if (**p == '\0' || **p == ':') {
            break;
        }
        v = eval_expr(p);
        print_value(&v);
        skip_spaces(p);
        if (**p == ';') {
            newline = 0;
            (*p)++;
        } else if (**p == ',') {
            newline = 0;
            {
                int zone;
                int nextcol;
                zone = 10;
                nextcol = ((print_col / zone) + 1) * zone;
                if (nextcol < print_col) {
                    nextcol = print_col;
                }
                print_spaces(nextcol - print_col);
            }
            (*p)++;
        } else {
            newline = 1;
            break;
        }
    }
    if (newline) {
        fputc('\n', stdout);
        print_col = 0;
    }
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
    int line_number;
    skip_spaces(p);
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
}

static void statement_gosub(char **p)
{
    int target;
    char *return_pos;

    if (gosub_top >= MAX_GOSUB) {
        runtime_error("GOSUB stack overflow");
        return;
    }
    skip_spaces(p);
    target = atoi(*p);
    while (**p && isdigit((unsigned char)**p)) {
        (*p)++;
    }
    return_pos = *p;
    gosub_stack[gosub_top].line_index = current_line;
    gosub_stack[gosub_top].position = return_pos;
    gosub_top++;
    current_line = find_line_index(target);
    if (current_line < 0) {
        runtime_error("Target line not found");
        return;
    }
    statement_pos = NULL;
}

static void statement_return(char **p)
{
    if (gosub_top <= 0) {
        runtime_error("RETURN without GOSUB");
        return;
    }
    gosub_top--;
    current_line = gosub_stack[gosub_top].line_index;
    statement_pos = gosub_stack[gosub_top].position;
}

static void statement_if(char **p)
{
    int cond_true;

    cond_true = eval_condition(p);
    skip_spaces(p);
    if (!starts_with_kw(*p, "THEN")) {
        runtime_error("Missing THEN");
        return;
    }
    *p += 4;
    skip_spaces(p);
    if (!cond_true) {
        /* Skip rest of line */
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
        /* Execute rest of line inline */
        skip_spaces(p);
        statement_pos = *p;
    }
}

static void statement_for(char **p)
{
    struct value *vp;
    struct value startv, endv, stepv;
    int is_array;
    int is_string;
    if (for_top >= MAX_FOR) {
        runtime_error("FOR stack overflow");
        return;
    }
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
    for_stack[for_top].name1 = ' ';
    for_stack[for_top].name2 = ' ';
    if (var_count > 0) {
        /* Recover name from vp by searching var table */
        int i;
        for (i = 0; i < var_count; i++) {
            if (&vars[i].scalar == vp || (vars[i].is_array && vp >= vars[i].array && vp < vars[i].array + vars[i].size)) {
                for_stack[for_top].name1 = vars[i].name1;
                for_stack[for_top].name2 = vars[i].name2;
                break;
            }
        }
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
    char namebuf[8];
    char n1, n2;
    int i;
    struct value *vp;
    int is_string;
    skip_spaces(p);
    if (isalpha((unsigned char)**p)) {
        read_identifier(p, namebuf, sizeof(namebuf));
    } else {
        namebuf[0] = '\0';
    }
    uppercase_name(namebuf, &n1, &n2, &is_string);
    for (i = for_top - 1; i >= 0; i--) {
        if (namebuf[0] == '\0' || (for_stack[i].name1 == n1 && for_stack[i].name2 == n2)) {
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
        char namebuf[8];
        char n1, n2;
        int is_string;
        int size;
        struct var *v;
        struct value sizev;
        skip_spaces(p);
        if (!isalpha((unsigned char)**p)) {
            runtime_error("Expected array name");
            return;
        }
        read_identifier(p, namebuf, sizeof(namebuf));
        uppercase_name(namebuf, &n1, &n2, &is_string);
        skip_spaces(p);
        if (**p != '(') {
            runtime_error("DIM requires size");
            return;
        }
        (*p)++;
        sizev = eval_expr(p);
        ensure_num(&sizev);
        size = (int)sizev.num + 1;
        if (size <= 0) {
            runtime_error("Invalid array size");
            return;
        }
        skip_spaces(p);
        if (**p != ')') {
            runtime_error("Missing ')'");
            return;
        }
        (*p)++;
        v = find_or_create_var(n1, n2, is_string, 1, size);
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
    }
    if (c == 'P') {
        if (starts_with_kw(*p, "PRINT")) {
            *p += 5;
            statement_print(p);
            return;
        }
        /* POKE is treated as a no-op (for compatibility with demos). */
        if (starts_with_kw(*p, "POKE")) {
            *p += 4;
            /* Skip the rest of the arguments */
            *p += strlen(*p);
            return;
        }
    }
    if (c == 'I' && starts_with_kw(*p, "INPUT")) {
        *p += 5;
        statement_input(p);
        return;
    }
    if (c == 'L' && starts_with_kw(*p, "LET")) {
        *p += 3;
        statement_let(p);
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
    if (c == 'D') {
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
    if (c == 'E' && starts_with_kw(*p, "END")) {
        halted = 1;
        *p += strlen(*p);
        return;
    }
    if (c == 'S' && starts_with_kw(*p, "STOP")) {
        halted = 1;
        *p += strlen(*p);
        return;
    }
    if (isalpha((unsigned char)c)) {
        statement_let(p);
        return;
    }
    runtime_error("Unknown statement");
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

static void load_program(const char *path)
{
    FILE *f;
    char linebuf[MAX_LINE_LEN];
    f = fopen(path, "r");
    if (!f) {
        fprintf(stderr, "Cannot open %s\n", path);
        exit(1);
    }
    while (fgets(linebuf, sizeof(linebuf), f)) {
        char *p;
        int number;
        trim_newline(linebuf);
        p = linebuf;
        while (*p == ' ' || *p == '\t') {
            p++;
        }
        /* Skip UTF-8 BOM if present */
        if ((unsigned char)p[0] == 0xef && (unsigned char)p[1] == 0xbb && (unsigned char)p[2] == 0xbf) {
            p += 3;
        }
        /* Ignore empty or whitespace-only lines */
        if (*p == '\0') {
            continue;
        }
        if (!isdigit((unsigned char)*p)) {
            fprintf(stderr, "Line missing number: %s\n", linebuf);
            exit(1);
        }
        number = atoi(p);
        while (*p && !isspace((unsigned char)*p)) {
            p++;
        }
        while (*p == ' ' || *p == '\t') {
            p++;
        }
        add_or_replace_line(number, p);
    }
    fclose(f);
    sort_program();
    collect_data_from_program();
}

static void run_program(void)
{
    halted = 0;
    current_line = 0;
    statement_pos = NULL;
    print_col = 0;
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
}

int main(int argc, char **argv)
{
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <program.bas>\n", argv[0]);
        return 1;
    }
    load_program(argv[1]);
    run_program();
    return 0;
}
