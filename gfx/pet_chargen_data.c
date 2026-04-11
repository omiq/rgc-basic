/* Commodore PET 2K character ROM (901447-10, Steve Gray / cbmsteve.ca).
 * Two 128×8 banks: $000–$3FF “graphics/uppercase”, $400–$7FF “text/lowercase”. */
#include <stdint.h>

const uint8_t pet_chargen_901447_10m[2048] = {
#include "pet_chargen_901447_10m.inc"
};
