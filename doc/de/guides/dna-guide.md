<!--
@license
Copyright (c) ggdna

Use of this source code is governed by terms that can be
found in the LICENSE file in the root of this package.
-->

# DNA-Leitfaden

So wird in dieser Organisation eine DNA-Schicht gebaut. Eine Schicht ist ein
gewöhnliches Paket, dessen Ordner `dna/` handgeschriebene Quelle ist; die
Engine führt ihn mit den darunterliegenden Schichten zusammen und
instanziiert das Ergebnis in das nutzende Repo.

## Eine Schicht anlegen <a id="start-a-layer"></a>

```bash
mkdir dna_<topic> && cd dna_<topic>
gg dna init
```

`gg dna init` legt `dna/_dna.json` und den Test an, der die Engine ausführt.
Ergänze dort `"isLayer": true`, damit der Test die Tags der Abschnitte
prüft (siehe [Nutzern die Anpassung ermöglichen](#let-consumers-adapt-it)).
Alles andere entsteht von Hand.

Eine neue Themenschicht deklariert keinen Parent, aus zwei Gründen.
`dna_ggdna` listet jede Themenschicht auf; eine Schicht, die den Schirm
zurück einbindet, würde also einen Zyklus schließen, und den lehnt die
Engine ab. Außerdem erreichen die Parents einer Schicht jeden Nutzer dieser
Schicht — ein Parent hier würde seinen Inhalt in jedes nachgelagerte Repo
drücken, ob dieses Repo das Thema angefordert hat oder nicht. Halte das
Thema orthogonal; das Zusammensetzen ist Aufgabe des Schirms.

Ein Repo, das selbst keine Themenschicht ist, übernimmt den ganzen Satz auf
einmal:

```bash
gg dna add dna_ggdna
```

## `dna/` aufbauen <a id="lay-out-dna"></a>

`dna/` spiegelt die Wurzel des nutzenden Repos — was unter `dna/x/y` liegt,
wird nach `x/y` instanziiert:

| In der Schicht                     | Instanziiert nach                     |
| ---------------------------------- | ------------------------------------- |
| `dna/LICENSE`                      | `LICENSE`                             |
| `dna/doc/en/guides/x-guide.md`     | `doc/en/guides/x-guide.md`            |
| `dna/dot-vscode/settings.json`     | `.vscode/settings.json`               |
| `dna/dot-claude/skills/x/SKILL.md` | `.claude/skills/x/SKILL.md`           |
| `dna/CLAUDE.md`                    | den verwalteten Block von `CLAUDE.md` |
| `dna/_vars.json`                   | — privat, bleibt drinnen              |

Ein führender Punkt wird als `dot-` maskiert, weil das Veröffentlichen auf
pub jeden Pfad verwirft, der mit einem Punkt beginnt. Jedes Pfadsegment,
das mit `_` beginnt, ist privat und wird nie instanziiert.

## Deklarieren, was sie erbt <a id="declare-what-it-inherits"></a>

`dna/_dna.json` ist der einzige Ort für die DNA-Konfiguration:

```jsonc
{
  "version": 1,
  // Application order — later layers win.
  "layers": ["dna_readme", "dna_guides"],
}
```

Eine Schicht ohne Parents deklariert `"layers": []`. Halte eine
Themenschicht wo möglich orthogonal: Zusammengesetzt wird in den
Schirm-Schichten.

## Die Variablen benennen <a id="name-the-variables"></a>

Jede Variable beginnt mit `dna` und wird als roher Text ersetzt, in jedem
Dateityp. Deklariere die Standardwerte in `dna/_vars.json` und lass den
Nutzer sie überschreiben:

```json
{ "ggdna": "ggdna" }
```

Weil die Ersetzung textuell ist, funktioniert eine Variable auch in einem
JSON-String oder einem Code-Block — `ggdna` in einer Einstellungsdatei
wird genauso ersetzt wie im Fließtext.

## Nutzern die Anpassung ermöglichen <a id="let-consumers-adapt-it"></a>

- Eine Datei mit gleichem Pfad in einer späteren Schicht ersetzt die frühere
  vollständig
- `dna/CLAUDE.md` ist die Ausnahme: Jede Schicht fügt ihre eigene dem
  verwalteten Block der `CLAUDE.md` des Projekts hinzu, in
  Schichtreihenfolge. Schreibe nur, was das eigene Thema der KI sagt; wiederhole
  nie den Text einer anderen Schicht
- `X.overrides.json` führt feldweise zusammen: Objekte werden tief
  zusammengeführt, `"key!"` ersetzt ohne Zusammenführen, `"key+"` hängt an
  ein Array an, `"key": null` löscht
- `X.overrides.md` ersetzt nur die Abschnitte, die eine Markdown-Datei mit
  `## @tag Title` markiert
- Ignore-Dateien (`dot-pubignore`, `dot-gitignore`, `dot-npmignore`,
  `dot-prettierignore`, …) werden zusammengefügt: Liste nur die Pfade, die die
  eigene Schicht ausliefert; das Projekt erhält die Zeilen jeder Schicht
  (siehe [Ignore-Dateien](#ignore-files))

Tagge jeden Abschnitt im Markdown — Leitfäden, Vorlagen, Skills und
`CLAUDE.md` gleichermaßen — mit `## @tag Title`; nur der `#`-Titel oben in
einer Datei bleibt ohne Tag. Welchen Abschnitt eine andere Organisation
ändern will, lässt sich nicht erraten, und erst ein Tag macht eine
Schicht wiederverwendbar statt nur forkbar. Halte einen Tag kurz und
stabil: ein oder zwei Wörter, die das Thema benennen (`@setup`, `@naming`),
eindeutig innerhalb der Datei und gleich in den Übersetzungen der Datei.
Setze `"isLayer": true` in `dna/_dna.json`, dann schlägt der angelegte
Test bei jedem Abschnitt ohne Tag fehl.

## Ignore-Dateien <a id="ignore-files"></a>

Eine Datei, deren Name mit einem Punkt beginnt und auf `ignore` endet, wird
nie von einer späteren Schicht ersetzt: Helix fügt die Zeilen jeder Schicht
zu einer Datei zusammen, ein Abschnitt `# <layer>` pro Schicht in
Schichtreihenfolge, das eigene `dna/` zuletzt. Ein Muster, das ein früherer
Abschnitt bereits enthält, wird weggelassen.

`dna/dot-pubignore` einer Schicht `dna_readme` und einer danach gelisteten
Schicht `dna_scripts`:

```gitignore
/doc/*/guides/
/doc/*/templates/
/scripts/
```

```gitignore
/doc/*/guides/
/scripts/
```

Die `.pubignore` des Projekts:

```gitignore
# .gitignore
.dart_tool/
coverage

# dna_readme
/doc/*/guides/
/doc/*/templates/
/scripts/
```

`dna_scripts` fügt nichts Neues hinzu und erhält daher keinen Abschnitt.

Eine `.pubignore` im Wurzelverzeichnis beginnt mit der `.gitignore` des
Projekts: `dart pub publish` liest die `.pubignore` statt der
`.gitignore`, ohne sie würde also alles veröffentlicht, was git ignoriert.
Liste nie `/dna/` — ein als Schicht genutztes Paket wird aus seinem
veröffentlichten Ordner `dna/` gelesen.

## In beide Registries ausliefern <a id="ship-it-to-both-registries"></a>

Eine Schicht wird aus Dart und aus TypeScript genutzt, daher wird sie aus
demselben Repo zweimal veröffentlicht:

- `pubspec.yaml` — `name: dna_<topic>`, veröffentlicht auf pub.dev
- `package.json` — `name: @<scope>/dna-<topic>`, veröffentlicht auf npm
- `files: ["dna", "README.md", "LICENSE"]` — das Tarball enthält den
  Quellordner, nichts Gebautes

Halte beide Versionen im Gleichschritt: Die Engine warnt, wenn sich die
beiden Kopien einer Schicht unterscheiden, und verwendet die npm-Kopie.

## Prüfen <a id="verify-it"></a>

Der angelegte Test instanziiert die Schicht bei jedem Lauf in ihr eigenes
Repo, sodass die Schicht immer von dem Repo erprobt wird, das sie
ausliefert:

```bash
dart test      # or: pnpm test
gg dna build   # the same run, without a test framework
```

Committe vor einem schreibenden Lauf: Jede vorhandene Datei, die die Engine
überschreiben würde, muss committet sein, damit jedes Überschreiben über
git wiederherstellbar bleibt.
