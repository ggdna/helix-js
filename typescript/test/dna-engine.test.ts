// @license
// Copyright (c) 2026 ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

// End-to-end smoke test of the wasm-compiled DNA engine: build a tiny
// project fixture on disk (a git repo with one fake DNA dev-dependency),
// run `runDnaTest` against it and verify helix's golden-update semantics:
// the first run writes the instances and fails once ("review & commit"),
// after committing the second run passes.

import { execFileSync, spawnSync } from 'node:child_process';
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { afterAll, describe, expect, test } from 'vitest';
import { runDnaTest } from '../index.js';
import './setup.js';

// The spec needs the compiled wasm bundle and the bundled base DNA — both
// produced by `dart run build.dart` — plus the dart SDK on the PATH.
const generated = fileURLToPath(new URL('../generated/', import.meta.url));
const wasmBuilt =
  existsSync(join(generated, 'bridge-wasm.wasm')) &&
  existsSync(join(generated, 'bridge-wasm.ts')) &&
  existsSync(join(generated, 'base-dna', 'dna'));
const dartOnPath = spawnSync('dart', ['--version']).status === 0;
const runnable = wasmBuilt && dartOnPath;

const tmpDirs: string[] = [];

function git(cwd: string, ...args: string[]): void {
  execFileSync('git', args, { cwd, stdio: 'pipe' });
}

function makeFixture(): string {
  const root = mkdtempSync(join(tmpdir(), 'helix-bridge-fixture-'));
  tmpDirs.push(root);

  // A minimal project consuming one fake DNA package via devDependencies.
  writeFileSync(
    join(root, 'package.json'),
    JSON.stringify(
      {
        name: 'fixture-project',
        version: '1.0.0',
        devDependencies: { 'fake-dna': '1.0.0' },
      },
      null,
      2,
    ) + '\n',
  );
  writeFileSync(join(root, 'LICENSE'), 'MIT — fixture license.\n');

  // Layers are explicit: nothing is inferred from the dependencies.
  mkdirSync(join(root, 'dna'), { recursive: true });
  writeFileSync(
    join(root, 'dna', '_dna.json'),
    JSON.stringify({ version: 1, layers: ['fake-dna'] }, null, 2) + '\n',
  );

  const fakeDna = join(root, 'node_modules', 'fake-dna');
  mkdirSync(join(fakeDna, 'dna', 'doc'), { recursive: true });
  writeFileSync(
    join(fakeDna, 'package.json'),
    JSON.stringify({ name: 'fake-dna', version: '1.0.0' }, null, 2) + '\n',
  );
  // A dna/ folder alone does not make a DNA package — it has to say so.
  writeFileSync(
    join(fakeDna, 'dna', '_dna.json'),
    JSON.stringify({ version: 1, role: 'dna', layers: [] }, null, 2) + '\n',
  );
  writeFileSync(
    join(fakeDna, 'dna', 'doc', 'hello.md'),
    '# Hello\n\nInstantiated by the fake DNA layer.\n',
  );

  // A committed git repo — the engine's per-file guard requires every
  // file it overwrites to be committed (node_modules is committed on
  // purpose so the fake DNA layer counts as committed work).
  git(root, 'init', '--initial-branch=main');
  git(root, 'config', 'user.email', 'fixture@example.com');
  git(root, 'config', 'user.name', 'Fixture');
  git(root, 'config', 'commit.gpgsign', 'false');
  git(root, 'add', '-A');
  git(root, 'commit', '-m', 'fixture');
  return root;
}

afterAll(() => {
  for (const dir of tmpDirs) {
    rmSync(dir, { recursive: true, force: true });
  }
});

describe('runDnaTest (wasm engine, node host)', () => {
  test.skipIf(!runnable)(
    'writes instances on the first run ("review & commit"), passes after commit',
    async () => {
      const root = makeFixture();

      // The engine instantiates the base DNA + fake-dna layer and commits
      // what it generated — the working tree stays clean.
      await expect(runDnaTest({ targetRoot: root })).resolves.toBeUndefined();

      expect(existsSync(join(root, 'doc', 'hello.md'))).toBe(true);
      expect(existsSync(join(root, 'dna', 'doc', 'hello.md'))).toBe(true);
      expect(
        execFileSync('git', ['log', '-1', '--pretty=%s'], {
          cwd: root,
          encoding: 'utf8',
        }).trim(),
      ).toBe('#gg: generated DNA');
      expect(
        execFileSync('git', ['status', '--porcelain'], {
          cwd: root,
          encoding: 'utf8',
        }).trim(),
      ).toBe('');

      // The 2nd run has nothing left to do.
      await expect(runDnaTest({ targetRoot: root })).resolves.toBeUndefined();
    },
    120000,
  );

  test.skipIf(!runnable)(
    'unrelated dirty files do not block a run',
    async () => {
      const root = makeFixture();

      // Dirty an unrelated file before the first instantiation.
      writeFileSync(join(root, 'uncommitted.txt'), 'dirty\n');

      await expect(runDnaTest({ targetRoot: root })).resolves.toBeUndefined();
      expect(existsSync(join(root, 'doc', 'hello.md'))).toBe(true);
      // The unrelated file is still dirty — only generated files were
      // committed.
      expect(
        execFileSync('git', ['status', '--porcelain'], {
          cwd: root,
          encoding: 'utf8',
        }),
      ).toContain('uncommitted.txt');
    },
    120000,
  );

  test.skipIf(!runnable)(
    'blocks adoption of an existing file with uncommitted work',
    async () => {
      const root = makeFixture();

      // The project owns an uncommitted file the DNA would adopt —
      // overwriting it would lose work git could not restore.
      mkdirSync(join(root, 'doc'), { recursive: true });
      writeFileSync(join(root, 'doc', 'hello.md'), '# My own notes\n');

      // The report explains the file is produced by the DNA and names
      // the source to edit instead.
      await expect(runDnaTest({ targetRoot: root })).rejects.toThrowError(
        /invalid changes[\s\S]*Move edits from[\s\S]*fake-dna\/dna\/doc\/hello\.md/,
      );

      // Nothing was written; the file survived untouched.
      expect(readFileSync(join(root, 'doc', 'hello.md'), 'utf8')).toBe(
        '# My own notes\n',
      );
      expect(existsSync(join(root, 'dna', '_generated.json'))).toBe(false);
    },
    120000,
  );

  test.skipIf(!runnable)(
    'surfaces engine failures with a readable message',
    async () => {
      const root = makeFixture();

      // A DNA layer that is not installed — the engine fails. Its message
      // has to reach the caller: a Dart throw would arrive as an opaque
      // `WebAssembly.Exception`.
      writeFileSync(
        join(root, 'dna', '_dna.json'),
        JSON.stringify({ version: 1, layers: ['not-installed'] }, null, 2) +
          '\n',
      );

      await expect(runDnaTest({ targetRoot: root })).rejects.toThrowError(
        /not-installed/,
      );
    },
    120000,
  );
});
