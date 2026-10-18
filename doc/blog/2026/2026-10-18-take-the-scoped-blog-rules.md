<!--
@license
Copyright (c) ggdna

Use of this source code is governed by terms that can be
found in the LICENSE file in the root of this package.
-->

# Take the scoped blog rules

## Motivation

- `helix-js` takes its guides, templates and skills from its
  organization layer `dna_ggdna`.
- That layer now carries new blog rules: one post per repo, describing
  only that repo. `helix-js` still had the old rule of one post per
  ticket.
- The goal: posts of `helix-js` describe `helix-js` alone and stand on
  their own next to its code.

## Strategy

- Take the new version of `dna_ggdna`
- Let the DNA test instantiate the new guides into this repo and verify
  them
- No code changes

## Implementation 1: The instantiated guides

- The blog guide, the blog template and the `/blog` skill are
  regenerated: posts go to `doc/blog/<yyyy>` and describe only this repo
- The development guide asks for a post in every repo of a ticket that
  has the blog guide
- The code, test, vscode and install guides and their skills are
  regenerated from the current topic layers as well
- This post is the first one of this repo written under the new rules

## Dependency updates

- `dna_ggdna`: carries `dna_blog` 0.3.0, `dna_translate` 0.3.0 and
  `dna_gg` 0.10.0; for `helix-js` that means scoped blog posts under
  `doc/blog/<yyyy>` and a post per repo at publish time

## Open Points

- None
