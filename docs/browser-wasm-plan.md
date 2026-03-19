# Browser / WASM Target – Planning Notes

## Overview

Compile CBM-BASIC to WebAssembly (via Emscripten) so it runs in the browser. The interpreter remains the same; only the I/O layer changes.

**Order**: Implement after bitmap graphics (see to-do.md). Bitmap completes the native graphics story first; browser port then has a clear target.

---

## Not an Emulator

CBM-BASIC is an interpreter, not a hardware emulator. In the browser it runs the same interpreter. No 6502 or C64 hardware emulation.

---

## I/O Backends (Pluggable)

The interpreter needs output and input routing. Different backends can support different use cases:

| Use case | Output | Input |
|----------|--------|-------|
| **Terminal-style** | Scrollable text area (`<pre>` or similar) | Text field + keyboard events |
| **Canvas/graphics** | 40×25 or 320×200 canvas (like basic-gfx) | Keyboard events |
| **Compute-only** | None (or log) | None (or preloaded data) |
| **Hybrid** | Text log + optional canvas | As above |

---

## Tutorial Embedded Output

**Key use case**: Written tutorials with example code blocks where output appears in embedded divs, interpreted in real time.

Example layout:

```html
<div class="example">
  <pre>10 PRINT "HELLO"
20 INPUT "Name? ", N$
30 PRINT "Hi, "; N$</pre>
  <button>Run</button>
  <div class="output"></div>  <!-- Output appears here -->
</div>
```

When the user clicks Run, the interpreter executes the BASIC and sends PRINT output to that specific div. INPUT prompts and fields appear in the same div.

**Real-time options**:
- **On Run** – Execute when user clicks Run
- **Live** – Re-run on each edit (with debouncing)
- **Step-by-step** – Run one line at a time for teaching

**Multiple examples** – Each example can have its own div and interpreter context. Many small programs on one page, each with its own output area.

---

## Implementation Notes

- Emscripten compiles C to WASM.
- Replace raylib with a web-compatible renderer (Canvas 2D, WebGL) for graphics mode.
- Terminal-style: PRINT → DOM append; INPUT/GET → prompt or inline text field.
- Async/event loop: browser doesn’t block; integrate with requestAnimationFrame or similar.
- File I/O: IndexedDB, localStorage, or File API; or sandboxed (no file access).

---

## Dependencies

- Bitmap graphics implemented first (native).
- Emscripten toolchain.
- JS glue for DOM/Canvas/events.
