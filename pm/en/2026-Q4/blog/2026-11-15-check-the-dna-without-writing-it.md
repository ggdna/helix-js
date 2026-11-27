<!--
@license
Copyright (c) ggdna

Use of this source code is governed by terms that can be
found in the LICENSE file in the root of this package.
-->

# Check the DNA without writing it

## Motivation

- `runDnaTest` does more than test: it writes DNA updates, backs up
  hand-edited instances, overwrites them and commits the result as
  `#gg: generated DNA`. A test run should not change the project
- A TypeScript project needs a test that only answers one question: are
  the files the DNA generated still unchanged?

## Strategy

- Keep one engine: the check runs the same wasm-compiled helix as
  `runDnaTest`, in a mode that plans the run and writes nothing
- Add `checkDna()` next to `runDnaTest()`, with the same options and the
  same Node host
- Report with the same colors and the same "Move edits from … to …" lines

## The bridge

- `DartBridge.instantiate` takes an optional fifth argument `checkOnly`
- The result carries two new lists: `modified` — generated files changed
  by hand — and `pending` — paths the DNA would write or delete
- `DnaInstantiationResult` in `typescript/index.ts` declares both

## checkDna

- Throws on `modified`, headline _Generated DNA files were changed by
  hand:_, one line per file with the DNA file the edit belongs in
- Logs `pending` with `gg dna build` as the way to apply it, and passes
- Writes no file, makes no backup and commits nothing
- Exported from the package together with `modifiedDnaMessage`

```ts
import { checkDna } from '@tssuite/helix-js';
import { test } from 'vitest';

test('generated dna files are unchanged', async () => {
  await checkDna();
}, 120000);
```

## Tests

- Two new end-to-end cases in `dna-engine.test.ts` run against a real git
  fixture: an unchanged project passes, a hand edit fails and stays,
  outstanding updates are reported and nothing is written
- Running the wasm bundle needs Node 24 or newer: older versions cannot
  compile the exception references the Dart compiler emits

## Dependency updates

- helix: `instantiateDna(checkOnly: true)` and the result fields
  `modified` and `pending`, which the bridge passes on

## Open Points

- `runDnaTest` stays for callers that want to instantiate from a test
