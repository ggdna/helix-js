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
Add `"isLayer": true` to it, so the test checks the tags of your sections
(see [Let consumers adapt it](#let-consumers-adapt-it)). Everything else
you write yourself.

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
| `dna/doc/en/guides/x-guide.md` | `doc/en/guides/x-guide.md` |
| `dna/dot-vscode/settings.json` | `.vscode/settings.json` |
| `dna/dot-claude/skills/x/SKILL.md` | `.claude/skills/x/SKILL.md` |
| `dna/CLAUDE.md` | the managed block of `CLAUDE.md` |
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
string or a code fence — `ggdna` in a settings file is replaced the
same way it is in prose.

## Let consumers adapt it

- A same-path file in a later layer replaces yours whole
- `dna/CLAUDE.md` is the exception: every layer adds its own to the
  managed block of the project's `CLAUDE.md`, in layer order. Write only
  what your topic tells the AI; never repeat another layer's text
- `X.overrides.json` merges field-wise: objects deep-merge, `"key!"`
  replaces without merging, `"key+"` appends to an array, `"key": null`
  deletes
- `X.overrides.md` replaces only the sections a markdown file marks with
  `## @tag Title`
- Ignore files (`dot-pubignore`, `dot-gitignore`, `dot-npmignore`,
  `dot-prettierignore`, …) are joined: list only the paths your layer
  ships, the project receives the lines of every layer (see
  [Ignore files](#ignore-files))

Tag every section of your markdown — guides, templates, skills and
`CLAUDE.md` alike — with `## @tag Title`; only the `#` title on top of a
file stays untagged. Which section another organization will want to
change is not yours to guess, and a tag is what makes a layer reusable
instead of forkable. Keep a tag short and stable: one or two words
naming the topic (`@setup`, `@naming`), unique within the file, the same
in the translations of the file. Set `"isLayer": true` in
`dna/_dna.json`, and the placed test fails on every section without one.

## Ignore files

A file whose name starts with a dot and ends with `ignore` is never
replaced by a later layer: Helix joins the lines of every layer into one
file, one `# <layer>` section per layer in layer order, the own `dna/`
last. A pattern an earlier section already holds is left out.

`dna/dot-pubignore` of a layer `dna_readme` and of a layer `dna_scripts`
listed after it:

```gitignore
/doc/*/guides/
/doc/*/templates/
/scripts/
```

```gitignore
/doc/*/guides/
/scripts/
```

The project's `.pubignore`:

```gitignore
# .gitignore
.dart_tool/
coverage

# dna_readme
/doc/*/guides/
/doc/*/templates/
/scripts/
```

`dna_scripts` adds nothing new, so it gets no section.

A root `.pubignore` starts with the project's `.gitignore`: `dart pub
publish` reads the `.pubignore` instead of the `.gitignore`, so without it
everything git ignores would be published. Never list `/dna/` — a package
used as a layer is read from its published `dna/` folder.

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
