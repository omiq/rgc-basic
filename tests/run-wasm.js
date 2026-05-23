#!/usr/bin/env node
/*
 * Headless WASM runner — drives web/basic.js (the basic-wasm build) the same
 * way the native CLI runs a .bas file, so both build targets share one CI
 * matrix. Wishlist 3f.
 *
 * Usage:
 *   node tests/run-wasm.js [--flags "<interpreter flags>"] <program.bas>
 *
 * Examples:
 *   node tests/run-wasm.js conformance/string/escapes.bas
 *   node tests/run-wasm.js --flags "-petscii" examples/scripting.bas
 *
 * Behaviour mirrors `basic --json-status`:
 *   - PRINT output goes to this process's stdout, diagnostics to stderr.
 *   - On completion, prints a final JSON line {"exit":N,"reason":..,"line":N}
 *     read from the basic_get_exit* ccall exports.
 *   - Exits with that exit code (0 = normal, 1 = runtime error, 2 = ASSERT).
 *
 * Requires a built web/basic.js + web/basic.wasm (make basic-wasm).
 */
'use strict';

const fs = require('fs');
const path = require('path');

function usage(msg) {
    if (msg) process.stderr.write('run-wasm: ' + msg + '\n');
    process.stderr.write('Usage: node tests/run-wasm.js [--flags "<flags>"] <program.bas>\n');
    process.exit(64);
}

let flags = '';
let prog = null;
const argv = process.argv.slice(2);
for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--flags') {
        if (i + 1 >= argv.length) usage('--flags needs a value');
        flags = argv[++i];
    } else if (a === '-h' || a === '--help') {
        usage(null);
    } else if (!prog) {
        prog = a;
    } else {
        usage('unexpected extra argument: ' + a);
    }
}
if (!prog) usage('no program file given');
if (!fs.existsSync(prog)) usage('program file not found: ' + prog);

const repoRoot = path.resolve(__dirname, '..');
const wasmJs = path.join(repoRoot, 'web', 'basic.js');
if (!fs.existsSync(wasmJs)) {
    process.stderr.write('run-wasm: web/basic.js not found — run `make basic-wasm` first.\n');
    process.exit(70);
}

const source = fs.readFileSync(prog, 'utf8');

const Module = require(wasmJs);
Module.print = (s) => process.stdout.write(s + '\n');
Module.printErr = (s) => process.stderr.write(s + '\n');
Module.noInitialRun = true;

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function waitFor(predicate, label, tries = 1000, gap = 10) {
    for (let i = 0; i < tries; i++) {
        if (predicate()) return;
        await sleep(gap);
    }
    throw new Error('timeout waiting for ' + label);
}

async function main() {
    await waitFor(() => typeof Module._basic_load_and_run === 'function',
                  'wasm runtime init');

    Module.ccall('basic_apply_arg_string', 'number', ['string'], [flags]);

    const FS = Module.FS;
    const memPath = '/run.bas';
    try { FS.unlink(memPath); } catch (_) { /* first run */ }
    FS.writeFile(memPath, source);

    Module['wasmRunDone'] = 0;
    Module.ccall('basic_load_and_run', null, ['string'], [memPath]);
    await waitFor(() => Module['wasmRunDone'] === 1, 'program completion');

    const code = Module.ccall('basic_get_exitcode', 'number', [], []);
    const line = Module.ccall('basic_get_exitline', 'number', [], []);
    const reason = Module.ccall('basic_get_exitreason', 'string', [], []);
    process.stdout.write(
        JSON.stringify({ exit: code, reason: reason, line: line }) + '\n');
    process.exit(code);
}

main().catch((e) => {
    process.stderr.write('run-wasm: ' + (e && e.message ? e.message : e) + '\n');
    process.exit(70);
});
