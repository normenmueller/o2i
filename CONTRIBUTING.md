# Contributing to O2I

Beiträge beginnen mit einem GitHub Issue. Das Issue beschreibt das Problem und den angestrebten Zustand; Pull Requests setzen ein ausreichend geklärtes Issue um.

Das öffentliche GitHub Project [O2I](https://github.com/users/normenmueller/projects/4) bildet Arbeitszustand und PO-Reihenfolge ab. Issues bleiben für Vertrag, Abhängigkeiten, Admission, Reviews sowie offenen oder geschlossenen Zustand maßgebend.

Für die Aufnahme ins Backlog genügt eine verständliche Idee mit Problem und grobem Ziel. Ein Agent bewertet kurz O2I-Passung, erwarteten Nutzen, mögliche Dopplungen, Änderungsklasse und Labels und erfasst einen geeigneten Vorschlag ohne Design- oder Umsetzungsfreigabe.

## Arten von Änderungen

### Framework Change

Ein Framework Change verändert Terminologie, Metamodellsemantik, normative Syntax, Formalisierung, Validierungsverhalten oder einen öffentlichen API-Vertrag.

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

Die Umsetzung beginnt erst nach fachlicher und formaler Admission. Ab dem ersten Admission Review bleibt der Proposal-Inhalt unverändert und ist über seinen SHA-256 gebunden. Der anschließend erstellte Implementierungsvertrag steht in einem separaten, ebenfalls digestgebundenen Issue-Kommentar. Ein Digest ist der kleingeschriebene SHA-256 der vom GitHub API gelieferten UTF-8-Bytes ohne Normalisierung oder zusätzliches Zeilenende; bei Kommentaren gehört die Kommentar-ID zur Evidenz.

### Maintenance

Maintenance umfasst Fehlerkorrekturen und Änderungen an Darstellung, Tooling, Tests, CI oder Repository-Administration, sofern sie die O2I-Semantik nicht verändern. Reviewtiefe und Prüfungen richten sich nach dem tatsächlichen Risiko.

Bei unklarer Einordnung gilt die strengere Einordnung als Framework Change.

Maintenance benötigt weder Framework Admission noch Admission-Digest. Ein Advisory Review ist optional und niemals Freigabe oder Gate-Evidenz. Jeder exakte Maintenance-Kandidat erhält vor seiner Annahme mindestens einen unabhängigen externen Finalreviewer, dessen Fähigkeit zum tatsächlichen Änderungsrisiko passt. Ein weiterer Reviewer kommt nur für ein materiell anderes Risiko hinzu, das der bereits ausgewählte Reviewer nicht glaubwürdig beurteilen kann; eine feste Reviewer-Matrix, -Anzahl oder Auswahlmechanik gibt es nicht.

Der Finalreview bindet Revision und Scope und dokumentiert Auswahlbegründung, Findings, Prüfungen und Bewertungen. Jedes Finding verwirft den exakten Kandidaten und verlangt den Review einer korrigierten Revision. Die Annahme erfordert kein Finding und 10,0 in jeder ausgewählten Dimension. Ein möglicher Einfluss auf O2I-Semantik, normative Syntax, Formalisierung, Validierungsverhalten oder öffentliche APIs verlangt stattdessen die erneute Einordnung als Framework Change.

## Status

Das GitHub Project `O2I` ist die Planungssicht des Product Owners:

- `Backlog`: verständliche Idee, noch nicht aufbereitet;
- `Refined`: vollständig konsolidiert und entscheidungsreif, aber noch nicht freigegeben;
- `Ready`: offen, vollständig vorbereitet, ohne blockierende Voraussetzung und durch den Product Owner ausdrücklich zur Umsetzung freigegeben;
- `In progress`: aus `Ready` aktivierte Umsetzung;
- `Paused`: bewusst ausgesetzt; Grund und Rückkehrbedingung stehen im Issue;
- `In review`: eine exakte Kandidatenrevision wird geprüft;
- `Done`: akzeptiert, remote verfügbar, erforderlichenfalls remote verifiziert und geschlossen.

Vor `Backlog -> Refined` lesen Agenten den vollständigen Issue-Body und sämtliche vorhandenen Kommentare. Sie führen die akzeptierten Inhalte zu einem eindeutigen Vertrag zusammen; widersprüchliche oder überholte Aussagen benötigen eine ausdrückliche Entscheidung des Product Owners. Diese Aufbereitung ist noch keine Umsetzung.

Ausschließlich der Product Owner verschiebt `Refined -> Ready` und erteilt damit die Ausführungsfreigabe. Ab `Ready` steuern Agenten Aktivierung, Review, Korrekturen und Abschluss innerhalb des freigegebenen Vertrags. Die Reihenfolge in `Ready` bestimmt die Abarbeitungsfolge, sofern der Product Owner keine andere Reihenfolge oder Parallelisierung freigibt.

```text
Backlog -- Reifung --> Refined -- PO-Freigabe --> Ready -- Aktivierung --> In progress
                                                       ^                       |
                                                       |                       +-- Pause --> Paused
                                                       |                                       |
                                                       +-- Rückkehrbedingung erfüllt ----------+

In progress -- Kandidat vollständig --> In review -- akzeptiert --> Done
    ^                                      |
    +--------------- Findings -------------+
```

Vertikale Reihenfolge bedeutet Aufbereitungspriorität in `Backlog`, Entscheidungspriorität in `Refined` und autorisierte Abarbeitungsfolge in `Ready`. Die Reihenfolge aller anderen Spalten hat keine Workflow-Bedeutung.

Echte Voraussetzungen innerhalb des O2I-Issue-Graphen werden ausschließlich als native Issue Dependencies modelliert. Eine erforderliche Abhängigkeit außerhalb dieses Graphen wird mit Quelle und nächster Prüfbedingung im betroffenen Issue dokumentiert. Project-Reihenfolge ersetzt keine Abhängigkeit; ein Blocker allein setzt ein Issue nicht auf `Paused`.

Benannte Umsetzungsbatches werden nach Aktivierung des Parent Issues durch genau je ein direktes GitHub Sub-Issue sichtbar gemacht. Ohne einen ausdrücklich batchbasierten Implementierungsvertrag entstehen keine Sub-Issues. Bei Maintenance ist der Parent-Body der Implementierungsvertrag; bei Framework Changes bleibt der separate Implementierungsvertragskommentar autoritativ. Der Body jedes Sub-Issues enthält nur den Parent-Link, gegebenenfalls den Link auf diesen Vertragskommentar, Liefergegenstand und übernommene Abschlussbedingungen des Batches sowie die feste Notiz, dass das Sub-Issue genau einen autorisierten Batch sichtbar macht, weder Scope noch Autorisierung ergänzt und der Parent autoritativ bleibt. Batch-ID und Batchname werden ausschließlich im nativen GitHub-Issue-Titel geführt. Die Zuweisung wird ausschließlich in nativen GitHub-Assignee-Metadaten geführt. Das Sub-Issue bleibt außerhalb des O2I Projects und besitzt keine eigene Freigabe-, Scope-, Abhängigkeits-, Review- oder Annahmeautorität über den Parent. Weitere Ebenen sind ausgeschlossen, und die Hierarchie ersetzt keine native Issue Dependency.

Jedes Batch Sub-Issue besitzt seinen eigenen Open/Closed-Zustand. Seine Schließung dokumentiert ausschließlich den Abschluss des Batches und bewirkt weder Annahme noch Schließung des Parents. Lifecycle-Kommentare dürfen nur einen Blocker- oder Pausengrund, dessen Rückkehrbedingung sowie Implementierungs- oder Verifikationsevidenz festhalten. Der Parent darf erst nach Schließung aller erforderlichen Batch Sub-Issues in `In review` wechseln. Neue Inhalte werden niemals in ein Sub-Issue aufgenommen, sondern durchlaufen den regulären Refinement- und Freigabeweg.

Vor `In review` sind release-relevante Hinweise ergänzt und der vollständige Kandidat committed. Nach Annahme wird exakt diese Revision veröffentlicht und verifiziert. Findings führen zurück zu `In progress`; ein vom Product Owner verworfenes Vorhaben wird als `not planned` geschlossen und sein Project-Eintrag archiviert.

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

Die technische Architektur, Paketstruktur, Installation und Nutzung der Haskell-Codebasis beschreibt [`spc/README.md`](./spc/README.md).

## White-Paper-Build

Das White Paper und alle TikZ-basierten Abbildungen werden reproduzierbar erzeugt:

```sh
./toPDF.sh
```

Das Skript rendert zunächst die Quellen aus `acc/` nach `img/`, ruft anschließend [`md2pdf`](https://github.com/normenmueller/md2pdf) auf und versiegelt die Quellen- und Rendererbindung in `o2i.pdf.manifest.json`.

## Attribution

Agentisch erstellte Commits führen den transparenten Machine User [`gertrud-ai4x`](https://github.com/gertrud-ai4x) als Autorin und den verantwortlichen Menschen als Committer. Gertrud wird einem Issue zugewiesen, sobald sie materielle Verantwortung für dessen Refinement, Koordination oder Umsetzung übernimmt; reine Advisory-Beteiligung genügt nicht. Agentische Issue-Kommentare und Board-Übergänge ab `Ready` erfolgen über diesen Account; PO-Freigaben, Releases und andere verantwortliche Entscheidungen bleiben dem Product Owner zugeordnet. Der Machine User kann unabhängige Review-Evidenz veröffentlichen, ersetzt oder imitiert jedoch keinen Reviewer.

## Umsetzung

- Änderungen bleiben im Scope des Issues.
- Neue fachliche Ideen erhalten ein eigenes Issue, bevor sie den Scope ändern.
- Veröffentlichungstexte beschreiben ausschließlich den frischen SOLL-Zustand.
- Normative O2I-Designs verwenden keine Workarounds, Kompatibilitätsschichten oder Migrationskonstrukte; ein unpassender Kern wird kohärent neu entworfen.
- Commit Messages sind kleingeschriebenes Englisch ohne Typpräfix.
- Issue-bezogene Commits führen `Refs #N` im Commit-Body; `Closes #N` bleibt dem tatsächlich abschließenden Commit vorbehalten.
- Pull Requests referenzieren ihr Issue und benennen ausgeführte Prüfungen.

## Review

Framework Changes werden von den im Issue benannten unabhängigen Fähigkeiten geprüft. Ein Review bindet:

- Issue-Body-Digest für Admission;
- ID und Digest des Implementierungsvertrags-Kommentars für Finalreview;
- vollständige Git-Revision und Scope beim Finalreview;
- Reviewerfähigkeit und Verdict;
- Findings und ausgeführte Prüfungen;
- Bewertung jeder erforderlichen Qualitätsdimension.

Maintenance-Finalreviews benötigen keinen Admission-Digest und keinen separaten Implementierungsvertrags-Kommentar. Sie binden die vollständige Revision und den Scope und dokumentieren die ausgewählte Reviewerfähigkeit, die knappe Risikobegründung, Findings, Prüfungen und Bewertungen.

Reviewer bewerten kritisch, neutral, objektiv und unabhängig. Ein Review ist keine Annahmeautomatik: Begründete Einwände, Verbesserungen oder materiell bessere Alternativen hinsichtlich Leanheit, Klarheit, Eleganz, Robustheit, Modularität oder Nutzen führen zur Ablehnung des Kandidaten.

Akzeptierte Reviewkommentare werden nicht editiert. Korrekturen erfolgen als neuer Kommentar. Ein geänderter Reviewkommentar ist keine gültige Akzeptanzevidenz.

## Verifikation

Der vollständige lokale Repository-Vertrag verändert keine getrackten Arbeitsartefakte und lautet:

```sh
./utl/verify.sh
```

Fokussierte Prüfungen mit `licensing`, `governance`, `model`, `haskell` oder `paper` sind während der Entwicklung vorgesehen. Die Lizenzstufe setzt den offiziellen REUSE-Validator 6.2.0 voraus; er kann mit `pipx install "reuse[charset-normalizer]==6.2.0"` installiert werden. Sie prüft jeden getrackten Pfad und ist deshalb bei jeder Änderung aktiv. Vor jedem Commit müssen mindestens alle von der Pfadmatrix betroffenen Stufen lokal erfolgreich sein; bei unbekannter oder gemeinsam genutzter Vertragsfläche gilt der vollständige Vertrag. Vor jedem Release-Tag ist `./utl/verify.sh` vollständig auszuführen. Die Paper-Stufe prüft zusätzlich die festgelegte `md2pdf`-Version, Quellenbindung sowie Seiten- und Textstruktur eines frischen Builds.

Direkte Branch-Pushes lösen keine GitHub Actions aus. Remote-Verifikation läuft ausschließlich für Pull Requests, manuelle Workflow-Aufrufe und Release-Tags mit dem Muster `o2i-v*`.

Bei jedem Lauf bestimmt `utl/verification/verification_scope.py` aus dem Git-Diff, welche Stufen betroffen sind. Die primäre Zuordnung lautet:

| Änderung | Ausgeführte Stufen |
| --- | --- |
| jeder getrackte Pfad | Repository-Lizenzierung |
| `.ai4X/` oder Governance-Werkzeuge | Governance |
| `mdl/` oder Modellwerkzeuge | Modellverträge |
| `spc/` | Haskell-Spezifikation |
| White-Paper-Quellen oder Rendering | White Paper |
| gemeinsam genutzte, unbekannte oder nicht eindeutig bestimmbare Pfade | alle Stufen |

Gekoppelte Verträge ergänzen diese Primärzuordnung: fachbezogene `.ai4X/operations/` aktivieren zusätzlich ihre jeweilige Stufe, `spc/lib/core/src/` zusätzlich das White Paper und `spc/ctr/archimate/` zusätzlich Modellverträge und White Paper. Die vollständige ausführbare Matrix liegt ausschließlich im Selektor und seiner Vertragssuite.

Bei Pull Requests bleiben alle fünf GitHub-Checks sichtbar. Eine nicht betroffene Stufe endet mit einem expliziten erfolgreichen Skip; eine betroffene Stufe führt unverändert den entsprechenden lokalen `verify.sh`-Vertrag aus. Manuelle Aufrufe und Release-Tags erzwingen stets den vollständigen Vertrag. Ein Release gilt erst nach erfolgreicher Remote-Verifikation als akzeptiert.

`[skip ci]` ist kein regulärer Workflowmechanismus. Die repository-seitige Triggerregel entscheidet über Remote-Verifikation und hält Commit-Messages frei von wiederkehrender CI-Steuerung.

Agentische Ausführung folgt zusätzlich dem hostneutralen Vertrag unter [`.ai4X/`](./.ai4X/).
