# HTTP fetch and VFS assets (design notes)

**Status:** **`HTTPFETCH`**, **`OPEN`** binary prefixes (`rb:`/`wb:`/`ab:`), **`PUTBYTE`**, and **`GETBYTE`** are implemented (see **`CHANGELOG.md`**). The sections below record the original rationale; **Priority 1** (fetch-to-file) and **Priority 2** (binary I/O) are covered by those features. Further work is optional (streaming, extra native backends, etc.).

## Context

IDE **tools** and **utilities** (see **`docs/ide-wasm-tools.md`**) often need to **download assets** (PNG, JSON, etc.) into the **Emscripten MEMFS** so **`LOADSPRITE`**, **`OPEN`**, and friends see a normal path like **`/preview.png`**.

Today:

- **`HTTP$`** returns the response **body as a string** (WASM: `fetch` + Asyncify). Fine for **small text**; **large binary** hits **`MAXSTR`** and string overhead.
- **`HTTPFETCH`** writes the **raw body** to a path (WASM + optional **`curl`** on Unix) — use for PNGs and large blobs.
- **`OPEN` / `PRINT#` / `INPUT#` / `GET#`** — text-oriented; **`PRINT#`** is not a general binary writer. Use **`"rb:"`/`"wb:"`/`"ab:"`** prefixes and **`PUTBYTE`/`GETBYTE`** for bytes.
- The **host IDE** can still **`fetch`** in JavaScript and **`Module.FS.writeFile(path, bytes)`** — no interpreter change required.

This document records **whether** and **how** the language supports **portable**, **BASIC-only** asset pipelines (same story on **native** with **`EXEC$("curl …")`** vs **WASM** with **`HTTP$`** / **`HTTPFETCH`**).

---

## Recommendation: yes, but targeted

**Bolster** interpreter features **selectively** if you want:

- **Self-contained tool programs** — one **`.bas`** that fetches and uses an asset without custom JS per tool.
- **Parity** — same script for **canvas WASM** and (where possible) **terminal / basic-gfx**.
- **Teaching** — “download into the project” entirely in BASIC.

**Do not** rely on stuffing PNG bytes into **`PRINT#`** or giant **`HTTP$`** return strings.

---

## Priority 1: Fetch directly to a file (WASM + native)

**Implemented:** **`HTTPFETCH url$, path$`** → status in **`HTTPSTATUS()`** and as the numeric return value. See **`CHANGELOG.md`**.

**Native:** Unix builds may use **`curl`** when available; otherwise use **`EXEC$("curl -o …")`** or extend the runtime.

---

## Priority 2: Binary-safe file I/O

**Implemented:** **`OPEN`** with **`"rb:"`**, **`"wb:"`**, **`"ab:"`** filename prefixes; **`PUTBYTE #lfn, expr`** / **`GETBYTE #lfn, var`**.

---

## What can stay as-is

- **`HTTP$`** for **JSON**, short **text**, and **small** responses.
- **IDE-only path:** **`fetch` + `FS.writeFile`** remains valid and often **best** for CORS edge cases, large CDN assets, or auth headers — the interpreter does not need to replace every JS workflow.

---

## Relationship to **`docs/ide-wasm-tools.md`**

- **IDE** may **prefetch** to MEMFS and pass **`ARG$(1)`** via **`basic_load_and_run_gfx_argline`** — or use **`HTTPFETCH`** inside the tool.
- **`HTTPFETCH`** / binary I/O makes **BASIC-only** tools **ergonomic** without one-off JS shims for every asset type.

---

## Related

- **`docs/wasm-assets-loadsprite-http.md`** — **`LOADSPRITE`** cannot use **`https://`** URLs; use **`HTTPFETCH`** to MEMFS or host **`FS.writeFile`** (embeds, WordPress, tutorials).
- **`docs/ide-wasm-tools.md`** — **`basic_load_and_run_gfx`**, **`basic_load_and_run_gfx_argline`**, **`ARG$`**, MEMFS.
- **`web/README.md`** — **`HTTP$`**, **`HTTPFETCH`**, Asyncify, CORS.
