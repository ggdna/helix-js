// @license
// Copyright (c) 2026 ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

// Copies what the Dart build produced next to the compiled TypeScript:
// the WASM module and the base DNA the engine carries. Node does this on
// every platform — `cp -R` does not exist on Windows.

import { cpSync, rmSync } from 'fs';

cpSync('typescript/generated/bridge-wasm.wasm', 'dist/bridge-wasm.wasm');
rmSync('dist/base-dna', { recursive: true, force: true });
cpSync('typescript/generated/base-dna', 'dist/base-dna', { recursive: true });
