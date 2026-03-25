#!/bin/sh
# Pulls the **current branch** from origin (no local upstream needed), then rebuilds.
# Example on main: same as  git pull origin main && make ...
set -e
BRANCH=$(git rev-parse --abbrev-ref HEAD)
git pull --ff-only origin "$BRANCH"
make clean
make
make basic-gfx
make basic-wasm
make basic-wasm-canvas
# Optional: make wasm-test && make wasm-canvas-test  (needs Playwright)
