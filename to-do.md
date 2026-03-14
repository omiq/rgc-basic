# Features to add/to-do

Colour without pokes
  * background command for setting screen colour
  * colour/color for text colour

* Files (open get# print# close etc)

* PETSCII symbols
  * Unicode stand-ins
  * Bitmap rendering of 320x200 pixel or 40x25 characters (SDL? Raylib?)

* Subroutines and Functions
  * Syntax sugar before actual implementation?

* Program text preprocessor
  * Replace current ad-hoc whitespace tweaks with a small lexer-like pass for keywords and operators
  * Normalize compact CBM forms while preserving semantics, e.g.:
    * `IFX<0THEN` → `IF X<0 THEN`
    * `FORI=1TO9` → `FOR I=1 TO 9`
    * `GOTO410` / `GOSUB5400` → `GOTO 410` / `GOSUB 5400`
    * `IF Q1<1ORQ1>8ORQ2<1ORQ2>8 THEN` → proper spacing around `OR` and `AND`
  * Ensure keywords are only recognized when not inside identifiers (e.g. avoid splitting `ORD(7)` or `FOR`), and never mangling string literals
  * Validate behavior against reference interpreter (`cbmbasic`) with a regression suite of tricky lines

* Include files / libraries
  * Design a simple `INCLUDE "file.bas"` or similar directive processed at load time
  * Allow splitting larger programs into multiple source files / libraries while preserving line-numbered semantics
  * Consider search paths and guarding against recursive includes

---

**Completed (removed from list):**
- Multi-dimensional arrays — `DIM A(x,y)` (and up to 3 dimensions) in `basic.c`.
- **CLR statement** — Resets all variables (scalar and array elements) to 0/empty, clears GOSUB and FOR stacks, resets DATA pointer; DEF FN definitions are kept.
- **String case utilities** — `UCASE$(s)` and `LCASE$(s)` implemented (ASCII `toupper`/`tolower`); use in expressions and PRINT.

