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

Die Werkzeugkette und ihre Versionen sind in
[spec/README.md](../../spec/README.md) und
[verify.yml](../../.github/workflows/verify.yml) beschrieben. Ergänze einmalig
die isolierte Python-Umgebung, den zur CI passenden Formatter und den gebundenen
Renderer aus dem Repository-Stamm:

```sh
python3 -m venv utl/verification/.local/python
utl/verification/.local/python/bin/python -m pip install 'reuse[charset-normalizer]==6.2.0' jsonschema==4.26.0
cabal install hindent-6.2.1 --ignore-project --with-compiler=ghc-9.10.3 --installdir="$PWD/utl/verification/.local/bin" --install-method=copy
md2pdf_revision=$(python3 -B utl/paper/check-pdf-freshness.py contract --root . --field acquisition-revision)
git clone --filter=blob:none --no-checkout https://github.com/normenmueller/md2pdf.git utl/verification/.local/src/md2pdf
git -C utl/verification/.local/src/md2pdf checkout --detach "$md2pdf_revision"
make -C utl/verification/.local/src/md2pdf PREFIX="$PWD/utl/verification/.local" install
```

Die Einrichtung benötigt Downloads und die oben verlinkte Grundwerkzeugkette.
Die Renderer-Revision stammt aus [dem Renderer-Vertrag](../../doc/resources/md2pdf.json).
Der Starter installiert selbst nichts und weist eine fehlende lokale Umgebung
vor dem Prüflauf zurück. Nach Verschieben des Checkouts muss die Python-Umgebung
neu erstellt werden.

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
