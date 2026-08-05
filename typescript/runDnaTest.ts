// @license
// Copyright (c) 2026 ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

// Node-side entry point for the placed DNA test. Mirrors gg_dna's
// `run_dna_test.dart` exactly: one instantiation over the target project,
// then the same outcome semantics — hand-modified instances fail, pending
// updates are written and fail once ("review & commit"), a dirty working
// tree blocks writes, a missing LICENSE fails.
//
// The engine itself runs inside the wasm-compiled Dart module; this file
// only supplies the host callbacks (node:fs, git) and the bundled base DNA.

import type { DnaHostCallbacks, DnaInstantiationResult } from './index.js';
import { init } from './index.js';

/** Headline for hand-edited generated files (verbatim from gg_dna). */
export const modifiedInstancesMessage = 'Generated files modified by hand:';

/** Headline of the per-file guard failure (verbatim from gg_dna). */
export const uncommittedTargetsMessage =
  'Generated files carry invalid changes:';

/** Headline when the generated files could not be committed. */
export const needsCommitMessage = 'Generated files need a commit:';

/** Commit message of the automatic commit (verbatim from gg_dna). */
export const generatedDnaCommitMessage = '#gg: generated DNA';

// Colors of the DNA report — the problem in cError, files in cCmd, what
// to do in cAction. Plain ANSI, mirroring gg_console_colors on the Dart
// side.
const cError = (s: string): string => `\x1B[31m${s}\x1B[0m`;
const cCmd = (s: string): string => `\x1B[34m${s}\x1B[0m`;
const cAction = (s: string): string => `\x1B[33m${s}\x1B[0m`;

/**
 * Renders one instruction per reported path: move the edits from the
 * generated file to the DNA file it is produced from.
 * @param paths - The reported project paths, in report order.
 * @param sources - Path → DNA source file, as returned by the engine.
 * @returns The report block, one line per path.
 */
export function describeDnaSources(
  paths: string[],
  sources: Record<string, string>,
): string {
  return paths
    .map((path) => {
      const source = sources[path];
      return source === undefined
        ? `${cAction('Commit or stash')} ${cCmd(path)}.`
        : `${cAction('Move edits from')} ${cCmd(path)} ` +
            `${cAction('to')} ${cCmd(source)}.`;
    })
    .join('\n');
}

/** Options for {@link runDnaTest}. */
export interface RunDnaTestOptions {
  /**
   * Root folder of the project to instantiate. Defaults to the current
   * working directory. Backslashes are normalized to `/`.
   */
  targetRoot?: string;
}

/**
 * Entry point for the placed DNA test:
 *
 * ```ts
 * import { runDnaTest } from '@tssuite/gg-dna';
 * test('dna is instantiated and unmodified', async () => {
 *   await runDnaTest();
 * }, 120000);
 * ```
 *
 * Runs one instantiation over the target project and throws when the
 * project is not in a clean, up-to-date DNA state:
 *
 * - hand-modified instances → fails, files stay untouched
 * - DNA updates → writes them and commits them as "#gg: generated DNA"
 * - generated files with uncommitted changes → fails without writing
 * - missing LICENSE → fails
 * @param options - Target selection; see {@link RunDnaTestOptions}.
 */
export async function runDnaTest(
  options: RunDnaTestOptions = {},
): Promise<void> {
  const fs = await import('node:fs');
  const path = await import('node:path');
  const { execSync } = await import('node:child_process');
  const { fileURLToPath } = await import('node:url');

  const targetRoot = (options.targetRoot ?? process.cwd()).replace(/\\/g, '/');
  const baseDnaRoot = resolveBaseDnaRoot(fs, fileURLToPath);
  const baseVersion = readBaseVersion(fs, baseDnaRoot);
  const host = createNodeHost(fs, path, execSync);

  const bridge = await init();

  let result: DnaInstantiationResult;
  try {
    result = bridge.instantiate(host, targetRoot, baseDnaRoot, baseVersion);
  } catch (e) {
    throw e instanceof Error ? e : new Error(String(e));
  }

  for (const warning of result.warnings) {
    console.log(`warning: ${warning}`);
  }
  for (const message of result.messages) {
    console.log(message);
  }

  if (result.modifiedInstances.length > 0) {
    throw new Error(
      `\n${cError(modifiedInstancesMessage)}\n` +
        `${describeDnaSources(result.modifiedInstances, result.sources)}`,
    );
  }
  if (result.uncommittedTargets.length > 0) {
    throw new Error(
      `\n${cError(uncommittedTargetsMessage)}\n` +
        `${describeDnaSources(result.uncommittedTargets, result.sources)}`,
    );
  }
  if (result.updated.length > 0 && !result.committed) {
    throw new Error(
      `\n${cError(needsCommitMessage)}\n` +
        result.updated
          .map((p) => `${cAction('Commit')} ${cCmd(p)}.`)
          .join('\n'),
    );
  }
  if (!host.existsFile(`${targetRoot}/LICENSE`)) {
    throw new Error(
      'LICENSE is missing — ship it via a DNA layer or add it manually.',
    );
  }
}

// -----------------------------------------------------------------------------
// Bundled base DNA
// -----------------------------------------------------------------------------

