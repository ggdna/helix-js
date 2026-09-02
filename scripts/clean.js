// @license
// Copyright (c) 2026 ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

// Removes the build output and prepares the generated folder. Node does
// this on every platform — `rm -rf` and `mkdir -p` do not exist on
// Windows.

import { mkdirSync, rmSync } from 'fs';

for (const dir of ['dist', 'typescript/generated']) {
  rmSync(dir, { recursive: true, force: true });
}
mkdirSync('typescript/generated', { recursive: true });
