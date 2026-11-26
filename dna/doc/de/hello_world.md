# Hallo DNA

`helix init` hat diese Datei unter `dna/doc/hello_world.md` abgelegt, und
die DNA-Engine instanziiert sie nach `doc/hello_world.md`. Diese beiden
Kopien sind die ganze Idee im Kleinen: `dna/` enthält die zusammengeführte
DNA, das Projekt enthält die daraus erzeugten Instanzen.

## 1. Die Konfiguration: `dna/_dna.json` <a id="1-the-config-dna_dnajson"></a>

Der einzige Ort für die DNA-Konfiguration. `role: "project"` besagt, dass
`dna/` von helix erzeugt wird, und `layers` listet die anzuwendenden
DNA-Pakete auf — in Anwendungsreihenfolge, die letzte Schicht gewinnt.

## 2. Die gewünschten DNA-Pakete hinzufügen <a id="2-add-the-dna-packages-you-want"></a>

DNA-Pakete sind gewöhnliche Pakete. `helix add` installiert eines als
Dev-Dependency und hängt seinen Namen an `layers` an:

```bash
helix add dna_dart                                  # pub package
helix add @tssuite/dna-base                         # npm package
helix add https://github.com/ggsuite/dna_base.git   # git repository
```

Die Abhängigkeit von Hand zu deklarieren funktioniert ebenfalls — dann
muss sie selbst unter `layers` eingetragen werden, denn eine Abhängigkeit,
die nicht gelistet ist, ist keine Schicht.

## 3. Die Tests ausführen — das ist die Engine <a id="3-run-your-tests--that-is-the-engine"></a>

`helix init` hat `test/dna/dna_test.dart` (Dart) oder
`test/dna/dna.spec.ts` (TypeScript) angelegt. Jeder Testlauf instanziiert
die DNA und prüft, dass die Instanzen noch mit ihr übereinstimmen:

```bash
dart test        # or: pnpm test
helix build      # the same run, without a test framework
```

Der erste Lauf schreibt `dna/`, die Instanzen und `dna/_generated.json` und
committet genau diese Dateien als `#gg: generated DNA`.

## 4. Was wo landet <a id="4-what-lands-where"></a>

| In der DNA                     | Instanziiert nach        |
| ------------------------------ | ------------------------ |
| `dna/LICENSE`                  | `LICENSE`                |
| `dna/doc/hello_world.md`       | `doc/hello_world.md`     |
| `dna/dot-vscode/settings.json` | `.vscode/settings.json`  |
| `dna/_vars.json`               | — privat, bleibt drinnen |

Ein führender Punkt wird als `dot-` maskiert, weil das Veröffentlichen auf
pub jeden Pfad verwirft, der mit einem Punkt beginnt. Jedes Pfadsegment,
das mit `_` beginnt, ist privat und wird nie instanziiert.

## 5. Erzeugte Dateien nicht bearbeiten <a id="5-do-not-edit-generated-files"></a>

Eine lokal geänderte Instanz wird in einen Ordner unterhalb des temporären
Systemverzeichnisses kopiert und dann mit dem DNA-Inhalt überschrieben; der
Bericht gibt diesen Sicherungspfad aus. Ändere stattdessen, was eine Schicht
ausliefert:

- eine Datei mit gleichem Pfad in einer späteren Schicht ersetzt die Datei,
- `X.overrides.json` wird feldweise in `X.json` zusammengeführt,
- `X.overrides.md` ersetzt die Abschnitte, die eine Markdown-Datei markiert.

Jede vorhandene Datei, die ein Lauf überschreiben oder löschen würde, muss
vorher committet sein, damit jedes Überschreiben über git
wiederherstellbar bleibt.

## Nächste Schritte <a id="next-steps"></a>

- Trage die eigenen Schichten in `dna/_dna.json` ein.
- Die README von helix ist die vollständige Referenz: Variablen, Overrides,
  der verwaltete `CLAUDE.md`-Block und die Auflösungsregeln.
