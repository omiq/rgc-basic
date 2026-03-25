#!/bin/bash
# Pulls the **current branch** from origin (no local upstream needed), then rebuilds.
# Example on main: same as  git pull origin main && make ...
# Uses a normal merge pull (not --ff-only) so local commits on top of origin still work.
source /home/chrisg/github/emsdk/emsdk_env.sh
set -e
BRANCH=$(git rev-parse --abbrev-ref HEAD)
git pull origin "$BRANCH"
make clean
make
make basic-gfx
make basic-wasm
make basic-wasm-modular
make basic-wasm-canvas
# Optional: make wasm-test && make wasm-canvas-test && make wasm-tutorial-test  (needs Playwright)
