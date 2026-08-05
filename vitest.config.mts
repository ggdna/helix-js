// @license
// Copyright (c) 2026 ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

// Node-only test setup: the DNA engine's host callbacks are implemented
// with node:fs / git, so the specs run in the Node runtime exclusively
// (unlike the gg-bridge-dart-typescript template, which also tests in
// Playwright/Chromium).

/// <reference types="vitest" />

import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    name: 'node',
    environment: 'node',
    include: ['typescript/test/**/*.test.ts'],
    exclude: ['node_modules/**'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html'],
      include: ['typescript/**/*.ts'],
      exclude: [
        'typescript/index.ts',
        'typescript/index.browser.ts',
        'typescript/index.node.ts',
        'typescript/test/**',
        'typescript/generated/**',
      ],
    },
  },
});
