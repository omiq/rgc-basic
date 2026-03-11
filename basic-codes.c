#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

typedef struct {
    char *buf;
    size_t len;
    size_t cap;
} StrBuf;

typedef struct {
    const char *name;
    int code;
} TokenMap;

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

static void sb_init(StrBuf *sb) {
    sb->cap = 256;
    sb->len = 0;
    sb->buf = malloc(sb->cap);
    if (!sb->buf) {
        fprintf(stderr, "Out of memory\n");
        exit(1);
    }
    sb->buf[0] = '\0';
}

static void sb_reserve(StrBuf *sb, size_t extra) {
    if (sb->len + extra + 1 <= sb->cap) {
        return;
    }
    while (sb->len + extra + 1 > sb->cap) {
        sb->cap *= 2;
    }
    char *newbuf = realloc(sb->buf, sb->cap);
    if (!newbuf) {
        free(sb->buf);
        fprintf(stderr, "Out of memory\n");
        exit(1);
    }
    sb->buf = newbuf;
}

static void sb_append_char(StrBuf *sb, char c) {
    sb_reserve(sb, 1);
    sb->buf[sb->len++] = c;
    sb->buf[sb->len] = '\0';
}

static void sb_append_mem(StrBuf *sb, const char *s, size_t n) {
    sb_reserve(sb, n);
    memcpy(sb->buf + sb->len, s, n);
    sb->len += n;
    sb->buf[sb->len] = '\0';
}

static void sb_append_str(StrBuf *sb, const char *s) {
    sb_append_mem(sb, s, strlen(s));
}

static char *dup_upper_trim(const char *src, size_t len) {
    while (len > 0 && isspace((unsigned char)*src)) {
        src++;
        len--;
    }
    while (len > 0 && isspace((unsigned char)src[len - 1])) {
        len--;
    }

    char *out = malloc(len + 1);
    if (!out) {
        fprintf(stderr, "Out of memory\n");
        exit(1);
    }

    for (size_t i = 0; i < len; i++) {
        out[i] = (char)toupper((unsigned char)src[i]);
    }
    out[len] = '\0';
    return out;
}

static int lookup_token_code(const char *token, int *code_out) {
    char *endptr = NULL;
    long n = strtol(token, &endptr, 10);

    if (*token != '\0' && *endptr == '\0') {
        if (n >= 0 && n <= 255) {
            *code_out = (int)n;
            return 1;
        }
        return 0;
    }

    for (int i = 0; token_map[i].name != NULL; i++) {
        if (strcmp(token, token_map[i].name) == 0) {
            *code_out = token_map[i].code;
            return 1;
        }
    }

    return 0;
}

static void append_quoted(StrBuf *out, const char *text, size_t len) {
    sb_append_char(out, '"');
    sb_append_mem(out, text, len);
    sb_append_char(out, '"');
}

char *transform_basic_line(const char *input) {
    StrBuf out;
    sb_init(&out);

    int in_string = 0;
    const char *segment_start = NULL;
    int piece_count = 0;

    for (size_t i = 0; input[i] != '\0'; i++) {
        char c = input[i];

        if (!in_string) {
            if (c == '"') {
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
                            sb_append_char(&out, ';');
                        }
                        append_quoted(&out, segment_start, seg_len);
                        piece_count++;
                    }

                    if (piece_count > 0) {
                        sb_append_char(&out, ';');
                    }

                    char tmp[32];
                    snprintf(tmp, sizeof(tmp), "CHR$(%d)", code);
                    sb_append_str(&out, tmp);
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

        if (c == '"') {
            size_t seg_len = (size_t)((input + i) - segment_start);

            if (seg_len > 0 || piece_count == 0) {
                if (piece_count > 0) {
                    sb_append_char(&out, ';');
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
        sb_append_char(&out, '"');
        if (segment_start) {
            sb_append_str(&out, segment_start);
        }
    }

    return out.buf;
}

static void usage(const char *progname) {
    fprintf(stderr, "Usage: %s inputfile.bas\n", progname);
}

int main(int argc, char **argv) {
    if (argc != 2) {
        usage(argv[0]);
        return 1;
    }

    const char *filename = argv[1];
    FILE *fp = fopen(filename, "r");
    if (!fp) {
        perror(filename);
        return 1;
    }

    char line[8192];

    while (fgets(line, sizeof(line), fp)) {
        char *out = transform_basic_line(line);
        fputs(out, stdout);
        free(out);
    }

    if (ferror(fp)) {
        perror("Error reading input");
        fclose(fp);
        return 1;
    }

    fclose(fp);
    return 0;
}