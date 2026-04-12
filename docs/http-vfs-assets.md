# HTTP fetch and VFS assets (design notes)

**Status:** recommendations for future work — not implemented as a single feature bundle.

## Context

IDE **tools** and **utilities** (see **`docs/ide-wasm-tools.md`**) often need to **download assets** (PNG, JSON, etc.) into the **Emscripten MEMFS** so **`LOADSPRITE`**, **`OPEN`**, and friends see a normal path like **`/preview.png`**.

Today:

- **`HTTP$`** returns the response **body as a string** (WASM: `fetch` + Asyncify). Fine for **small text**; **large binary** hits **`MAXSTR`** and string overhead.
- **`OPEN` / `PRINT#` / `INPUT#` / `GET#`** are oriented toward **text**; **`PRINT#`** is not a general **binary blob** writer (C strings, formatting).
- The **host IDE** can always **`fetch`** in JavaScript and **`Module.FS.writeFile(path, bytes)`** — no interpreter change required.

This document records **whether** and **how** to extend the language for **portable**, **BASIC-only** asset pipelines (same story on **native** with **`EXEC$("curl …")`** vs **WASM** with **`HTTP$`**).

---

## Recommendation: yes, but targeted

**Bolster** interpreter features **selectively** if you want:

- **Self-contained tool programs** — one **`.bas`** that fetches and uses an asset without custom JS per tool.
- **Parity** — same script for **canvas WASM** and (where possible) **terminal / basic-gfx**.
- **Teaching** — “download into the project” entirely in BASIC.

**Do not** rely on stuffing PNG bytes into **`PRINT#`** or giant **`HTTP$`** return strings.

---

## Priority 1: Fetch directly to a file (WASM + native)

Add a way to write the **raw response body** to a **host path** without holding it all in a **`STRING$`**:

- **Option A:** New intrinsic, e.g. **`HTTPFETCH url$, path$`** → status in **`HTTPSTATUS()`** (or return code).
- **Option B:** Extend **`HTTP$`** with an optional “write to path” overload (document carefully to avoid ambiguity with **`HTTP`** vs **`HTTPSTATUS`** parsing).

**Benefits:** avoids **`MAXSTR`**, avoids double memory for large files, matches how **`LOADSPRITE`** already expects a **path**.

**Native:** implement with **`curl`**, **`wget`**, or portable **socket** code — or document **`EXEC$("curl -o …")`** as the host workaround until implemented.

---

## Priority 2: Binary-safe file I/O

Support **explicit binary mode** and **byte-oriented** I/O where needed:

- **`OPEN`**: **`"rb"`** / **`"wb"`** / **`"ab"`** (or CBM-style secondary codes mapping to binary).
- **`PUTBYTE #lfn, expr`** / **`GETBYTE #lfn, var`** — or a small **`BSAVE`/`BLOAD`**-style block copy from **DATA** / memory (if a memory model exists).

This lets tools **stream** or **chunk** data without **`PRINT#`** of binary strings.

---

## What can stay as-is

- **`HTTP$`** for **JSON**, short **text**, and **small** responses.
- **IDE-only path:** **`fetch` + `FS.writeFile`** remains valid and often **best** for CORS edge cases, large CDN assets, or auth headers — the interpreter does not need to replace every JS workflow.

---

## Relationship to **`docs/ide-wasm-tools.md`**

- **IDE** may **prefetch** to MEMFS and pass **`ARG$(1)`** to a tool — **no** new BASIC features required.
- **Bolstering** **`HTTP$`** / I/O makes **BASIC-only** tools **ergonomic** and **portable**; use it when the cost of implementation is justified by fewer one-off JS shims.

---

## Related

- **`docs/ide-wasm-tools.md`** — **`basic_load_and_run_gfx_argline`**, **`ARG$`**, MEMFS.
- **`web/README.md`** — **`HTTP$`**, Asyncify, CORS.
