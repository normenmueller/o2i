# Strategiebestandteile modellieren und erfassen

Eine vollständige O2I-Strategie verbindet zwei Darstellungsformen:
**Im Modellgraphen stehen die strategischen Inhalte und ihre Beziehungen;
eine ergänzende Strategieformulierung bindet diese Inhalte an ihre Rollen und
erfasst die weiteren textlichen und strukturierten Festlegungen.** Beide Formen
beschreiben dieselbe Wegentscheidung. „Ergänzend“ bedeutet ergänzend zum
Graphen; die Formulierung ist für eine fachlich vollständige Strategie
erforderlich.

Die fachlichen Bedeutungen definiert das [White Paper](../paper/o2i.md#strategie).
Diese Referenz erklärt, wo jeder Bestandteil erfasst wird. Das
[ArchiMate-Profil](../../spec/ctr/archimate/profile.json) bestimmt die konkrete
Modellsyntax. Der [Core-Vertrag](../../spec/lib/core/semantics.json) bestimmt
unter `strategyFormulationSemantics` die Formulierungsprüfung und unter
`supplementalInputSchema` das genaue Eingabeschema.

## Die elf Bestandteile und ihre Eingabeorte

Beginne mit dem Geltungsbereich: Für welche organisatorische oder sachliche
Einheit gilt diese Wegentscheidung? Danach lassen sich ihre Herausforderung,
Absicht und Handlungslogik zusammenhängend formulieren. Die Reihenfolge der
Tabelle dient der Orientierung; beim Ausarbeiten werden die Bestandteile
aufeinander abgestimmt.

Du kannst die Inhalte schrittweise ausarbeiten und den Modellgraphen zunächst
als `Candidate` prüfen. Ein solcher Zwischenstand ist noch kein vollständiger
Formulierungsinput: Für dessen Übergabe verlangt das vorhandene Schema alle
Pflichtfelder; unvollständige JSON-Datensätze sind kein zulässiges Teilformat.

Alle genannten JSON-Felder gehören zu **einem** `StrategyFormulationInput`
für die jeweilige Strategy. „Modell-IDs“ bezeichnet die Identitäten vorhandener
Modellelemente, nicht deren Namen oder ihre Position in einer View.

| Bestandteil | Fachliche Frage | O2I-Repräsentation | Konkreter Eingabeort |
| --- | --- | --- | --- |
| Geltungsbereich | Für welche Einheit gilt die Wegentscheidung? | Textliche Festlegung | JSON-Feld `scope`: nichtleere geordnete Textliste |
| Strategische Verankerung | Wie wird sie entscheidbar, verantwortbar und umsetzbar? | Strukturierte Festlegung | JSON-Objekt `anchoring`: Zeitraum, Verantwortungsbereich, Entscheidungsebene, Verantwortlichkeiten, Entscheidungswege und Umsetzungslogik |
| Abgeleitete Leitplanken | An welche übergeordneten Vorgaben muss sie anschließen? | Textliche Festlegung | JSON-Feld `derivedGuardrails`: nichtleere geordnete Textliste |
| Diagnose | Welche entscheidende Herausforderung muss bewältigt werden? | Ein oder mehrere `Driver @ Strategy` | ArchiMate `Driver`; ihre Modell-IDs im JSON-Feld `diagnosis` |
| Strategische Absicht | Welchen Beitrag zur Vision soll die Strategie leisten? | Ein oder mehrere `Objective @ Strategy` | ArchiMate `Goal`; ihre Modell-IDs im JSON-Feld `intent` |
| Guiding Policy | Welcher grundsätzliche Ansatz adressiert die Herausforderung? | Ein oder mehrere `Principle @ Strategy` | ArchiMate `Principle`; ihre Modell-IDs im JSON-Feld `guidingPolicy` |
| Strategische Positionierung | Wodurch unterscheidet sich der gewählte Ansatz von Alternativen? | Textliche Festlegung | JSON-Feld `positioning`: nichtleere geordnete Textliste |
| Trade-offs | Was wird bewusst nicht getan? | Menge fachlicher Ausschlüsse | JSON-Feld `tradeOffs`: nichtleere Menge verschiedener Texte |
| Kohärente Handlungsfestlegungen | Welche Entscheidungen und Ressourcenbindungen machen den Ansatz ausführbar? | Ein oder mehrere `Action @ Strategy` | ArchiMate `CourseOfAction`; ihre Modell-IDs im JSON-Feld `actions` |
| Strategischer Erfolgsbezug | Welches überprüfbare Ergebnis stützt den angestrebten Beitrag? | Ein oder mehrere `Key Result @ Strategy` | ArchiMate `Outcome`; ihre Modell-IDs im JSON-Feld `keyResults` |
| Fit / Kohärenznachweis | Warum passen Positionierung, Trade-offs, Handlungsfestlegungen und Erfolgsbezüge zusammen? | Textliche Kohärenzbegründung | JSON-Feld `fitRationale`: nichtleere geordnete Textliste |

Zur **Diagnose**: Dieser Strategiebestandteil beschreibt die entscheidende
Herausforderung, die eine Strategie bewältigen muss, um die Vision zu
verwirklichen.

Die elf Bestandteile sind keine zusätzlichen O2I-Kontexte oder Primitive-Typen.
Fünf Bestandteile werden durch Primitives repräsentiert und in der
Formulierung über deren Modell-IDs gebunden; die anderen sechs werden dort
textlich oder strukturiert erfasst. Die
[Strategiebestandteile-Sicht](../../meta/o2i-semantics-strategy-constituents.md)
zeigt ihren fachlichen Zusammenhang.

## Den Modellgraphen in Archi erfassen

Die Strategy wird als ArchiMate `Grouping` mit `o2i.type=Strategy` modelliert.
Die fünf Primitive-Typen tragen jeweils `o2i.type=Driver`, `Objective`,
`Principle`, `Action` beziehungsweise `KeyResult`. Jedes dieser Elemente und
die Strategy tragen genau einmal `o2i.commitment` mit `candidate` oder
`asserted`, entsprechend ihrem Aussageanspruch.

Je eine gerichtete `Composition` vom Strategy-Grouping zum Primitive heißt
exakt `contextualizes` und trägt ebenfalls `o2i.commitment`. Sie drückt die
Zugehörigkeit aus. Räumliches Verschachteln allein stellt diese Bindung nicht
her. Die [Trägersicht](../../meta/o2i-syntax-carriers.md) und die
[Kontextualisierungssicht](../../meta/o2i-syntax-contextualization.md) erklären
die allgemeinen Syntaxmuster.

Die inhaltlichen Beziehungen werden zusätzlich im Modellgraphen erfasst:
Diagnose begründet Absicht, Guiding Policy leitet Handlungsfestlegungen,
Handlungsfestlegungen tragen zu Erfolgsbezügen bei, und Erfolgsbezüge
substantiieren Absichten. Die Vision richtet die Absichten aus. Die genauen
Pflichten stehen unter [Semantische Gültigkeit](../paper/o2i.md#semantische-gültigkeit);
zulässige ArchiMate-Beziehungstypen bestimmt das Profil.

## Eine vollständige Strategieformulierung eingeben

Erstelle eine separate UTF-8-JSON-Datei mit `type` gleich
`StrategyFormulationInput` und `strategy` gleich der Modell-ID des betreffenden
Strategy-Groupings. Ergänze sämtliche elf Felder aus der Tabelle. Die Felder
`diagnosis`, `intent`, `guidingPolicy`, `actions` und `keyResults` sind jeweils
nichtleere Mengen verschiedener Modell-IDs. Die referenzierten Primitives
müssen den passenden Typ haben und dieser Strategy gehören.

Die Rollenbindung entsteht durch diese fünf ID-Mengen. Ein Elementname wie
„Diagnose“ bindet keine Rolle; eine Property `o2i.role=diagnosis` ist dafür
nicht vorgesehen. Auch die sechs weiteren Bestandteile werden nicht als neue
O2I-Properties am Grouping abgelegt. Das ArchiMate-Profil stellt keinen
modellinternen Transport für den Formulierungsinput bereit.

Das Objekt `anchoring` enthält folgende Pflichtfelder:

| Feld | Inhalt und Form |
| --- | --- |
| `period` | Zeitraum als nichtleerer Text |
| `responsibilityScope` | Verantwortungsbereich als nichtleerer Text |
| `decisionLevel` | Entscheidungsebene als nichtleerer Text |
| `responsibilities` | Tragende Verantwortlichkeiten als nichtleere geordnete Textliste |
| `decisionPaths` | Entscheidungswege als nichtleere geordnete Textliste |
| `implementationLogic` | Umsetzungslogik als nichtleerer Text |

Eine Textliste ist ein JSON-Array aus Zeichenketten. Bei `tradeOffs` tragen
Reihenfolge und Mehrfachnennung keine zusätzliche Bedeutung; die Einträge
müssen verschieden sein. Das Schema lässt keine unbekannten Felder zu.
Ein [vollständiges technisches Eingabebeispiel](../../spec/cli/tst/fixtures/plural-strategy-input.json)
zeigt die Struktur mit mehreren Inhalten je Graphrolle. Seine IDs gehören
zum [zugehörigen Testmodell](../../spec/cli/tst/fixtures/profiled-plural-strategy.archimate)
und sind durch die IDs des eigenen Modells zu ersetzen.

## Modell und Formulierung gemeinsam prüfen

Nach [Installation der CLI](../../spec/README.md#cli-setup) übergibst du die
JSON-Datei bei der Semantikprüfung über `--supplement`. Ersetze im folgenden
Aufruf Dateipfade und View-Namen durch deine eigenen:

```sh
o2i validate modell.archimate --view "Strategie" --level semantics --supplement strategie.json
```

Für mehrere Strategien wird `--supplement` mit jeweils einer Datei wiederholt.
Pro Strategy darf höchstens ein Formulierungsinput in derselben Operation
vorliegen. Alle referenzierten Modellidentitäten müssen im ausgewählten
View-Scope erreichbar sein. Der Input wird der Operation separat übergeben;
er wird nicht im ArchiMate-Modell gespeichert oder von der CLI automatisch
nachgeladen.

Ein `Candidate` bleibt ein diagnostizierbarer Entwurf und liefert keine
Begründungszeugen. Die vollständige Formulierungsprüfung verlangt die
zugeordneten Inhalte, Kontextualisierungen und erforderlichen Beziehungen mit
`Asserted`-Commitment. Ohne Formulierungsinput bleibt dieses ergänzende
Assessment nicht verfügbar; ein akzeptierter Modellgraph allein weist keine
vollständige Strategieformulierung nach.

Die formale Prüfung kontrolliert Eingabeform, Identitätsbindung und die
definierten Relationspflichten. Die fachliche Tragfähigkeit von Diagnose,
Positionierung, Trade-offs und Kohärenzbegründung muss weiterhin inhaltlich
beurteilt werden.

Für das Zusammenwirken mehrerer Strategien gelten zusätzlich die Regeln zu
[Strategiebeitrag und kollektiver Strategierealisierung](../paper/o2i.md#strategiebeitrag-und-kollektive-strategierealisierung).
Die vorhandene [Syntaxsicht zur kollektiven Strategierealisierung](../../meta/o2i-syntax-collective-strategy-realization.md)
zeigt deren n-ären Träger. Die vollständigen Beitragspflichten und der separate
kollektive Fit sind im [Metamodell](../paper/o2i.md#kollektive-strategierealisierung)
beschrieben.

[Zur Dokumentationsübersicht](../README.md)
