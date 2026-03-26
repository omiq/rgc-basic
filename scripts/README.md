# Scripts

- **ansi.py** — Prints ANSI escape code reference (colors, cursor, clear, etc.) for terminal development.
- **emsdk-env.sh** — `source scripts/emsdk-env.sh` (or `. scripts/emsdk-env.sh`) to put **`emcc`** on PATH from repo **`./emsdk`**. Needed in **sh/dash**: upstream **`emsdk/emsdk_env.sh`** only auto-finds itself in **bash/zsh/ksh** unless the cwd is **`emsdk/`**; this wrapper `cd`s there first. One-time: `git clone https://github.com/emscripten-core/emsdk.git emsdk && cd emsdk && ./emsdk install latest && ./emsdk activate latest`. In **`~/.bashrc`**, source **`/workspace/emsdk/emsdk_env.sh`** (not `emsdk/emsdk/...`).
- **pullmake.sh** — `git pull`, `make clean`, native `basic`, optional `basic-gfx` (if `pkg-config raylib`), then `basic-wasm` / `basic-wasm-modular` / `basic-wasm-canvas`. Sources emsdk from `$EMSDK`, `./emsdk`, or `$HOME/emsdk`.
- **pullmake-wasm.sh** — Same pull + **WASM only** (no native `basic`, no Raylib). For servers that only deploy `web/*.js` + `web/*.wasm`. Requires emsdk (same discovery as above).
- **tag-version.sh** — Helper for creating version tags (see usage in script).
