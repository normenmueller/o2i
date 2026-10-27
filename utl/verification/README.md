# Lokale Prüfungen

Der stabile Einstieg für einen Zwischenstand lautet:

```sh
./utl/verification/local.sh checkpoint
```

Der Starter setzt die lokale Python-Umgebung und das Verzeichnis für temporäre
Prüfdaten und ruft anschließend unverändert `utl/verify.sh` auf. Dort bleiben
Stufenauswahl, Prüfungen und Bereinigung definiert. Ohne Argument wählt der
lokale Starter `checkpoint`; der kanonische Prüfer wählt ohne Argument `all`.
Alle ausdrücklich benannten kanonischen Stufen sind verfügbar.

## Einrichtung

Der Starter benötigt zunächst nur eine lokale Python-Umgebung:

```sh
python3 -m venv utl/verification/.local/python
```

Weitere Werkzeuge werden nur für die tatsächlich gewählten Stufen benötigt.
`utl/verify.sh` prüft diese Voraussetzungen beim Eintritt in die jeweilige Stufe;
`checkpoint` verwendet dafür dieselbe Stufenauswahl wie der kanonische Prüfer.

| Stufe | Zusätzliche Voraussetzungen |
| --- | --- |
| `governance`, `model` | Keine weiteren lokalen Werkzeuge |
| `licensing` | REUSE in der lokalen Python-Umgebung |
| `foundation` | REUSE, Haskell-Werkzeugkette und lokaler hindent |
| `haskell` | Haskell-Werkzeugkette und lokaler hindent |
| `paper` | Lokaler md2pdf und die unten beschriebene Publikationswerkzeugkette |
| `checkpoint`, `all` | Vereinigung der Voraussetzungen ihrer gewählten Stufen |

Unbekannte oder nicht ermittelbare Änderungen wählen weiterhin alle Stufen.
Lokales Python, REUSE, hindent und md2pdf werden bei Bedarf ausdrücklich aus
`.local/` verlangt; fehlende Exemplare ersetzt der Prüfer nicht durch globale Werkzeuge.
Der Starter installiert nichts automatisch.

Die Haskell-Werkzeugkette und ihre Versionen sind in
[spec/README.md](../../spec/README.md) und
[verify.yml](../../.github/workflows/verify.yml) beschrieben. Ergänze REUSE für
die Lizenzprüfung:

```sh
utl/verification/.local/python/bin/python -m pip install 'reuse[charset-normalizer]==6.2.0'
```

Installiere für Haskell-Prüfungen `jsonschema` und den zur CI passenden Formatter:

```sh
utl/verification/.local/python/bin/python -m pip install jsonschema==4.26.0
cabal install hindent-6.2.1 --ignore-project --with-compiler=ghc-9.10.3 --installdir="$PWD/utl/verification/.local/bin" --install-method=copy
```

Die Paper-Prüfung benötigt den gebundenen Renderer. Führe den Clone-Schritt nur
aus, wenn das Quellverzeichnis noch fehlt; eine vorhandene Installation wird aus
derselben gebundenen Revision wiederhergestellt:

```sh
md2pdf_revision=$(python3 -B utl/paper/check-pdf-freshness.py contract --root . --field acquisition-revision)
if [ ! -d utl/verification/.local/src/md2pdf ]; then
  git clone --filter=blob:none --no-checkout https://github.com/normenmueller/md2pdf.git utl/verification/.local/src/md2pdf
fi
git -C utl/verification/.local/src/md2pdf checkout --detach "$md2pdf_revision"
make -C utl/verification/.local/src/md2pdf PREFIX="$PWD/utl/verification/.local" install
```

