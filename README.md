# @tssuite/helix-js

The [helix](https://github.com/ggsuite/helix) DNA engine compiled to
WebAssembly — instantiates and verifies a project's DNA from TypeScript
test runs.

DNA packages ship configs, docs, scripts and agent skills into consuming
repos. In Dart projects the placed `test/dna/dna_test.dart` calls helix's
`runDnaTest()` directly. This package brings the _same engine, byte for
byte_ to TypeScript projects: the io-free engine core of helix 5.x is
compiled with `dart compile wasm`, and every file-system / git access is
injected from JavaScript as a callback host.

## Usage — the placed spec

TypeScript projects consuming DNA place a single Vitest spec:

```ts
import { runDnaTest } from '@tssuite/helix-js';

test('dna is instantiated and unmodified', async () => {
  await runDnaTest();
}, 120000);
```

`runDnaTest()` runs one instantiation over the project (default:
`process.cwd()`, override via `runDnaTest({ targetRoot })`) and applies
helix's golden-update semantics:

- **hand-modified instances** → fails, files stay untouched
  (`DNA instances were modified by hand: …`)
- **pending DNA updates** → writes them and fails once
  (`DNA instances updated — review & commit: …`)
- **a file to be overwritten carries uncommitted work** → fails without
  writing and names the files (`DNA installation would overwrite
uncommitted work — commit or stash these files first: …`); unrelated
  dirty files never block a run
- **missing `LICENSE`** → fails
  (`LICENSE is missing — ship it via a DNA layer or add it manually.`)
- otherwise → passes; warnings and adoption messages are printed.

The package bundles helix's own `dna/` folder (`dist/base_dna`) as the
implicit base layer plus its version (`base-version.json`), so the
TypeScript run produces exactly the manifest a Dart run would.

## Architecture

```
lib/src/main.dart        Dart bridge: CallbackDnaHost implements DnaHost by
                         delegating to a JS callback object; DartBridge
                         exposes instantiate(...) on globalThis.dartBridge.
typescript/runtime.ts    Loads + instantiates the wasm module (Node reads
                         the .wasm from disk, browsers fetch it).
typescript/runDnaTest.ts Node host callbacks (node:fs, git) + the outcome
                         semantics of helix's run_dna_test.dart.
typescript/index.ts      Public API + hand-written TypeScript types.
build.dart               dart compile wasm + bundles helix's dna/ folder
                         into typescript/generated/base_dna.
```

Only the io-free parts of helix are imported
(`package:helix/src/engine/instantiate.dart`,
`package:helix/src/util/dna_fs.dart`) — the helix barrel exports
`dart:io`/`dart:isolate` code (IoDnaHost, runDnaTest) that cannot compile
to wasm.

### The callback host contract

The wasm engine performs no I/O itself. The TypeScript side injects a host
object; all paths are posix-separated strings:

```ts
interface DnaHostCallbacks {
  existsFile(path: string): boolean;
  existsDir(path: string): boolean;
  readBytes(path: string): Uint8Array; // throws on missing
  writeBytes(path: string, bytes: Uint8Array): void;
  deleteFile(path: string): void;
  deleteDir(path: string): void;
  createDir(path: string): void;
  rename(from: string, to: string): void;
  listFilesRecursive(dir: string): string[]; // relative posix, files only
  uncommittedPaths(repoRoot: string): string[]; // relative posix
}
```

`runDnaTest()` builds this host with `node:fs` (sync API), recursive
`readdir` without following symlinks, and
`git status --porcelain -uall` (plus `git rev-parse --show-prefix` for
subdirectory checkouts) via `node:child_process`. Custom hosts can call
the lower-level API directly:

```ts
import { init } from '@tssuite/helix-js';
const bridge = await init();
const result = bridge.instantiate(host, targetRoot, baseDnaRoot, '5.0.0');
```

## Building

Prerequisites: Dart SDK ≥ 3.11, Node ≥ 22, pnpm.

```bash
dart pub get
pnpm install
pnpm run build   # clean → sync-version → dart run build.dart → tsc + vite
pnpm test        # dart test + vitest + eslint
```

`dart run build.dart` compiles `lib/src/main.dart` to
`typescript/generated/bridge-wasm.wasm` (+ the generated JS loader wrapped
as `bridge-wasm.ts`) and copies helix's `dna/` folder to
`typescript/generated/base_dna`. The TS build emits `dist/` including
`dist/base_dna` and `dist/bridge-wasm.wasm`.

The Vitest spec `typescript/test/dna-engine.test.ts` skips itself when the
wasm has not been built yet or `dart` is not on the PATH.

The Dart-side bridge unit tests are browser-only and require the dart2wasm
compiler (gg_hash's tree hashing uses `Int64List`, which dart2js does not
support):

```bash
pnpm run test:dart:browser   # dart test -p chrome -c dart2wasm
```

## Relationship to helix and the bridge template

- **helix 5.x** (Dart) owns the engine. Since 5.0 the engine core is
  host-agnostic behind the `DnaHost` seam; this package is the wasm
  consumer of that seam. `pubspec.yaml` uses a workspace path dependency
  (`../../ggsuite/helix`); releases pin the hosted `helix: ^5.0.0`.
- **[tssuite/gg-bridge-dart-typescript](https://github.com/tssuite/gg-bridge-dart-typescript)**
  is the template this repo is derived from: the `build.dart` wasm
  pipeline, the runtime loading machinery, `@JSExport()` +
  `createJSInteropWrapper` + `globalThis.dartBridge`, and the
  pubspec-is-source-of-truth version sync.

## License

MIT — see [LICENSE](LICENSE).
