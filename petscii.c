/*
 * PETSCII code point → UTF-8 for terminal display (-petscii mode).
 * Faithful Unicode mapping (Kreative Korp / C64 style): £ ↑ ←, box-drawing,
 * block elements, card suits ♠♥♦♣, π, and Symbols for Legacy Computing where applicable.
 */

#include "petscii.h"

/* C64 has two ROM character sets:
 * - uppercase/graphics (default)
 * - lowercase/uppercase (shifted)
 *
 * When lowercase charset is enabled we render:
 * - 0x41-0x5A as 'a'-'z'
 * - 0x61-0x7A as 'A'-'Z'
 * Everything else uses the faithful Unicode mapping table.
 */
static int petscii_lowercase_charset = 0;

static const char *petscii_to_utf8[256] = {
    /* 0x00 - 0x1F: control (output suppressed in basic.c; table fallback) */
    " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", "\n", " ", " ", "\r", " ", " ",
    " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ",
    /* 0x20 - 0x2F */
    " ", "!", "\"", "#", "$", "%", "&", "'", "(", ")", "*", "+", ",", "-", ".", "/",
    /* 0x30 - 0x3F */
    "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", ":", ";", "<", "=", ">", "?",
    /* 0x40 - 0x5F: @ A-Z [ £ ] ↑ ← */
    "@", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O",
    "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "[", "\u00A3", "]", "\u2191", "\u2190",
    /* 0x60 - 0x7F: graphics (horizontal, spade, block elements, box-drawing, card suits, π, etc.) */
    "\u2500", "\u2660", "\U0001FB72", "\U0001FB78", "\U0001FB77", "\U0001FB76", "\U0001FB7A", "\U0001FB71",
    "\U0001FB74", "\u256E", "\u2570", "\u256F", "\U0001FB7C", "\u2572", "\u2571", "\U0001FB7D",
    "\U0001FB7E", "\u2022", "\U0001FB7B", "\u2665", "\U0001FB70", "\u256D", "\u2573", "\u25CB",
    "\u2663", "\U0001FB75", "\u2666", "\u253C", "\U0001FB8C", "\u2502", "\u03C0", "\u25E5",
    /* 0x80 - 0x9F: control (output suppressed in basic.c) */
    " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ",
    " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ",
    /* 0xA0 - 0xBF: block elements, box-drawing, quadrants */
    "\u00A0", "\u258C", "\u2584", "\u2594", "\u2581", "\u258F", "\u2592", "\u2595",
    "\U0001FB8F", "\u25E4", "\U0001FB87", "\u251C", "\u2597", "\u2514", "\u2510", "\u2582",
    "\u250C", "\u2534", "\u252C", "\u2524", "\u258E", "\u258D", "\U0001FB88", "\U0001FB82",
    "\U0001FB83", "\u2583", "\U0001FB7F", "\u2596", "\u259D", "\u2518", "\u2598", "\u259A",
    /* 0xC0 - 0xDF: same graphics as 0x60-0x7F (C64 uppercase/graphics) */
    "\u2500", "\u2660", "\U0001FB72", "\U0001FB78", "\U0001FB77", "\U0001FB76", "\U0001FB7A", "\U0001FB71",
    "\U0001FB74", "\u256E", "\u2570", "\u256F", "\U0001FB7C", "\u2572", "\u2571", "\U0001FB7D",
    "\U0001FB7E", "\u2022", "\U0001FB7B", "\u2665", "\U0001FB70", "\u256D", "\u2573", "\u25CB",
    "\u2663", "\U0001FB75", "\u2666", "\u253C", "\U0001FB8C", "\u2502", "\u03C0", "\u25E5",
    /* 0xE0 - 0xFF: same block elements as 0xA0-0xBF */
    "\u00A0", "\u258C", "\u2584", "\u2594", "\u2581", "\u258F", "\u2592", "\u2595",
    "\U0001FB8F", "\u25E4", "\U0001FB87", "\u251C", "\u2597", "\u2514", "\u2510", "\u2582",
    "\u250C", "\u2534", "\u252C", "\u2524", "\u258E", "\u258D", "\U0001FB88", "\U0001FB82",
    "\U0001FB83", "\u2583", "\U0001FB7F", "\u2596", "\u259D", "\u2518", "\u2598", "\u259A"
};

const char *petscii_code_to_utf8(unsigned char c)
{
    if (petscii_lowercase_charset) {
        if (c >= 0x41 && c <= 0x5A) {
            static char buf[2];
            buf[0] = (char)('a' + (c - 0x41));
            buf[1] = '\0';
            return buf;
        }
        if (c >= 0x61 && c <= 0x7A) {
            static char buf[2];
            buf[0] = (char)('A' + (c - 0x61));
            buf[1] = '\0';
            return buf;
        }
    }
    return petscii_to_utf8[c];
}

void petscii_set_lowercase(int enabled)
{
    petscii_lowercase_charset = enabled ? 1 : 0;
}

int petscii_get_lowercase(void)
{
    return petscii_lowercase_charset;
}
