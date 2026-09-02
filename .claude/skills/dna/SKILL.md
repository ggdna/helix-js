---
name: dna
description: Checks this DNA layer against the DNA guide and reports what would break for a consumer. Use when the user says "/dna" or asks whether the layer is in shape.
---

<!--
@license
Copyright (c) ggdna

Use of this source code is governed by terms that can be
found in the LICENSE file in the root of this package.
-->

# DNA

Read `doc/guides/dna-guide.md` and follow it.

## 1. Check the layout

Report a path below `dna/` that starts with a literal dot instead of
`dot-`, a private `_` file that the layer expects to be instantiated, and
a file that would land somewhere the consumer does not expect.

## 2. Check the config

Report a `dna/_dna.json` whose `layers` name something that is not a
declared dependency, and a dependency that ships a `dna/` folder but is
missing from `layers` — a dependency that is not listed is not a layer.

## 3. Check the variables

Report an identifier starting with `dna` that no `_vars.json` gives a
value, and a value in `_vars.json` that nothing uses.

## 4. Check both manifests

Report a version mismatch between `pubspec.yaml` and `package.json`, and
a layer listed in one manifest but not in the other — the engine warns
when the two published copies differ.

## 5. Report before fixing

List the findings first. Fix only what the user confirms.
