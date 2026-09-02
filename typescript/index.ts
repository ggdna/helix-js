// @license
// Copyright (c) 2026 ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import { loadBridge, type RuntimeOptions } from './runtime.js';

export {
  assertWasmGcSupported,
  checkWasmGcSupport,
  type WasmGcSupport,
} from './compat.js';

export { runDnaTest, type RunDnaTestOptions } from './runDnaTest.js';

// -----------------------------------------------------------------------------
// Public TypeScript types — hand-written. These declare the JS-facing API
// that the Dart side promises to deliver. `tsc --emitDeclarationOnly` turns
// them into `dist/index.d.ts`.
// -----------------------------------------------------------------------------

/**
 * The callback host injected into the wasm-compiled helix engine: every
 * file-system and git access of the engine goes through these functions.
 *
 * All paths are posix-separated strings (`/`), absolute or relative to the
 * process working directory.
 */
export interface DnaHostCallbacks {
  /** Whether a file exists at `path`. */
  existsFile(path: string): boolean;
  /** Whether a directory exists at `path`. */
  existsDir(path: string): boolean;
  /**
   * `path` with every symlink on it resolved; `path` itself when it
   * cannot be resolved. pnpm installs a package as a symlink into its
   * store, and the package's own dependencies live next to that store
   * folder — only the resolved path leads to them.
   */
  realPath(path: string): string;
  /** Reads the file at `path` as bytes; throws on missing files. */
  readBytes(path: string): Uint8Array;
  /** Writes `bytes` to `path`, creating parent directories. */
  writeBytes(path: string, bytes: Uint8Array): void;
  /** Deletes the file at `path`; missing files are ignored. */
  deleteFile(path: string): void;
  /** Deletes the directory at `path` recursively; missing dirs ignored. */
  deleteDir(path: string): void;
  /** Creates the directory at `path` recursively. */
  createDir(path: string): void;
  /**
   * Creates a fresh directory below the system temp folder, its name
   * starting with `prefix`, and returns its absolute posix path. It holds
   * the backups of locally changed instances.
   */
  createTempDir(prefix: string): string;
  /** Renames/moves a file or directory from `from` to `to`. */
  rename(from: string, to: string): void;
  /**
   * Lists all files below `dir` recursively as relative posix paths
   * (files only, no directories, symlinks not followed).
   */
  listFilesRecursive(dir: string): string[];
  /**
   * All paths below `repoRoot` that carry uncommitted work — modified,
   * staged, deleted or untracked — as posix paths relative to `repoRoot`.
   * Used to protect individual files from being overwritten.
   */
  uncommittedPaths(repoRoot: string): string[];
  /**
   * Commits exactly `paths` (relative to `repoRoot`) with `message`,
   * leaving every other change untouched. Throws when committing is not
   * possible (no repository, no git identity).
   */
  commitPaths(repoRoot: string, paths: string[], message: string): void;
}

/** Outcome of one DNA instantiation run (mirrors helix's result type). */
export interface DnaInstantiationResult {
  /** Progress and adoption log lines. */
  messages: string[];
  /** Non-fatal findings of config parsing and merging. */
  warnings: string[];
  /**
   * Instances whose content was changed by hand — the run copied the
   * local content to `backupDir` and wrote the DNA content over it.
   */
  backedUp: string[];
  /**
   * The system-temp folder holding the copies of `backedUp`, keeping
   * their project-relative paths. `null` when nothing was backed up.
   */
  backupDir: string | null;
  /** Paths written by this run — non-empty means "review & commit". */
  updated: string[];
  /**
   * Existing files the run had to overwrite or delete that carry
   * uncommitted work — non-empty means the run wrote nothing.
   */
  uncommittedTargets: string[];
  /**
   * For every reported path: the DNA source file it is produced from
   * (e.g. `base-dna/dna/doc/develop.md`) — the file to edit instead of
   * the generated one. Paths without a DNA source are absent.
   */
  sources: Record<string, string>;
  /**
   * Whether `updated` was committed automatically as
   * "#gg: generated DNA". `false` means the files still need a manual
   * commit (no repository, no git identity).
   */
  committed: boolean;
}

/**
 * A run that failed inside the engine. The bridge reports failures as a
 * value rather than throwing them: a Dart throw crosses the wasm boundary
 * as an opaque `WebAssembly.Exception` with an unreadable payload.
 */
export interface DnaBridgeError {
  /** The failure message, and a stack trace for unexpected errors. */
  error: string;
}

/**
 * Whether `result` is a {@link DnaBridgeError} rather than a result.
 * @param result - The value returned by `DartBridge.instantiate`.
 * @returns `true` when the run failed.
 */
export function isDnaBridgeError(
  result: DnaInstantiationResult | DnaBridgeError,
): result is DnaBridgeError {
  return typeof (result as DnaBridgeError).error === 'string';
}

/** The bridge surface exposed to JS/TS callers. */
export interface DartBridge {
  /**
   * Runs one DNA instantiation over `targetRoot` with host access injected
   * via `host`. `baseDnaRoot` points at the bundled helix package root
   * (its `dna/` subfolder is the implicit base layer); `baseVersion` is
   * the helix version recorded in the manifest.
   *
   * Resolves to a {@link DnaBridgeError} when the run failed. The engine
   * runs git through the host, which answers asynchronously, so the
   * result arrives as a promise.
   */
  instantiate(
    host: DnaHostCallbacks,
    targetRoot: string,
    baseDnaRoot: string | null,
    baseVersion: string,
  ): Promise<DnaInstantiationResult | DnaBridgeError>;
}

/** Options for `init()`. */
export type InitOptions = RuntimeOptions;

let cached: DartBridge | undefined;

/**
 * Load and initialize the Dart bridge.
 *
 * Idempotent: repeated calls return the same instance.
 * @param options - Runtime options (target selection, wasm URL, …).
 */
export async function init(options: InitOptions = {}): Promise<DartBridge> {
  if (cached) return cached;
  cached = await loadBridge(options);
  return cached;
}

/** Reset the cached bridge — useful in tests. */
export function _resetForTests(): void {
  cached = undefined;
}
