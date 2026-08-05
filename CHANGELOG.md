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
