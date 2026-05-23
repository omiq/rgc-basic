# RGC-BASIC conformance corpus

Short, **headless** `.bas` scripts that assert on known behaviour, one feature
area per file. A regression gate that both rgc-basic CI and external adopters
(e.g. the Haversack tool runtime) run against the *same* corpus, so there's no
drift between what rgc-basic tests and what tools rely on.

This is deliberately **separate from `examples/`**: examples are demos for
humans (gfx, music, RPG, interactive tutorials, many of which need a window /
user gesture / event loop). Conformance scripts are short, headless, and
assert on known output — suitable for CI in both the native CLI and the
`basic-wasm` node harness.

## How it works

- Each script uses **`ASSERT cond, "msg"`** to gate expected values. A false
  assertion halts with **exit code 2** and the message; a runtime error halts
  with **exit code 1**; clean termination is **exit 0**.
- **`--json-status`** makes the interpreter print a final stdout line of the
  form `{"exit":N,"reason":"...","line":N}`, so any host (bash, node, PHP) can
  read the outcome without parsing diagnostics.

## Running

Native (`./basic`):

```sh
sh conformance/run.sh            # uses ./basic
sh conformance/run.sh ./basic    # explicit binary
```

WASM (`web/basic.js` via the node runner — same corpus, same exit-code
contract, so both build targets share one CI matrix):

```sh
make basic-wasm                  # build web/basic.js first
sh conformance/run-wasm.sh       # or: make wasm-conformance
```

A single script can also be run directly under WASM:

```sh
node tests/run-wasm.js [--flags "<flags>"] conformance/string/escapes.bas
```

The native `conformance/run.sh` runs as part of `make check`. The WASM
variant is opt-in (`make wasm-conformance`) since it needs node + a built
`web/basic.js`.

## Layout

```
conformance/
  README.md
  run.sh             # native runner (./basic)
  run-wasm.sh        # WASM runner (node tests/run-wasm.js over web/basic.js)
  control/
    for_goto_next.bas  # forward GOTO within a FOR body → NEXT
  string/
    escapes.bas        # backslash escape sequences
```

Add new feature areas as subdirectories (`json/`, `dict/`, `http/`,
`fileio/`, …). Keep each script focused on one feature and headless.
