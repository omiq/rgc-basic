# Spec: real `INPUT` in the transpiler + headless regression harness

Status: IN PROGRESS (2026-06-18). Owner: Chris + Claude.
Cross-repo: emit_c lives in **rgc-transpiler** (private); interpreter, adventure,
and tests live in **rgc-basic**.

## Why

`adventure-portable.bas` hand-rolled `GetLine()` (a GET poll loop) because the
RGC-BASIC→C transpiler had no `INPUT`. That reinvents the interpreter's `INPUT`.
Add real `INPUT` to emit_c so scripts use `input VAR[$]` directly, and stand up
a headless regression harness so input behaviour doesn't rot as it grows.

## Design decisions (settled)

- **Not cgets.** Emitted programs use emit_c's own scrolling console
  (`rgc_putc`/`rgc_pstr` + RAM shadow). cc65 `cgets` writes screen memory
  directly, desyncing that shadow. Build on the existing `plat_getkey_nb`
  abstraction instead (in the contract on all 18 retro-c adapters) → zero
  adapter changes.
- **Reference = interpreter.** The interpreter's `INPUT` is `fgets`-based
  (basic.c ~15844) and **reads piped stdin**, so it is headless-testable today.
  That is the regression oracle. The host C build uses ncurses (needs a TTY) so
  the compiled path is verified by compile-snapshot + interactive/pty, not pipe.
- **`rgc_input()`** (emit_c runtime): poll `plat_getkey_nb` until Enter (13/10);
  printable bytes (>=32, incl. shifted/symbols) append + echo via the console;
  backspace (8/20/127) trims the buffer; cap at `RGC_STR_MAX`; return a pooled
  `char *`. Mirrors trek's shipped `GetInput`.
- **Forms:** `INPUT VAR`, `INPUT VAR$`, `INPUT "prompt"; VAR`,
  `INPUT "prompt", VAR`. Default (no prompt) prints `"? "` to match interpreter.
  Numeric var → `rgc_val(rgc_input())` (int parse, matches interpreter VAL).

## Tasks

- [x] T1  emit_c: add `ctx.uses_input` flag (Ctx.__init__).
- [x] T2  emit_c: `_INPUT_RE` + `_emit_input(rest, ctx)`; dispatch `kw=="INPUT"`.
- [x] T3  emit_c: emit `rgc_input()` in `_emit_helpers` when `uses_input`
          (gated `need_pool` + `uses_print`; placed after dict block).
- [x] T4  emit_c: numeric INPUT via `rgc_val` (+`add_scalar`); string via `rgc_scpy`.
- [x] T5  Verify: emit-c an INPUT program transpiles; host build compiles (52KB bin).
- [x] T6  Harness: `tests/input/*.bas` + `*.in` + `*.expected` + runner
          `tests/input_test.sh` (pipes stdin through the interpreter oracle).
- [x] T7  Tests: line, symbols, empty, numeric, prompt — all pass.
- [x] T8  adventure-portable: `GetLine()` → `input I$`, removed GetLine func.
          Transpiles + fits (c64 10994, pet 10832); interpreter processes piped
          commands (`look` now shows the room desc — INPUT also fixed the
          words-vs-letters parsing the GET loop had).
- [x] T9  Regression: input harness pass, bigstring pass, emit-c failures
          118→115 (3 INPUT examples newly transpile, zero new breaks).
- [x] T10 Docs: INPUT note added to rgc-transpiler README.
- [x] T11 Commit + push: rgc-transpiler 9fb7906, rgc-basic 9b2f94a.

## DONE 2026-06-18 — all tasks complete.

## Test commands (reference)

```sh
# interpreter INPUT is pipe-testable (the oracle):
printf 'hello\n' | ./basic prog_using_input.bas
# transpile check:
cd ../rgc-transpiler && python3 -m rgcx emit-c prog.bas -o /dev/null
# host compile+run (needs a TTY for ncurses input; compile alone is the headless check):
python3 -m rgcx run prog.bas
# adventure fit:
python3 -c "from pathlib import Path; from rgcx import emu; emu.compile_desktop(Path('../rgc-basic/examples/adventure-portable.bas'),'pet')"
```

## Notes / risks

- Backspace/cursor editing only exists on a real TTY; pipe tests assert the
  line RESULT, not editing keystrokes. pty harness can drive editing if needed.
- emit_c is private (rgc-transpiler); keep the shared front end backwards-compatible.
- adventure-portable currently has a separate WIP: `WaitKey()` returns a value
  but isn't `WaitKey$()` so it won't transpile until renamed (Chris's edit).
