#ifndef PETSCII_H
#define PETSCII_H

/* Map a PETSCII code (0–255) to a UTF-8 string for terminal display.
 * Used when -petscii is set so CHR$(n) shows C64-style glyphs. */
const char *petscii_code_to_utf8(unsigned char c);

#endif
