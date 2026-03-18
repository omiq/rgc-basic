#ifndef PETSCII_H
#define PETSCII_H

/* Map a PETSCII code (0–255) to a UTF-8 string for terminal display.
 * Used when -petscii or -petscii-plain is set. Faithful Unicode: £ ↑ ←, box-drawing,
 * block elements, card suits, π, and Symbols for Legacy Computing where applicable. */
const char *petscii_code_to_utf8(unsigned char c);

/* Select C64-style character set rendering for PETSCII letters.
 * 0 = uppercase/graphics (default), 1 = lowercase/uppercase. */
void petscii_set_lowercase(int enabled);
int petscii_get_lowercase(void);

#endif
