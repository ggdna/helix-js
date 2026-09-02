<!--
@license
Copyright (c) ggdna

Use of this source code is governed by terms that can be
found in the LICENSE file in the root of this package.
-->

# DNA Guide

How a DNA layer is built in this organization. A layer is an ordinary
package whose `dna/` folder is hand-authored source; the engine merges it
with the layers below and instantiates the result into the consuming
repo.

## Start a layer

```bash
mkdir dna_<topic> && cd dna_<topic>
gg dna init
```

`gg dna init` places `dna/_dna.json` and the test that runs the engine.
Everything else you write yourself.

A new topic layer declares no parent, for two reasons. `dna_ggdna` lists
every topic layer, so a layer that took the umbrella back would close a
cycle and the engine refuses that. And a layer's parents reach every
consumer of that layer — a parent here would push its content into every
repo downstream, whether that repo asked for the topic or not. Keep the
topic orthogonal; composing is what the umbrella is for.

A repo that is not itself a topic layer takes the whole set in one go:

```bash
gg dna add dna_ggdna
```

## Lay out `dna/`

`dna/` mirrors the root of the consuming repo — what sits at `dna/x/y`
is instantiated to `x/y`:

| In the layer | Instantiated to |
| --- | --- |
| `dna/LICENSE` | `LICENSE` |
| `dna/doc/guides/x-guide.md` | `doc/guides/x-guide.md` |
| `dna/dot-vscode/settings.json` | `.vscode/settings.json` |
| `dna/dot-claude/skills/x/SKILL.md` | `.claude/skills/x/SKILL.md` |
| `dna/_vars.json` | — private, stays inside |

A leading dot is escaped as `dot-`, because publishing to pub drops every
path that starts with a dot. Any path segment starting with `_` is
private and never becomes an instance.

## Declare what it inherits

`dna/_dna.json` is the only place DNA configuration lives:

```jsonc
{
  "version": 1,
  // Application order — later layers win.
  "layers": ["dna_readme", "dna_guides"]
}
```

A layer with no parents declares `"layers": []`. Keep a topic layer
orthogonal where you can: it is the umbrella layers that compose.

## Name the variables

Every variable starts with `dna` and is substituted as raw text, in any
file type. Declare the defaults in `dna/_vars.json` and let the consumer
override them:

```json
{ "ggdna": "ggdna" }
```

Because substitution is textual, a variable also works inside a JSON
string or a code fence — `ggsuite` in a settings file is replaced the
same way it is in prose.

## Let consumers adapt it

- A same-path file in a later layer replaces yours whole
- `X.overrides.json` merges field-wise: objects deep-merge, `"key!"`
  replaces without merging, `"key+"` appends to an array, `"key": null`
  deletes
- `X.overrides.md` replaces only the sections a markdown file marks with
  `## @tag Title`

Mark the sections of your guides that another organization will plausibly
want to change — that is what makes a layer reusable instead of forkable.

## Ship it to both registries

A layer is consumed from Dart and from TypeScript, so it is published
twice from the same repo:

- `pubspec.yaml` — `name: dna_<topic>`, published to pub.dev
- `package.json` — `name: @<scope>/dna-<topic>`, published to npm
- `files: ["dna", "README.md", "LICENSE"]` — the tarball carries the
  source folder, nothing built

Keep both versions in step: the engine warns when the two copies of one
layer differ, and uses the npm one.

## Verify it

The placed test instantiates the layer into its own repo on every run, so
the layer is always exercised by the repo that ships it:

```bash
dart test      # or: pnpm test
gg dna build   # the same run, without a test framework
```

Commit before a run that writes: every existing file the engine would
overwrite has to be committed, so each overwrite stays recoverable
through git.
