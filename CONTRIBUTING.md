# Contributing to O2I

Öffentliche Beiträge beginnen mit einem GitHub Issue. Das Issue beschreibt das Problem und den angestrebten Zustand; Pull Requests setzen ein ausreichend geklärtes Issue um. Ein ausdrücklicher PO-Auftrag darf klar begrenzte Routinearbeit auch ohne Issue autorisieren; der lokale Handoff hält Scope und Autorität für die Arbeitskontinuität fest.

Das öffentliche GitHub Project [O2I](https://github.com/users/normenmueller/projects/4) bildet Arbeitszustand und PO-Reihenfolge ab. Issues bleiben für Vertrag, materielle Entscheidungen, Abhängigkeiten, Reviews sowie offenen oder geschlossenen Zustand maßgebend.

Für die Aufnahme ins Backlog genügt eine verständliche Idee mit Problem und grobem Ziel. Ein Agent bewertet kurz O2I-Passung, erwarteten Nutzen, mögliche Dopplungen, Änderungsklasse und Labels und erfasst einen geeigneten Vorschlag ohne Design- oder Umsetzungsfreigabe.

## Risikogerechte Änderungspfade

Der notwendige Prozess richtet sich nach Wirkung, Reversibilität und Reichweite der tatsächlichen Änderung. Labels erleichtern das Finden, bestimmen aber nicht automatisch die Governance.

### Routine

Routinearbeit ist lokal, reversibel und semantikerhaltend, beispielsweise ein fokussierter Bugfix, Refactoring ohne öffentlichen Vertragswechsel, Tests, Dokumentationskorrekturen, CI oder Tooling.

Minimal erforderlich sind ein verständliches Issue oder ein ausdrücklicher PO-Auftrag, ein fokussierter Kandidat, die relevanten deterministischen Prüfungen und ein kritischer Selbstreview. Ein unabhängiger Reviewer kommt nur hinzu, wenn Tests und lokale Inspektion ein materielles Risiko nicht glaubwürdig schließen.

### Signifikant

Signifikante Arbeit verändert einen öffentlichen Vertrag, überschreitet Paket- oder Capability-Grenzen, führt eine Migration durch oder besitzt eine größere technische beziehungsweise nutzungsbezogene Reichweite, ohne geschützte fachliche Bedeutung zu verändern.

Das Issue hält die relevante Designentscheidung und echte Alternativen fest. Erforderlich sind ausdrückliche Umsetzungsautorität, deterministische Verifikation und mindestens ein unabhängiger Reviewer mit passender Fähigkeit. Weitere Reviewer gibt es nur für materiell eigenständige Risiken.

### Geschützt

Geschützte Arbeit verändert fachliche Terminologie oder Metamodellsemantik, normative Syntax, schwer umkehrbare Kompatibilitätszusagen, Release- oder Publikationsautorität, sicherheitsrelevantes Verhalten oder die Repository-Governance selbst.

Sie benötigt eine ausdrückliche PO-Entscheidung, ein vollständiges aber kompaktes Issue, risikogerecht ausgewählte unabhängige Fachreviews, alle anwendbaren Prüfungen und eine gesonderte PO-Freigabe für Veröffentlichung oder Push. Digests und unveränderliche Manifeste werden nur für externe Autoritäten, Release-Artefakte, sicherheitsrelevante Evidenz oder einen anderen konkret benannten Integritätsbedarf verwendet.

Unklarheit führt nach Prüfung höchstens in die nächstsicherere Klasse, nicht automatisch in den Maximalprozess. Kein Änderungspfad schwächt Tests, Typsicherheit, Reproduzierbarkeit, Dokumentationsqualität, Repository-Autonomie oder Publikationsprüfungen.

## Status

Das GitHub Project `O2I` zeigt Arbeitsstand und PO-Reihenfolge:

- `Backlog`: verständliche Idee oder Problem;
- `Refinement`: eine materielle Produkt- oder Designentscheidung wird vorbereitet; kein Pflichtschritt für Routinearbeit oder bereits eindeutige PO-Aufträge;
- `Ready`: autorisiert und ohne Voraussetzung, die den nächsten Schritt blockiert;
- `In progress`: aktive Konzeption, Umsetzung, Untersuchung, Reproduktion oder Korrektur;
- `Paused`: echter Wartezustand mit genau einem Grund und einer Rückkehrbedingung;
- `In review`: vollständiger Kandidat in Prüfung oder mit ausstehender PO-Publikationsentscheidung;
- `Done`: akzeptiert, erforderlichenfalls remote verfügbar und verifiziert sowie geschlossen.

```text
Backlog -> Refinement -> Ready -> In progress -> In review -> Done
                                      |
                                      +-> Paused -> Ready
```

Das Board bildet Autorität ab, erzeugt sie aber nicht. Ein ausdrücklicher PO-Auftrag kann klare Arbeit ohne zeremonielle Statusdurchläufe autorisieren. Project-Reihenfolge ersetzt keine Abhängigkeit; echte Voraussetzungen werden als native Issue Dependencies modelliert.

Die ausdrückliche PO-Freigabe eines exakten Issues im Project-Status `Ready` autorisiert Gertrud innerhalb seines akzeptierten Scopes standardmäßig bis `In review`: Aktivierung und `In progress`, passende Spezialisten und Co-Authors, Umsetzung, deterministische Verifikation, unabhängige Reviews und Korrekturen, Commit, Push, Pull Request, grüne erforderliche Remote-Prüfungen, Evidenzbelege und `In review`. Der bloße Status `Ready` genügt nicht. Die Freigabe umfasst weder Scope-Erweiterung oder umgangene Owner und Rollentrennung noch Merge, Issue-Schließung, `Done`, Branch- oder Worktree-Bereinigung, Release oder Tag und geschützte Publikation. Fehlt die verifizierte Machine-User-Identität, unterbleiben agentische Remote-Schreibvorgänge.

Die ausdrückliche PO-Autorität für die Abschlussaktionen eines exakten Issues gilt nach ihrem genannten Scope und ihren Bedingungen. Umfasst sie auch die Bereinigung, wird nur dieser Bereinigungsanteil erst ausführbar, wenn das Issue akzeptiert, erforderlichenfalls publiziert und remote grün verifiziert, geschlossen sowie im Project `Done` ist. Gertrud muss dann sämtliche nicht mehr benötigten Issue-eigenen lokalen und Remote-Arbeitsbranches, verknüpften Worktrees, Stashes, jeden veralteten `.ai4x/local/ACTIVE.md`-Verweis und Scratch-Artefakte entfernen. Diese Aufräumpflicht ist Teil des autorisierten Abschlusses; die gewöhnliche Ready-Freigabe bis `In review` autorisiert sie nicht.

Vor jeder Löschung werden alle Ziele exakt identifiziert und nur bereinigt, wenn ihre einzigartigen Änderungen auf dem maßgebenden publizierten Branch dauerhaft vorhanden oder ausdrücklich obsolet sind. Unmittelbar vor jeder einzelnen Löschung werden das Ziel erneut aufgelöst und seine stabile Identität sowie ein gegebenenfalls erwarteter Ref gegen den Vorabnachweis geprüft; jede Abweichung stoppt die Bereinigung vor dieser Mutation. Default-, geschützte, aktive, im Review befindliche, ungemergte oder der Wiederherstellung dienende Branches, aktive Worktrees und Handoffs sowie Stash- oder Scratch-Daten mit einzigartigem oder nutzereigenem Inhalt bleiben unangetastet; breite Wurzelziele, unaufgelöste Variablen, Globs und rekursive Dateisystemlöschungen sind ausgeschlossen. Remote-Branch-Löschungen benötigen die verifizierte Machine-User-Identität und eine Lease oder gleichwertige, an den erwarteten Ref gebundene bedingte Operation. Danach werden lokale und Remote-Bestände erneut inventarisiert und veralteter Project- oder ACTIVE-Zustand nur innerhalb derselben Autorität korrigiert.

## PO-Entscheidungsvorlage

Jeder abschließende Bericht, der eine autorisierte Arbeitseinheit beendet oder an einem PO-Entscheidungs- beziehungsweise Wartepunkt zurückgibt, endet mit genau einer konkreten Empfehlung. Sie benennt in fester Reihenfolge den exakten Gegenstand, begrenzten Scope, beobachtbaren Zielzustand, die Autoritätsgrenze und einen kurzen evidenzbasierten Grund. Die Autoritätsgrenze enthält entweder die exakt neu angefragte Agentenautorität oder das Literal `none` sowie in beiden Fällen zwingend die Ausschlüsse. Eine durch `Freigegeben.` ausführbare Empfehlung muss die exakte neue Agentenautorität nennen und darf `none` nicht verwenden; eine direkte PO-Aktion und ein empfohlener Cold Start müssen `none` verwenden und dürfen keine Agentenautorität erfinden. Die Vorlage nennt nur Alternativen, die Scope, Autorität, materielles Risiko, unumkehrbare Folgen oder die erforderliche Reihenfolge tatsächlich verändern, und andernfalls ausdrücklich keine. Zwischenstände, reine Antworten und autonomes Weiterarbeiten innerhalb bestehender Autorität benötigen keine Entscheidungsvorlage.

Die Vorlage bewertet den Cold Start mit genau `recommended` oder `not recommended`. `recommended` setzt alle Sicherheitsbedingungen voraus und macht den Cold Start zur einzigen Empfehlung. Bei `not recommended` unterscheidet der Grund ausdrücklich zwischen einer fehlgeschlagenen Sicherheitsbedingung und einem sicheren, aber gegenüber der Empfehlung nachrangigen Cold Start.

Das kanonische Feld `Approval:` erscheint im deutschen Bericht als `Antwort zur Freigabe:`; darauf folgt als exakte alleinstehende PO-Antwort `Freigegeben.`. Die Ausgabe `Freigabe: Freigegeben.` ist ausgeschlossen. Diese Antwort bindet genau einmal ausschließlich die eine Empfehlung der unmittelbar vorausgehenden, noch offenen Entscheidungsvorlage mit ihrem Gegenstand, Scope, Zielzustand und ihrer Autoritätsgrenze. Gertrud prüft diese Bindung unmittelbar vor der Ausführung und macht sie durch einen nicht autoritätserweiternden Beleg mit denselben vier Angaben und dem Zustand `consumed` sichtbar. Dieser Zustand bindet die Freigabe an genau diese eine begrenzte Ausführung und verhindert ihre Wiederverwendung. Eine fehlende oder mehrdeutige Vorlage, eine bereits verbrauchte Vorlage sowie eine durch eine spätere Vorlage oder neue materielle Fakten überholte Vorlage blockieren die Ausführung und erfordern eine neue Entscheidungsvorlage. Die Bindung gilt nur im aktuellen laufenden Austausch; sie wird weder aus einem Gesprächsprotokoll rekonstruiert noch über eine Session-Grenze getragen. Eine direkte PO-Aktion und ein empfohlener Cold Start werden nicht durch `Freigegeben.` gebunden.

Beim empfohlenen Cold Start folgen auf ausschließlich nicht imperative Entscheidungsmetadaten die unveränderten drei nummerierten Aktionsschritte des Cold-Start-Vertrags. Weitere imperative Sätze oder nummerierte Übergangsanweisungen sind ausgeschlossen, und der Bericht endet unmittelbar nach Schritt 3. Bei `not recommended` werden diese Schritte nicht ausgegeben.

Native Sub-Issues werden nur genutzt, wenn sie einen mehrteiligen Liefergegenstand für den Product Owner sichtbar besser machen. Der Parent besitzt integrierten Scope, Autorität, Annahme und Publikation. Eine Story oder ein Batch besitzt genau einen begrenzten Liefergegenstand und den eigenen Open/Closed-Zustand, ergänzt aber keinen Produktscope und keine Autorität. Aktive Stories dürfen zur Sichtbarkeit im Project stehen.

Ein bei der späteren Integration entdecktes Problem ist zunächst eine Akzeptanz-Challenge und keine rückwirkende Entwertung. Es wird gegen die exakte akzeptierte Revision und ihre Autorität reproduziert und danach als Vorgängerfehler, Verantwortung der aktuellen Arbeit, Vertragsunklarheit oder Nicht-Finding klassifiziert. Ein bestätigter Vorgängerfehler erhält standardmäßig ein neues verlinktes Korrektur-Issue; geschlossene Historie bleibt geschlossen, sofern der Product Owner keine andere Darstellung entscheidet.

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

- Änderungen bleiben im Scope des Issues oder des ausdrücklichen PO-Auftrags.
- Neue fachliche Ideen erhalten ein eigenes Issue, bevor sie den Scope ändern.
- Veröffentlichungstexte beschreiben ausschließlich den frischen SOLL-Zustand.
- Normative O2I-Designs verwenden keine Workarounds, Kompatibilitätsschichten oder Migrationskonstrukte; ein unpassender Kern wird kohärent neu entworfen.
- Commit Messages sind kleingeschriebenes Englisch ohne Typpräfix.
- Issue-bezogene Commits führen `Refs #N` im Commit-Body; `Closes #N` bleibt dem tatsächlich abschließenden Commit vorbehalten.
- Pull Requests referenzieren ihr Issue und benennen ausgeführte Prüfungen.

## Review

Ein Review dokumentiert den exakten Gegenstand und Scope, die Reviewerfähigkeit, ausgeführte Prüfungen, Findings und genau eines dieser Verdicts:

- `accepted`: kein blockierendes Finding bleibt offen;
- `accepted with follow-ups`: kein blockierendes Finding bleibt offen; separat erfasste Verbesserungen verhindern die Annahme nicht;
- `changes required`: mindestens ein blockierendes Finding bleibt offen.

Numerische Bewertungen entfallen. `10/10` ist ausschließlich die PO-Kurzform dafür, dass alle erforderlichen formalen Verdicts `accepted` lauten, weder blockierende noch beratende Findings offen sind, alle lokalen und entfernten Prüfungen des exakten Kandidaten grün sind und die Trennung von Autorschaft und Review gewahrt ist; `accepted with follow-ups` erfüllt diese Kurzform nicht. Reviewtiefe und Zahl der Reviewer folgen dem tatsächlichen Risiko. Routinearbeit benötigt nicht automatisch einen externen Reviewer; signifikante Arbeit mindestens einen passenden unabhängigen Reviewer; geschützte Arbeit risikogerecht ausgewählte unabhängige Fachreviews und die verantwortliche PO-Entscheidung.

Reviewer bewerten kritisch, neutral, objektiv und unabhängig. Ein Review ist keine Annahmeautomatik. Jedes blockierende Finding benennt eine konkrete SOLL-Lösung und bleibt von optionalen Verbesserungen unterscheidbar.

Spätere Änderungen benötigen nur für ihre geänderte Risikofläche einen neuen Review. Sie entwerten akzeptierte historische Evidenz für unveränderte Revisionen und Gesetze nicht. Korrekturen eines veröffentlichten Review-Belegs erfolgen durch einen neuen Kommentar statt durch das Umschreiben der Historie.

## Verifikation

Der vollständige lokale Repository-Vertrag verändert keine getrackten Arbeitsartefakte und lautet:

```sh
./utl/verify.sh
```

Fokussierte Prüfungen mit `licensing`, `governance`, `model`, `haskell` oder `paper` sind während der Entwicklung vorgesehen. Die Lizenzstufe setzt den offiziellen REUSE-Validator 6.2.0 voraus; er kann mit `pipx install "reuse[charset-normalizer]==6.2.0"` installiert werden. Sie verlangt für jede getrackte Datei genau eine pfadbasierte Annotation in `REUSE.toml`, verbietet konkurrierende eingebettete SPDX-Angaben und ist deshalb bei jeder Änderung aktiv. Vor jedem Commit müssen mindestens alle von der Pfadmatrix betroffenen Stufen lokal erfolgreich sein; bei unbekannter oder gemeinsam genutzter Vertragsfläche gilt der vollständige Vertrag. Vor jedem Release-Tag ist `./utl/verify.sh` vollständig auszuführen. Die Paper-Stufe prüft zusätzlich die festgelegte `md2pdf`-Version, Quellenbindung sowie Seiten- und Textstruktur eines frischen Builds.

Direkte Branch-Pushes lösen keine GitHub Actions aus. Remote-Verifikation läuft ausschließlich für Pull Requests, manuelle Workflow-Aufrufe und Release-Tags mit dem Muster `o2i-v*`.

Bei jedem Lauf bestimmt `utl/verification/verification_scope.py` aus dem Git-Diff, welche Stufen betroffen sind. Die primäre Zuordnung lautet:

| Änderung | Ausgeführte Stufen |
| --- | --- |
| jeder getrackte Pfad | Repository-Lizenzierung |
| `.ai4x/` oder Governance-Werkzeuge | Governance |
| `mdl/` oder Modellwerkzeuge | Modellverträge |
| `spc/` | Haskell-Spezifikation |
| White-Paper-Quellen oder Rendering | White Paper |
| gemeinsam genutzte, unbekannte oder nicht eindeutig bestimmbare Pfade | alle Stufen |

Gekoppelte Verträge ergänzen diese Primärzuordnung: fachbezogene `.ai4x/operations/` aktivieren zusätzlich ihre jeweilige Stufe, `spc/lib/core/src/` zusätzlich das White Paper und `spc/ctr/archimate/` zusätzlich Modellverträge und White Paper. Die vollständige ausführbare Matrix liegt ausschließlich im Selektor und seiner Vertragssuite.

Bei Pull Requests bleiben alle fünf GitHub-Checks sichtbar. Eine nicht betroffene Stufe endet mit einem expliziten erfolgreichen Skip; eine betroffene Stufe führt unverändert den entsprechenden lokalen `verify.sh`-Vertrag aus. Manuelle Aufrufe und Release-Tags erzwingen stets den vollständigen Vertrag. Ein Release gilt erst nach erfolgreicher Remote-Verifikation als akzeptiert.

`[skip ci]` ist kein regulärer Workflowmechanismus. Die repository-seitige Triggerregel entscheidet über Remote-Verifikation und hält Commit-Messages frei von wiederkehrender CI-Steuerung.

Agentische Ausführung folgt zusätzlich dem hostneutralen Vertrag unter [`.ai4x/`](./.ai4x/).
