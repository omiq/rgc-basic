# WASM host hook for `EXEC$` and `SYSTEM` (Emscripten)

**Status:** Implemented in **`basic.c`** for all Asyncify WASM builds (**`basic.js`**, **`basic-modular.js`**, **`basic-canvas.js`**). Native/desktop behaviour is unchanged: **`popen`** / **`system`** shell.

## Purpose

In the browser there is **no shell**. This hook gives the **embedding developer** (IDE, tutorial page, WordPress) a single, explicit integration point so BASIC programs can **request work from the host** — same *role* as desktop **`EXEC$("…")`**, but **you** implement the semantics in JavaScript instead of the OS running arbitrary shell commands.

**Security model:** The BASIC program passes an **opaque string** `cmd$`. **Only** your **`Module.rgcHostExec`** (or legacy **`Module.onRgcExec`**) runs. There is **no** `eval(cmd$)` in the runtime. Untrusted BASIC still cannot execute arbitrary JS unless **you** choose to interpret `cmd$` that way.

## Registering the hook

Before or after loading WASM, set **one** of these on the same **`Module`** object Emscripten uses:

| Property | Type | Notes |
|----------|------|--------|
| **`Module.rgcHostExec`** | `function (cmd: string) => …` | **Preferred** name |
| **`Module.onRgcExec`** | same | **Legacy** alias; same behaviour |

If neither is a **function**, **`EXEC$`** returns **`""`** and **`SYSTEM`** returns **`-1`** (same as the previous WASM stubs).

### Return shapes (sync or async)

Your handler may return:

1. **`{ stdout: string, exitCode: number }`** — best for **`EXEC$`** + **`SYSTEM`** together.  
   - **`stdout`** is copied into the BASIC string (**truncated** to current max string length).  
   - **`exitCode`** is what **`SYSTEM`** returns (typically **0** = success).

2. **A plain string** — treated as **`stdout`** only; **`exitCode`** is taken from **`Module.rgcHostExecLastExit`** if that property is a **number**, otherwise **`0`**.

3. **`undefined` / `null`** — **`stdout`** is **`""`**; **`exitCode`** from **`Module.rgcHostExecLastExit`** if set, else **`0`**.

4. **A `Promise`** resolving to any of the above — **supported** (the runtime awaits inside **`wasm_js_host_exec_async`**). Use for **`fetch`**, **`navigator.clipboard`**, or messaging the IDE over **`postMessage`**.

### Optional: exit code when returning a string

Set **`Module.rgcHostExecLastExit = n`** (integer) before returning a bare string if **`SYSTEM`** should see a non-zero code while **`EXEC$`** still gets the string.

## BASIC mapping

| BASIC | WASM with hook |
|-------|------------------|
| **`R$ = EXEC$(cmd$)`** | Calls hook with **`cmd$`**; **`R$`** = returned **`stdout`** (trimming rules match native: trailing CR/LF trimmed in native path; WASM copies UTF-8 via `stringToUTF8` / cap). |
| **`S = SYSTEM(cmd$)`** | Calls hook once; **`S`** = **`exitCode`** (integer). **`stdout`** from the same call is **discarded** for **`SYSTEM`** (the C side passes **`want_stdout=0`**). |

Both paths **flush** the same way as **`HTTP$`**: canvas refreshes **`wasm_gfx_refresh_js`**, terminal flushes **`BEFORE_CSTDIO`**, then **`emscripten_sleep(0)`**, then the async host call — so **`PRINT`** lines appear before a slow host call.

## Command string conventions

The runtime does **not** parse `cmd$`. Recommended IDE pattern:

- **Prefix verbs:** `ide:uppercase`, `ide:replace\told\tnew`, `compiler:build`, …
- **Or JSON:** `ide:{"op":"selection","action":"uppercase"}` — parse in JS with **`JSON.parse`** inside **`try/catch`**.

Keep payloads bounded; BASIC strings are limited by **`#OPTION MAXSTR`** / defaults.

## Modular build (`createBasicModular`)

Each **`Module`** instance is separate. Assign **`instance.rgcHostExec = …`** on the object returned by **`createBasicModular({ … })`**, not only on **`window.Module`** (unless you merge references the same way your loader already does).

## Standalone demo page

**`web/host-exec-example.html`** — minimal page (no VFS UI) that defines **`Module.rgcHostExec`** with demo verbs **`demo:echo:`**, **`demo:uppercase:`**, **`demo:exit:`**, **`demo:async:`**. Serve from **`web/`** after **`make basic-wasm`**, e.g. **`cd web && python3 -m http.server 8765`**, then open **`http://127.0.0.1:8765/host-exec-example.html`**.

## Playwright / CI smoke

**`web/index.html`** defines a minimal hook that responds to the sentinel command:

```text
__wasm_browser_host_exec_test__
```

with **`{ stdout: 'HOST_OK', exitCode: 0 }`**. **`tests/wasm_browser_test.py`** runs a short BASIC program that **`PRINT EXEC$(…)`** and asserts **`HOST_OK`** in the output.

## Manual testing checklist

1. Build: **`make basic-wasm`** (or modular / canvas).
2. Open **`web/index.html`** (or your embed).
3. In devtools: **`Module.rgcHostExec = cmd => ({ stdout: 'ECHO:'+cmd, exitCode: 0 })`**
4. Run: **`10 PRINT EXEC$("hello"):20 PRINT SYSTEM("x"):30 END`** — expect **`ECHO:hello`** and **`0`** (or your exit code).

Edge cases to verify in the IDE:

- [ ] Very long **`cmd$`** (near **`MAXSTR`**) — host should not assume unbounded buffers.
- [ ] **`await`** inside hook — Asyncify should still unwind correctly.
- [ ] Hook throws — **`EXEC$`** → **`""`**, **`SYSTEM`** → **`-1`** (errors swallowed; check console in browser).
- [ ] **`SYSTEM`** without hook — **`-1`**.
- [ ] Canvas + **`PRINT`** then **`EXEC$`** — output order after flush.

## Related

- **`docs/ide-wasm-tools.md`** — **`ARG$`**, **`HTTPFETCH`**, canvas tool workflow
- **`README.md`** — **`EXEC$` / `SYSTEM`** native vs browser summary
