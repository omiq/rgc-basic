# MEMSET, MEMCPY, MEMSHIFT – Planning Notes

## XC=BASIC v3 Reference

### MEMSET
**Syntax:** `MEMSET address, length, fill_value`

Sets `length` bytes starting at `address` to `fill_value`.  
Example: `MEMSET 1024, 1000, 32` fills 1000 bytes at 1024 with 32 (clear screen).

### MEMCPY
**Syntax:** `MEMCPY dest_address, src_address, length`

Copies `length` bytes from `src_address` to `dest_address`.  
XC=BASIC: overlapping-safe **downwards only** (dest &lt; src or non-overlapping). For overlapping **upwards** (dest &gt; src), use MEMSHIFT.

### MEMSHIFT
**Syntax:** (similar to MEMCPY, direction implied)

Copies overlapping regions **upwards** (dest &gt; src). Uses a backward copy so source bytes are not overwritten before being read.

---

## Our Simulated Memory Model

CBM-BASIC uses a virtual 16-bit address space backed by arrays:

| Range        | Base     | Size  | Backing array |
|--------------|----------|-------|----------------|
| Screen RAM   | 0x0400   | 1000  | `screen[]`     |
| Colour RAM   | 0xD800   | 1000  | `color[]`      |
| Char/UDG     | 0x3000   | 2048  | `chars[]`      |
| Bitmap       | 0x2000   | 8000  | `bitmap[]`     |
| Keys (RO)    | 0xDC00   | 256   | `key_state[]`  |

All access goes through `gfx_peek()` / `gfx_poke()`. Addresses outside these ranges read 0 and ignore writes.

---

## Implementation Approach

### MEMSET
- Iterate `length` bytes from `address`.
- For each byte: `gfx_poke(s, addr + i, fill_value)`.
- Only meaningful when `GFX_VIDEO` is defined. In terminal mode: no-op (POKE is already a no-op).

### MEMCPY
- Two cases for overlap:
  - **dest &lt; src** or **non-overlapping**: copy low→high (forward).
  - **dest &gt; src** (overlapping upwards): copy high→low (backward) to avoid overwriting source.
- Implement via byte-by-byte PEEK/POKE so routing stays correct across regions.
- Same as C’s `memmove`; no separate MEMSHIFT needed.

### MEMSHIFT – Do We Need It?

**No.** With our array-backed model we can implement MEMCPY to handle overlap in both directions (like `memmove`). A single MEMCPY that:

1. If `dest < src` or `dest >= src + length`: copy forward.
2. If `dest > src` and `dest < src + length`: copy backward.

covers all cases. MEMSHIFT exists in XC=BASIC because its MEMCPY is optimized for the downward case only; we don’t have that constraint.

**Recommendation:** Implement MEMSET and MEMCPY only. Omit MEMSHIFT.

---

## Parameter Order (XC=BASIC vs C)

| Command | XC=BASIC              | C equivalent        |
|---------|------------------------|---------------------|
| MEMSET  | `address, length, val` | `memset(ptr, val, n)` – note val/length order differs |
| MEMCPY  | `dest, src, length`    | `memcpy(dest, src, n)` – same |

---

## Scope

- **GFX build only**: MEMSET and MEMCPY operate on the virtual address space via `gfx_peek`/`gfx_poke`.
- **Terminal build**: No-op or optional “not supported” error. PEEK/POKE are already no-ops there.
- **Cross-region copies**: Allowed. E.g. MEMCPY from screen to colour RAM; each byte is routed to the correct array by the existing PEEK/POKE logic.

---

## Edge Cases

- **Length 0**: No-op.
- **Negative length**: Error (or treat as 0).
- **Address wrap**: Use 16-bit `addr & 0xFFFF` for consistency with PEEK/POKE.
- **Keys range (0xDC00)**: POKE to keys is currently ignored; MEMSET/MEMCPY would behave the same (writes dropped).
