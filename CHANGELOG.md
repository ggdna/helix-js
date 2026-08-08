# Changelog

## Unreleased

### Added

- Initial project, derived from tssuite/gg-bridge-dart-typescript.
- gg_dna 5.x engine core compiled to WebAssembly with host access
  injected via JS callbacks (`CallbackDnaHost`).
- `runDnaTest()` for placed Vitest specs, mirroring gg_dna's
  `run_dna_test.dart` outcome semantics.
- Bundled base DNA (`dist/base_dna`) copied from gg_dna's own `dna/`
  folder at build time, together with its version.

### Changed

- Built against gg_dna 5.0: DNA configuration moved from `.gg/dna.json`
  to `dna/_dna.json`, the engine's bookkeeping to `dna/_generated.json`,
  layers are declared explicitly by package name, and dotfiles in DNA
  content are escaped with a `dot-` prefix. Consuming repositories have
  to be migrated — see the gg_dna 5.0 changelog. The bridge API itself
  is unchanged.
- The import name in the docs and in the wrapper spec `gg_dna init`
  places is now `@tssuite/gg_dna-js`, matching what is actually
  published. It read `@tssuite/gg-dna` before, so the generated spec did
  not resolve.

### Fixed

- Engine failures reached the caller as `[object WebAssembly.Exception]`
  with no message. The bridge now returns failures as `{ error }`
  (`DnaBridgeError`) instead of throwing them across the wasm boundary,
  and `runDnaTest()` rethrows them as a plain `Error`.
- `build.dart` now fails when the resolved gg_dna ships no
  `dna/dot-claude`. A gg_dna installed from pub used to lose its agent
  skills to pub's dotfile stripping, and the published bundle carried a
  base DNA without any skills — silently.
