/*
 * rgc_real.h — portable "real number" type for transpiled RGC-BASIC.
 *
 * BASIC numeric values are floating point. Most retro C compilers have a
 * float library (cmoc, sdcc, vbcc), but cc65 (every 6502 target: C64, C128,
 * Apple II, Atari 8-bit, PET...) has NO float at all — it cannot even parse a
 * float literal. So this header lowers a single `rgc_real` type two ways:
 *
 *   - cc65    -> 16.16 signed fixed point in `long` (integer math only)
 *   - else    -> native `float`
 *
 * The transpiler emits the SAME RGC_* operations regardless of target; only
 * the backend differs. Speed is irrelevant for the turn-based text programs
 * this targets, so the fixed-point path favours clarity + 32-bit safety
 * (cc65 has `long` but not `long long`).
 *
 * Real literals are emitted as RGC_LIT(fixedbits, floatval): the emitter
 * computes both forms at translate time so the cc65 path never sees a float
 * token. e.g. 7.98 -> RGC_LIT(522977L, 7.98f).
 */
#ifndef RGC_REAL_H
#define RGC_REAL_H

#if defined(__CC65__)

/* ---- 16.16 fixed point (no float, 32-bit-safe) ---------------------------- */
typedef long rgc_real;

#define RGC_FBITS   16
#define RGC_FONE    65536L

#define RGC_LIT(fixedbits, floatval)  ((rgc_real)(fixedbits))
#define RGC_FROMINT(i)                ((rgc_real)(i) << RGC_FBITS)
#define RGC_TOINT(r)                  ((int)((r) >> RGC_FBITS))   /* floor */
#define RGC_ADD(a, b)                 ((a) + (b))
#define RGC_SUB(a, b)                 ((a) - (b))
#define RGC_NEG(a)                    (-(a))
/* Pre-shift so the product stays inside 32 bits (cc65 has no long long).
 * a = A<<16, b = B<<16; (a>>8)*(b>>8) = A*B<<16. Drops the low 8 bits of each
 * operand (~1/256 effective precision) — ample for game arithmetic. */
#define RGC_MUL(a, b)                 (((a) >> 8) * ((b) >> 8))
/* (a<<8)/(b>>8) = (A<<24)/(B<<8) = (A/B)<<16, staying in 32 bits. */
#define RGC_DIV(a, b)                 (((a) << 8) / ((b) >> 8))
#define RGC_FLOOR(r)                  ((r) & ~(RGC_FONE - 1))
#define RGC_ABS(a)                    ((a) < 0 ? -(a) : (a))
/* 16-bit random word -> real in [0,1): the bits ARE the 16.16 fraction. */
#define RGC_RND_FROM16(x)             ((rgc_real)((x) & 0xFFFF))

static rgc_real rgc_sqrt(rgc_real v) {
    rgc_real x, last;
    if (v <= 0) return 0;
    x = v > RGC_FONE ? v : RGC_FONE;        /* seed */
    /* Newton: x = (x + v/x) / 2, fixed point. Converges fast for our range. */
    last = 0;
    while (x != last) {
        last = x;
        x = (x + RGC_DIV(v, x)) >> 1;
    }
    return x;
}

#else

/* ---- native float (no <math.h>: not portable across retro toolchains) ----- */
typedef float rgc_real;

#define RGC_LIT(fixedbits, floatval)  (floatval)
#define RGC_FROMINT(i)                ((rgc_real)(i))
#define RGC_TOINT(r)                  ((int)rgc_floor(r))         /* floor */
#define RGC_ADD(a, b)                 ((a) + (b))
#define RGC_SUB(a, b)                 ((a) - (b))
#define RGC_NEG(a)                    (-(a))
#define RGC_MUL(a, b)                 ((a) * (b))
#define RGC_DIV(a, b)                 ((a) / (b))
#define RGC_FLOOR(r)                  (rgc_floor(r))
#define RGC_ABS(a)                    ((a) < 0 ? -(a) : (a))
#define RGC_RND_FROM16(x)             ((rgc_real)((x) & 0xFFFF) / (rgc_real)65536)

static rgc_real rgc_floor(rgc_real x) {
    long t = (long)x;                  /* truncates toward zero */
    if ((rgc_real)t > x) t--;          /* round down for negatives */
    return (rgc_real)t;
}

static rgc_real rgc_sqrt(rgc_real v) {
    rgc_real x, last;
    int i;
    if (v <= 0) return 0;
    x = v < 1 ? (rgc_real)1 : v;        /* seed */
    for (i = 0; i < 40; i++) {
        last = x;
        x = (x + v / x) / 2;
        if (x == last) break;
    }
    return x;
}

#endif

/* INT(x) in BASIC returns the floor as a real (integral-valued). */
#define RGC_INT(r)   RGC_FLOOR(r)

#endif /* RGC_REAL_H */
