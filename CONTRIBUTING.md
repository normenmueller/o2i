# Contributing to O2I

Beiträge beginnen mit einem GitHub Issue. Das Issue beschreibt das Problem und
den angestrebten Zustand; Pull Requests setzen ein ausreichend geklärtes Issue
um.

Das öffentliche GitHub Project
[O2I](https://github.com/users/normenmueller/projects/4) dient dem Product
Owner als Planungssicht. Issues bleiben für Arbeitszustand, Abhängigkeiten,
Admission, Reviews und Abschluss maßgebend.

## Arten von Änderungen

### Framework Change

Ein Framework Change verändert Terminologie, Metamodellsemantik, normative
Syntax, Formalisierung, Validierungsverhalten oder einen öffentlichen
API-Vertrag.

Das Issue enthält:

- Problem und betroffene Anwender;
- generischen Nutzen und Passung zu O2I;
- angestrebten Zustand;
- Scope und Non-Goals;
- Akzeptanzkriterien;
- geprüfte Alternativen;
- fachliche, technische und nutzungsbezogene Risiken;
- Autor, Co-Autoren und nicht blockierende Herleitung;
- erforderliche, risikogerechte Reviewfähigkeiten.

Die Umsetzung beginnt erst nach fachlicher und formaler Admission. Ab dem
ersten Admission Review bleibt der Proposal-Inhalt unverändert und ist über
seinen SHA-256 gebunden. Der anschließend erstellte Implementierungsvertrag
steht in einem separaten, ebenfalls digestgebundenen Issue-Kommentar.

### Maintenance

Maintenance umfasst Fehlerkorrekturen und Änderungen an Darstellung, Tooling,
Tests, CI oder Repository-Administration, sofern sie die O2I-Semantik nicht
verändern. Reviewtiefe und Prüfungen richten sich nach dem tatsächlichen
Risiko.

Bei unklarer Einordnung gilt die strengere Einordnung als Framework Change.

## Status

Das GitHub Project `O2I` ist die Planungssicht des Product Owners:

- `Backlog`: erfasst, aber noch nicht ausführungsbereit;
- `Ready`: hinreichend geklärt und entscheidungsreif, aber noch nicht zur
  Umsetzung freigegeben;
- `In progress`: durch den Product Owner freigegebene aktive Umsetzung;
- `Paused`: bewusst ausgesetzt; Grund und Rückkehrbedingung stehen im Issue;
- `In review`: eine exakte Kandidatenrevision wird geprüft;
- `Done`: das Issue ist geschlossen.

Der `Backlog` nimmt eine hinreichend verständliche Idee mit Problem und grobem
Ziel bewusst niederschwellig auf. Er bedeutet weder vollständige
Nutzenbewertung noch Design, Admission oder Implementierungsfreigabe.
Agenten unterstützen die Reifung, indem sie Nutzen, Scope, Risiken,
Abhängigkeiten und Akzeptanzkriterien schärfen, fehlende
Entscheidungsgrundlagen ausweisen und den Übergang zu `Ready` empfehlen. Diese
Vorbereitung ist noch keine Umsetzung.

`Ready` kennzeichnet die Entscheidungsreife für eine Umsetzung: Nutzen, Scope,
Risiken, Abhängigkeiten und Akzeptanzkriterien sind tragfähig. Framework
Changes benötigen zusätzlich die vollständige fachliche und formale Admission;
Maintenance nur eine risikogerechte Prüfung. `Ready` erteilt noch keine
Ausführungsfreigabe. Ausschließlich der Product Owner setzt ein Issue auf
`In progress`; Agenten führen diesen Übergang nicht selbstständig aus und
leiten ihn auch nicht aus dem Issue-Zustand ab.

Ein erforderlicher Blocker innerhalb des O2I-Issue-Graphen wird ausschließlich
als native Issue Dependency modelliert. Eine erforderliche Abhängigkeit
außerhalb dieses Graphen, etwa eine Upstream-Entscheidung, wird mit Quelle und
nächster Prüfbedingung ausdrücklich im betroffenen Issue dokumentiert; ein
eigenes Label ist dafür nicht reserviert. Ein Blocker allein setzt ein Issue
nicht auf `Paused`.

## Repository-Struktur

| Pfad | Verantwortung |
| --- | --- |
| `o2i.md` | aktives White Paper und fachlicher Referenztext |
| `o2i.pdf` | bleeding-edge PDF-Fassung des White Papers |
| `o2i.pdf.manifest.json` | exakte Quellen- und Rendererbindung des PDF |
| `wtf.md` | kurzer, bewusst direkter und nicht normativer Einstieg |
| `acc/` | reproduzierbare TikZ-Quellen der White-Paper-Abbildungen |
| `img/` | gerenderte Abbildungen für White Paper und Modellkommunikation |
| `mdl/` | ArchiMate-Modell, Views und Review-Snapshots |
| `spc/` | Haskell-Spezifikation, Profilvertrag, Inspection und CLI |
| `utl/` | deterministische Repository-, Modell- und Publikationsprüfungen |

Die technische Architektur, Paketstruktur, Installation und Nutzung der
Haskell-Codebasis beschreibt [`spc/README.md`](./spc/README.md).

## White-Paper-Build

Das White Paper und alle TikZ-basierten Abbildungen werden reproduzierbar
erzeugt:

```sh
./toPDF.sh
```

Das Skript rendert zunächst die Quellen aus `acc/` nach `img/`, ruft
anschließend [`md2pdf`](https://github.com/normenmueller/md2pdf) auf und
versiegelt die Quellen- und Rendererbindung in `o2i.pdf.manifest.json`.

## Umsetzung

- Änderungen bleiben im Scope des Issues.
- Neue fachliche Ideen erhalten ein eigenes Issue, bevor sie den Scope ändern.
- Veröffentlichungstexte beschreiben ausschließlich den frischen
  SOLL-Zustand.
- Normative O2I-Designs verwenden keine Workarounds,
  Kompatibilitätsschichten oder Migrationskonstrukte; ein unpassender Kern wird
  kohärent neu entworfen.
- Commit Messages sind kleingeschriebenes Englisch ohne Typpräfix.
- Pull Requests referenzieren ihr Issue und benennen ausgeführte Prüfungen.

## Review

Framework Changes werden von den im Issue benannten unabhängigen Fähigkeiten
geprüft. Ein Review bindet:

- Proposal-Digest oder Plan-Kommentar samt Digest;
- vollständige Git-Revision und Scope beim Finalreview;
- Reviewerfähigkeit und Verdict;
- Findings und ausgeführte Prüfungen;
- Bewertung jeder erforderlichen Qualitätsdimension.

Akzeptierte Reviewkommentare werden nicht editiert. Korrekturen erfolgen als
neuer Kommentar. Ein geänderter Reviewkommentar ist keine gültige
Akzeptanzevidenz.

## Verifikation

Der vollständige lokale Repository-Vertrag verändert keine getrackten
Arbeitsartefakte und lautet:

```sh
./utl/verify.sh
```

Fokussierte Prüfungen mit `governance`, `model`, `haskell` oder `paper` sind
während der Entwicklung zulässig; vor Annahme eines Kandidaten ist der
vollständige Vertrag maßgebend. Die Paper-Stufe prüft zusätzlich die
festgelegte `md2pdf`-Version, Quellenbindung sowie Seiten- und Textstruktur
eines frischen Builds.

GitHub Actions hält alle vier Prüfstatus sichtbar, führt auf Basis einer
konservativen Pfadklassifikation jedoch nur betroffene Stufen aus. Unklare
Änderungen und manuelle Workflow-Aufrufe erzwingen stets die vollständige
Prüfung.

Bei jedem Lauf bestimmt `utl/verification_scope.py` aus dem Git-Diff, welche
Stufen betroffen sind. Die primäre Zuordnung lautet:

| Änderung | Ausgeführte Stufen |
| --- | --- |
| `.ai4X/` oder Governance-Werkzeuge | Governance |
| `mdl/` oder Modellwerkzeuge | Modellverträge |
| `spc/` | Haskell-Spezifikation |
| White-Paper-Quellen oder Rendering | White Paper |
| gemeinsam genutzte, unbekannte oder nicht eindeutig bestimmbare Pfade | alle Stufen |

Gekoppelte Verträge ergänzen diese Primärzuordnung: fachbezogene
`.ai4X/operations/` aktivieren zusätzlich ihre jeweilige Stufe,
`spc/lib/core/src/` zusätzlich das White Paper und
`spc/ctr/archimate/` zusätzlich Modellverträge und White Paper. Die
vollständige ausführbare Matrix liegt ausschließlich im Selektor und seiner
Vertragssuite.

Jeder der vier GitHub-Checks bleibt dabei vorhanden. Eine nicht betroffene
Stufe endet mit einem expliziten erfolgreichen Skip; eine betroffene Stufe
führt unverändert den entsprechenden lokalen `verify.sh`-Vertrag aus. Bei
manuellen Aufrufen, erzwungenen Pushes sowie fehlender oder ungültiger
Diff-Basis gilt stets der vollständige Vertrag. Dadurch bleiben
Branch-Protection und Fehlerverhalten stabil, während unnötige Installationen
und Builds entfallen.

Agentische Ausführung folgt zusätzlich dem hostneutralen Vertrag unter
[`.ai4X/`](./.ai4X/).