Für Pandoc und pandoc-crossref bestimmt der White-Paper-Job in
[verify.yml](../../.github/workflows/verify.yml) die verwendeten Versionen.
Installiere dieselben Versionen in `utl/verification/.local/bin`; der Starter
bevorzugt sie gegenüber globalen Homebrew-Werkzeugen. Lade die zu deinem System
passenden Archive aus den offiziellen Releases von
[Pandoc](https://github.com/jgm/pandoc/releases) und
[pandoc-crossref](https://github.com/lierdakil/pandoc-crossref/releases), prüfe
ihre veröffentlichten SHA-256-Prüfsummen und entpacke sie. Übernimm nur die beiden
ausführbaren Programme. Beispiel mit den entsprechend ersetzten Quellpfaden:

```sh
install -m 0755 /pfad/zum/entpackten/pandoc utl/verification/.local/bin/pandoc
install -m 0755 /pfad/zum/entpackten/pandoc-crossref utl/verification/.local/bin/pandoc-crossref
utl/verification/.local/bin/pandoc --version
utl/verification/.local/bin/pandoc-crossref --version
```

Die ausgegebenen Versionen müssen mit dem verlinkten CI-Job übereinstimmen.
Globale Installationen bleiben erhalten. Erzeuge das versionierte Paper mit
dieser lokalen Werkzeugkette und prüfe es anschließend über den normalen Starter:

```sh
PATH="$PWD/utl/verification/.local/bin:$PWD/utl/verification/.local/python/bin:$PATH" ./utl/paper/render-paper.sh
./utl/verification/local.sh paper
```

Weitere Paper-Voraussetzungen sind `pandoc-include`, LaTeX und Poppler; ihre
Installation beschreibt der verlinkte White-Paper-Job. Sie werden für eine reine
Governance- oder Lizenzprüfung nicht benötigt.

Die Einrichtung zusätzlicher Werkzeuge benötigt Downloads und die oben
verlinkte Grundwerkzeugkette.
Die Renderer-Revision stammt aus [dem Renderer-Vertrag](../../doc/resources/md2pdf.json).
Der Starter weist eine fehlende lokale Python-Umgebung vor dem Prüflauf zurück;
weitere fehlende Voraussetzungen meldet die betroffene Stufe. Nach Verschieben
des Checkouts muss die Python-Umgebung neu erstellt werden.

Nach Löschen der Working Copy fehlen diese Installationen im neuen Clone.
Führe dort die Einrichtung erneut aus: Git liefert die Anleitung und die
Versionsbindungen, die Downloads und Installationen erzeugen `.local/` neu.
Temporäre Prüfdaten entstehen beim nächsten Lauf. Benötigte Quellen, Ergebnisse
oder Nachweise dürfen deshalb nie ausschließlich in `.local/` liegen.

## Ablage und Freigabe

- `.local/python/` enthält die wiederherstellbare Werkzeugumgebung.
- `.local/bin/` enthält lokale Werkzeuge mit Vorrang vor globalen Installationen;
  die Einrichtung ersetzt keine globalen Werkzeuge.
- `.local/src/` enthält bezogene Werkzeugquellen; `.local/share/` installierte
  Renderer-Ressourcen.
- `.local/tmp/` enthält getrennte temporäre Prüfläufe; der kanonische Prüfer
  räumt seine Laufverzeichnisse auf.
- Alle liegen ignoriert unter `utl/verification/`, außerhalb des Agentengedächtnisses.

Frische Testverzeichnisse dürfen das umgebende O2I-Repository nicht versehentlich
als ihr eigenes erkennen. Dafür begrenzt der Starter die Git-Suche mit
`GIT_CEILING_DIRECTORIES`; eigene Git-Repositories in Testverzeichnissen bleiben
erkennbar. Diese Einstellung ist keine Sicherheitsgrenze.

Für wiederholte Codex-Aufrufe kann der feste Präfix
`./utl/verification/local.sh checkpoint` dauerhaft freigegeben werden. Die
Freigabe führt den jeweils aktuellen Starter und Prüfer aus; sie erlaubt keine
zusätzliche Veröffentlichung. Umgebungsvariablen und wechselnde Temp-Pfade müssen
nicht vor den Aufruf geschrieben werden.
