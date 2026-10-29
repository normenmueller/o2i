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

Beginne in einem Clone deines Forks mit [Git](https://git-scm.com/downloads),
[Python 3](https://www.python.org/downloads/) einschließlich `venv` und einer
POSIX-Shell. Alle folgenden Befehle laufen im Repository-Wurzelverzeichnis.
Für die über Git LFS gespeicherten PNG- und PDF-Dateien benötigst du zusätzlich
[Git LFS](https://git-lfs.com/):

```sh
git lfs install --local
git lfs pull
```

Der lokale Starter benötigt zunächst nur eine Python-Umgebung:

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

Für Haskell installierst du zunächst [GHCup nach der offiziellen
Anleitung](https://www.haskell.org/ghcup/install/) einschließlich der dort
genannten Betriebssystemvoraussetzungen. Wähle anschließend die vom Projekt
verlangten Versionen aus:

```sh
ghcup install ghc 9.10.3
ghcup install cabal 3.16.1.0
ghcup set ghc 9.10.3
ghcup set cabal 3.16.1.0
ghc --numeric-version
cabal --numeric-version
```

Die letzten beiden Befehle müssen `9.10.3` und `3.16.1.0` ausgeben. Die
Auswahl erfolgt über GHCup; der Formatter benötigt keinen eigenen Compiler.
[spec/README.md](../../spec/README.md) beschreibt die Pakete,
[verify.yml](../../.github/workflows/verify.yml) bindet die CI-Werkzeuge.
Ergänze REUSE für die Lizenzprüfung:

```sh
utl/verification/.local/python/bin/python -m pip install 'reuse[charset-normalizer]==6.2.0'
```

Installiere für Haskell-Prüfungen `jsonschema`:

```sh
utl/verification/.local/python/bin/python -m pip install jsonschema==4.26.0
```

Der Formatter ist Hindent 6.3.0. Unter macOS verwenden wir die ursprüngliche,
ungepatchte [Homebrew-Bottle vom 25. Januar 2026](https://github.com/Homebrew/homebrew-core/blob/5971856bb4f75779f111715efdff49a70c5967db/Formula/h/hindent.rb).
Spätere Homebrew-Builds derselben Versionsnummer entfernen strikte GADT-Felder
und verändern damit Haskell-Semantik. Die folgende geprüfte Bottle gilt für
Apple Silicon ab macOS 26 und benötigt keine Homebrew-Installation oder
Relokation. Andere Plattformarchive sind in der verlinkten historischen
Formula dokumentiert; ihre Laufzeitverträglichkeit ist hier nicht geprüft.

```sh
(
set -eu
test "$(uname -s)/$(uname -m)" = Darwin/arm64
macos_version=$(sw_vers -productVersion)
test "${macos_version%%.*}" -ge 26
hindent_bottle_sha256='5b3d7317ba8d50474ca4075b3a1964fcf3f97b24faf92b1543a63b88e19342ff'
hindent_directory=$(mktemp -d)
trap 'rm -rf "$hindent_directory"' EXIT
hindent_token=$(python3 -c 'import json, urllib.request; print(json.load(urllib.request.urlopen("https://ghcr.io/token?service=ghcr.io&scope=repository:homebrew/core/hindent:pull"))["token"])')
hindent_archive="$hindent_directory/hindent.bottle.tar.gz"
curl --fail --location --retry 3 \
  --header "Authorization: Bearer $hindent_token" \
  "https://ghcr.io/v2/homebrew/core/hindent/blobs/sha256:$hindent_bottle_sha256" \
  --output "$hindent_archive"
printf '%s  %s\n' "$hindent_bottle_sha256" "$hindent_archive" | shasum -a 256 --check --status
tar -xOf "$hindent_archive" hindent/6.3.0/bin/hindent >"$hindent_directory/hindent"
mkdir -p utl/verification/.local/bin
install -m 0755 "$hindent_directory/hindent" utl/verification/.local/bin/hindent
test "$(utl/verification/.local/bin/hindent --version)" = "hindent 6.3.0"
)
```

Für Linux x86_64 verwendet die CI das offizielle
[Release-Executable](https://github.com/mihaimaruseac/hindent/releases/tag/v6.3.0).
Prüfe dessen gebundene SHA-256-Prüfsumme vor Installation und Ausführung:

```sh
(
set -eu
test "$(uname -s)/$(uname -m)" = Linux/x86_64
hindent_version=6.3.0
hindent_sha256='9b359816c72df2039ee9b88f70c6b70e8dd20008cbef315291d01fbfa3897cfa'
hindent_download=$(mktemp)
trap 'rm -f "$hindent_download"' EXIT
curl --fail --location --retry 3 \
  "https://github.com/mihaimaruseac/hindent/releases/download/v$hindent_version/hindent" \
  --output "$hindent_download"
printf '%s  %s\n' "$hindent_sha256" "$hindent_download" | sha256sum --check --status
mkdir -p utl/verification/.local/bin
install -m 0755 "$hindent_download" utl/verification/.local/bin/hindent
test "$(utl/verification/.local/bin/hindent --version)" = "hindent 6.3.0"
)
```

GHC und Cabal bleiben bei ihren bestehenden Versionen; ein Quellbau des
Formatters ist nicht erforderlich. Die normale Haskell-Prüfung verlangt die
exakte Formatter-Version und prüft vor der Generierung, dass der Formatter
strikte GADT-Felder unverändert erhält. Prüfe zusätzlich sämtliche Haskell-Quellen mit dem
lokalen Programm; dieselbe Prüfung läuft mit dem Linux-Executable in CI:

```sh
find spec -path '*/dist-newstyle' -prune -o \
  -type f -name '*.hs' \
  -exec "$PWD/utl/verification/.local/bin/hindent" --line-length 80 --validate {} +
```

Damit müssen beide Plattformen dieselben eingecheckten Dateien unverändert
akzeptieren. Globale Werkzeuge ersetzen die isolierte Installation nicht.

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

## Haskell-Laufzeiten und Diagnoseausgabe

Die Haskell-Prüfung weist Build und Testaufruf getrennt aus. Dasselbe gilt für
die Vorbereitung der Quellarchive sowie Build und Testaufruf aus frisch
entpackten Quellen in einem eigenen Build-Verzeichnis. Die bestehenden
Prüfungen bleiben erhalten; beide Paketumfänge prüfen dieselben Haddock-Warnungen.
Ein Cabal-Testaufruf kann Planung oder Neuaufbau enthalten und misst deshalb
keine reine Testausführungszeit.

Die gekennzeichnete monotone Uhr liefert bei fehlenden oder ungültigen Werten
`UNKNOWN`; es gibt keinen stillen Wechsel zur Systemzeit. Für Vergleiche müssen
Uhr, Rechnerbedingungen, Werkzeuge und Abhängigkeitszustand vergleichbar sein.
Rechner-Ruhezeiten werden je nach Plattform unterschiedlich behandelt.
Der Prüfer meldet angeforderte Compiler- und Scheduling-Optionen. Nicht
beobachtete effektive Einstellungen bleiben `UNKNOWN`.

Cabals natives `--semaphore` koordiniert Modul- und Komponentenkompilierung bei
Build, Test und Haddock innerhalb des bereits konfigurierten Jobs-Budgets. Der
Prüfer überschreibt diese Jobzahl nicht. Leise Planungs- und API-Abfragen
behalten dieselbe `-Werror`-Konfiguration. Das gemeinsame interne Core-Testprogramm
kann zur Laufzeit mehr Spitzenspeicher benötigen; das Compiler-Scheduling
verringert diese Laufzeitkosten nicht.

`O2I_HASKELL_CABAL_VERBOSITY` erlaubt `1` als Vorgabe oder `2` für ausführlichere
Build-, Test- und Haddock-Ausgaben. Maschinenlesbare Abfragen bleiben leise.
Halte diese Diagnoseausgabe fest, wenn tatsächliche Compileraufrufe oder der
effektive native Jobs-Pool untersucht werden sollen. Die Ausgabestufe ändert
weder Prüfumfang noch Optimierung, Scheduling, Abhängigkeiten oder die Trennung
der Archivprüfung.

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
