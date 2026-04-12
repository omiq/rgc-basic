/* Alternate PET-like glyph data for C64 screen-code layout (256×8), from
 * pet_uppercase.64c / pet_lowercase.64c at repo root (skip 2-byte header). */
#include <stdint.h>

const uint8_t pet_style_upper_rom[2048] = {
#include "pet_uppercase_64c.inc"
};

const uint8_t pet_style_lower_rom[2048] = {
#include "pet_lowercase_64c.inc"
};
