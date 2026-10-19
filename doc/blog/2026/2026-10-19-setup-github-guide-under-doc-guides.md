<!--
@license
Copyright (c) ggdna

Use of this source code is governed by terms that can be
found in the LICENSE file in the root of this package.
-->

# Setup github guide under doc/guides

## Motivation

- The `Tests` workflow of `helix-js` failed on `main`: `prettier --check .`
  rejected `guides/setup-github-guide.md`.
- The file came from the DNA, sat in a top-level `guides/` folder instead
  of `doc/guides/`, and ended a line with a trailing space. The generated
  `doc/guides/` is excluded from the format check, `guides/` was not.
- The goal: a green `Tests` workflow and one place for all guides.

## Strategy

- Take the fixed setup github guide through `dna_ggdna`
- Let the DNA test instantiate it and remove the old file
- No code changes

## Implementation 1: The new place

- The DNA test instantiates `doc/guides/setup-github-guide.md`
- It removes `guides/setup-github-guide.md`, which is no longer produced,
  and the then empty `guides/` folder
- `prettier --check .` passes on the whole repo again

## Implementation 2: Other regenerated files

- The development guide and the `/gg`, `/gg-publish` skills are
  regenerated from the current layers, which also add `/gg-review`

## Dependency updates

- `dna_ggdna`: carries the setup github guide under `doc/guides/` and
  without trailing whitespace, and the current development guide and gg
  skills

## Open Points

- None
