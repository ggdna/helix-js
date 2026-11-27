<!--
@license
Copyright (c) ggdna

Use of this source code is governed by terms that can be
found in the LICENSE file in the root of this package.
-->

# Document checkDna and share the engine run

## Motivation

- `checkDna()` is the function a TypeScript project places in
  `test/dna/dna.spec.ts`, but the README still showed `runDnaTest()` there
- `checkDna()` and `runDnaTest()` repeated the same 25 lines: loading the
  Node modules, preparing the base DNA, the host and the bridge call

## Strategy

- Describe the placed check first, then `runDnaTest()` as the way to
  instantiate
- Move the shared part into one function, keep both public functions as
  they are

## README

- "Usage — the placed check" shows the vitest spec with `checkDna()` and
  what it reports: hand edits fail, outstanding updates pass with
  `gg dna build`
- The engine needs Node 24 or newer — older versions cannot compile the
  exception references the Dart compiler emits
- "Instantiating — runDnaTest" keeps the old description of
  `runDnaTest()`

## One engine run

- `runEngine(options, checkOnly)` prepares the target, the base DNA, the
  Node host and the bridge, runs the engine and turns a reported error
  into a readable `Error`
- `runDnaTest()` and `checkDna()` only interpret its result
- No change to the public API or the behavior

## Open Points

- None
