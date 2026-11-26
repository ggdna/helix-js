<!--
@license
Copyright (c) ggdna

Use of this source code is governed by terms that can be
found in the LICENSE file in the root of this package.
-->

# Update the DNA to Language Folders

## Motivation

- The DNA of this repo now keeps documentation per language:
  `doc/<lang>/` without a quarter, `pm/<lang>/<yyyy>-Q<n>/` for everything
  planned. This repo only regenerated its DNA; its engine code is
  unchanged.
- The update also brings the DNA from an older state up to the current
  layers, with their newer skills and guides.

## Strategy

- Raise the DNA layers to their new versions
- Regenerate the DNA and commit the instances as they come
- Change nothing by hand in the WebAssembly engine or its JavaScript host

## Implementation 1: Docs per language

- All generated guides moved from `doc/guides/` to `doc/en/guides/`, the
  templates to `doc/en/templates/`
- Every guide also arrived in German and Farsi under `doc/de/` and
  `doc/fa/`; the German blog template is now
  `doc/de/templates/blog-template.md`
- `.prettierignore` and `.pubignore` cover `doc/*/guides/` and
  `doc/*/templates/`

## Implementation 2: Skills and scripts

- Every skill reads its guide from `doc/en/guides/`; `/blog` writes to
  `pm/<lang>/<yyyy>-Q<n>/blog`, `/translate` syncs all languages set by
  `dnaLanguages`
- New `/gg-review-architecture` skill and `doc/en/guides/architecture-guide.md`
- `/gg-ticket` derives a slug id from one question, `/gg-commit` checks
  and commits all ticket repos at once, `/gg-publish` runs from the
  workspace root with `-i <ticket>`
- `scripts/check-readme.js` checks `README.<lang>.md` for every language
- `scripts/functions/` now import `execSync` and `red` where they use them
- The pm-prompts hook and its `.claude/settings.json` are no longer
  generated and were removed
- `install-corepack-guide.md` gave way to `install-pnpm-guide.md`

## Dependency updates

- helix base 1.15.2 → 1.18.0, dna_ggdna 1.0.0 → 1.0.1, dna_gg
  1.0.0 → 1.9.2, and all topic layers raised to their current versions

## Open Points

- None in the engine; hand-written docs outside the DNA were not moved