type FsModule = typeof import('node:fs');
type PathModule = typeof import('node:path');
type ExecSync = typeof import('node:child_process').execSync;
type FileUrlToPath = typeof import('node:url').fileURLToPath;

// The build bundles gg_dna's own package root (its `dna/` folder is the
// implicit base layer plus a `base-version.json`) next to the emitted JS:
//
//   dist/base-dna/…                  (published package; entry files)
//   dist/chunks/…  → ../base-dna     (this module may land in a chunk)
//   typescript/generated/base-dna/…  (source runs, e.g. vitest)
function resolveBaseDnaRoot(fs: FsModule, fileURLToPath: FileUrlToPath): string {
  const candidates = ['./base-dna', '../base-dna', './generated/base-dna'];
  for (const candidate of candidates) {
    const url = new URL(candidate, import.meta.url);
    if (url.protocol !== 'file:') continue;
    const root = fileURLToPath(url).replace(/\\/g, '/');
    if (fs.existsSync(`${root}/dna`)) return root;
  }
  throw new Error(
    'Bundled base DNA not found next to @tssuite/gg-dna — ' +
      'run `pnpm run build` (dart run build.dart + build:ts) first.',
  );
}

function readBaseVersion(fs: FsModule, baseDnaRoot: string): string {
  const file = `${baseDnaRoot}/base-version.json`;
  if (!fs.existsSync(file)) {
    throw new Error(
      `Bundled base DNA is incomplete — missing ${file}. ` +
        'Run `pnpm run build` first.',
    );
  }
  const parsed = JSON.parse(fs.readFileSync(file, 'utf8')) as {
    version?: string;
  };
  if (typeof parsed.version !== 'string') {
    throw new Error(`${file} has no "version" string.`);
  }
  return parsed.version;
}

// -----------------------------------------------------------------------------
// Node host callbacks
// -----------------------------------------------------------------------------

function createNodeHost(
  fs: FsModule,
  path: PathModule,
  execSync: ExecSync,
): DnaHostCallbacks {
  const listFiles = (dir: string, base: string, out: string[]): void => {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = `${dir}/${entry.name}`;
      if (entry.isSymbolicLink()) continue; // never follow symlinks
      if (entry.isDirectory()) {
        listFiles(full, base, out);
      } else if (entry.isFile()) {
        out.push(path.posix.relative(base, full));
      }
    }
  };

  return {
    existsFile: (p) => fs.existsSync(p) && fs.statSync(p).isFile(),
    existsDir: (p) => fs.existsSync(p) && fs.statSync(p).isDirectory(),
    readBytes: (p) => {
      const buffer = fs.readFileSync(p); // throws on missing
      return new Uint8Array(buffer.buffer, buffer.byteOffset, buffer.byteLength);
    },
    writeBytes: (p, bytes) => {
      fs.mkdirSync(path.posix.dirname(p), { recursive: true });
      fs.writeFileSync(p, bytes);
    },
    deleteFile: (p) => {
      if (fs.existsSync(p) && fs.statSync(p).isFile()) fs.rmSync(p);
    },
    deleteDir: (p) => {
      fs.rmSync(p, { recursive: true, force: true });
    },
    createDir: (p) => {
      fs.mkdirSync(p, { recursive: true });
    },
    rename: (from, to) => {
      fs.renameSync(from, to);
    },
    listFilesRecursive: (dir) => {
      if (!fs.existsSync(dir) || !fs.statSync(dir).isDirectory()) return [];
      const out: string[] = [];
      listFiles(dir.replace(/\/+$/, ''), dir.replace(/\/+$/, ''), out);
      return out.sort();
    },
    commitPaths: (repoRoot, paths, message) => {
      if (paths.length === 0) return;
      // `-A --` stages content, additions and deletions of exactly these
      // paths; the path-limited commit leaves everything else untouched.
      const quoted = paths.map((p) => JSON.stringify(p)).join(' ');
      execSync(`git add -A -- ${quoted}`, { cwd: repoRoot, stdio: 'pipe' });
      execSync(
        `git commit -m ${JSON.stringify(message)} -- ${quoted}`,
        { cwd: repoRoot, stdio: 'pipe' },
      );
    },
    uncommittedPaths: (repoRoot) => {
      // `git status` prints repo-root-relative paths — strip the prefix
      // of repoRoot inside the repository. `-uall` lists untracked files
      // individually instead of collapsing whole folders.
      const git = (args: string): string =>
        execSync(args, { cwd: repoRoot, encoding: 'utf8' });
      const prefix = git('git rev-parse --show-prefix').trim();
      const status = git(
        'git -c core.quotepath=false status --porcelain -uall',
      );
      const paths = new Set<string>();
      for (const line of status.split('\n')) {
        if (line.length < 4) continue;
        const entry = line.slice(3);
        for (const raw of entry.includes(' -> ')
          ? entry.split(' -> ')
          : [entry]) {
          let path = raw.trim().replace(/\\/g, '/');
          if (path.length > 1 && path.startsWith('"') && path.endsWith('"')) {
            path = path.slice(1, -1);
          }
          if (path === '') continue;
          if (prefix === '') paths.add(path);
          else if (path.startsWith(prefix)) paths.add(path.slice(prefix.length));
        }
      }
      return [...paths];
    },
  };
}
