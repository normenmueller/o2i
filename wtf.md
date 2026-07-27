# WTF & HTH

`WTF` steht hier für `What the f**k?`, `HTH` für `How the heck?`. Dieses Dokument beantwortet naheliegende O2I-Fragen bewusst direkt: kurz genug für den Einstieg, präzise genug, um nichts Falsches mitzunehmen. Für die vollständige fachliche Begründung führen die Verweise in den O2I-Artikel.

> [!NOTE]
> `Mindestinhalt` bezeichnet, welche Informationen fachlich mindestens bereitgestellt werden müssen; ein bestimmtes Dokumentformat schreibt O2I nicht vor. `Prüfung` grenzt den Inhalt fachlich ab und benennt die jeweils einschlägigen Validierungsstufen.

## WTF "Ethos"?

> [!NOTE]
> **Ethos** = *Wofür* stehen wir?

Ethos ist der kulturell-normative Kompass eines Akteurs: Wofür stehen wir, und was kommt für uns grundsätzlich infrage? Es besteht aus mindestens einem Leitprinzip, das Handlungsoptionen bewertet und begrenzt. Ethos ist weder Zielbild noch Strategie.

**Mindestinhalt**

- der handlungsfähige Akteur, für den das Ethos gilt,
- mindestens ein benanntes Leitprinzip,
- der normative Maßstab jedes Leitprinzips für Entscheidungen und Handlungen.

**Prüfung**

Die Leitprinzipien müssen Handlungsoptionen bewerten oder begrenzen können. Ziele, Zukunftsbilder und Maßnahmen erfüllen diese Funktion nicht.

Weiterlesen: [Ethos](./o2i.md#ethos)

## WTF "Mission"?

> [!NOTE]
> **Mission** = *Warum* gibt es uns?

Mission beantwortet, warum es einen Akteur gibt und welchen dauerhaften Beitrag er leisten soll. Sie wird vom Ethos geprägt, legt aber weder einen Zukunftszustand noch den Weg dorthin fest.

**Mindestinhalt**

- der handlungsfähige Akteur, für den die Mission gilt,
- sein dauerhafter Existenzzweck und angestrebter Beitrag,
- mindestens ein `Driver @ Mission`, der diesen Beitragsgrund ausdrückt,
- die Führung mindestens eines Mission-Drivers durch mindestens ein Leitprinzip des Ethos.

**Prüfung**

Die Mission muss das dauerhafte Warum beantworten. Ein befristetes Ziel, Zukunftsbild oder Vorgehensplan ist keine Mission.

Weiterlesen: [Mission](./o2i.md#mission)

## WTF "Vision"?

> [!NOTE]
> **Vision** = *Wohin* wollen wir wirken?

Vision beschreibt, wohin ein Akteur wirken will: den angestrebten, orientierenden Zukunftszustand. Sie gibt Richtung, aber noch keinen Weg. Wer bereits konkrete Handlungen aufzählt, ist gedanklich bei Strategie oder Intervention angekommen.

**Mindestinhalt**

- der handlungsfähige Akteur, für den die Vision gilt,
- mindestens ein qualitativ beschriebener angestrebter Zukunftszustand als `Objective @ Vision`,
- die Begründung mindestens eines Vision-Objectives durch einen `Driver @ Mission`,
- die Führung mindestens eines Vision-Objectives durch ein Leitprinzip des Ethos.

**Prüfung**

Die Vision muss einen orientierenden Zukunftszustand beschreiben, ohne Wegentscheidung, Maßnahmen oder Umsetzungsdetails vorwegzunehmen.

Weiterlesen: [Vision](./o2i.md#vision)

## WTF "Strategie"?

> [!NOTE]
> **Strategie** = *Wie* verwirklichen wir unsere Vision?

Strategie ist kein Wunschzettel. Sie beschreibt das strategische Wie: die begründete und kohärente Wegentscheidung, wie ein handlungsfähiger Akteur seine Vision unter gegebenen Bedingungen verwirklichen will. Sie legt sich gegenüber Alternativen unterscheidbar fest, bindet Handlungen und Ressourcen und muss als Ganzes kohärent sein.

**Mindestinhalt**

- Geltungsbereich,
- strategische Verankerung mit Zeitraum, Verantwortungsbereich, Entscheidungsebene, Verantwortlichkeiten, Entscheidungswegen und Umsetzungslogik,
- abgeleitete Leitplanken,
- Diagnose,
- strategische Absicht,
- Guiding Policy,
- strategische Positionierung,
- Trade-offs,
- kohärente Handlungsfestlegungen,
- strategische Erfolgsbezüge,
- Fit beziehungsweise Kohärenznachweis.

**Prüfung**

Eine vollständige Strategie verbindet `Driver`, `Objective`, `Principle`, mindestens eine `Action` und mindestens ein `Key Result` in ihren festgelegten Strategy-Rollen. Diagnose begründet Absicht, Guiding Policy leitet Handlungsfestlegungen, diese tragen zu Erfolgsbezügen bei und Erfolgsbezüge substantiieren die Absicht. Die Fit-Begründung weist die Kohärenz des Gesamtzusammenhangs nach.

Spezifikation: [`assessModelSemantics`](./spc/lib/core/src/O2I/Validation/Semantics.hs)

Weiterlesen: [Strategie](./o2i.md#strategie)

## WTF "Kollektive Strategierealisierung"?

> [!NOTE]
> **Kollektive Strategierealisierung** = *Realisieren mehrere Strategien gemeinsam eine Zielstrategie?*

Ein binärer Strategiebeitrag sagt nur, dass eine Strategie zu einer anderen beiträgt. Kollektive Strategierealisierung ist stärker: Mindestens zwei Strategien realisieren eine Zielstrategie gemeinsam. Keine davon realisiert das Ziel allein.

**Mindestinhalt**

- mindestens zwei verschiedene beitragende Strategy-Instanzen,
- genau eine andere Ziel-Strategy,
- eine eigene begründete `contributes-to`-Makrorelation jedes Beitragenden zum Ziel,
- gemeinsame Abdeckung aller Actions und Key Results der Ziel-Strategy,
- paarweise Kohärenz der Beitragenden,
- Kompatibilität jedes Beitrags mit Guiding Policy und Trade-offs des Ziels,
- eine tragfähige Interaktion der Beiträge.

**Prüfung**

`assessModelSemantics` prüft Kontext- und Strategy-Semantik sowie sämtliche kollektiven Claims als eine vollständige Modellgrenze. Candidates bleiben diagnostizierbar; ohne gültige Kontextsemantik wird ihre fachliche Bewertung ausdrücklich als blockiert ausgewiesen. Fatal fehlerhafte Claims verhindern die Annahme, und nur ein insgesamt angenommenes Assessment erzeugt ein `SemanticallyValidModel` mit opaken Realisierungszeugen. Eine direkte binäre `Strategy --realizes--> Strategy`-Relation ist unzulässig; `directs` und `contributes-to` behalten ihre jeweils eigene Bedeutung.

Spezifikation: [`assessModelSemantics`](./spc/lib/core/src/O2I/Validation/Semantics.hs), [`validatedCollectiveStrategyRealizations`](./spc/lib/core/src/O2I/Validation/Semantics.hs)

Weiterlesen: [Strategiebeitrag und kollektive Strategierealisierung](./o2i.md#strategiebeitrag-und-kollektive-strategierealisierung), [Kollektive Strategierealisierung im Metamodell](./o2i.md#kollektive-strategierealisierung)

## WTF "Modellzustand"?

> [!NOTE]
> **Modellzustand** = *Welche Aussagen gelten bereits, welche Kontexte sind elaboriert und wie reif ist das Gesamtmodell?*

O2I trennt drei Ebenen: `Commitment` kennzeichnet den Aussageanspruch eines Claims als `Candidate` oder `Asserted`. `Elaboration` beschreibt abgeleitet den verpflichtenden Inhalt einer Kontextinstanz als `Referenced` oder `Elaborated`. `Maturity` beschreibt abgeleitet die geprüfte Modellgrenze als `Skeleton`, `Draft` oder `SemanticallyValid`.

**Mindestinhalt**

- Claims mit genau einem eindeutigen Aussageanspruch,
- vollständige verpflichtende Inhalte für jeden zu elaborierenden Kontext,
- alle Abhängigkeiten und Evidenzen der `Asserted`-Claims,
- keine manuell gesetzten Werte für `Elaboration` oder `Maturity`.

**Prüfung**

Candidates bleiben diagnostizierbar, erfüllen jedoch keine semantische Pflicht. Ein Kontext ist nur durch vollständige gültige `Asserted`-Inhalte elaboriert. Das Modell ist `SemanticallyValid`, wenn keine Candidates verbleiben und die globale Semantikprüfung erfolgreich ist; andernfalls ist es abhängig von der Kontextelaboration `Draft` oder `Skeleton`.

Spezifikation: [`Commitment`](./spc/lib/core/src/O2I/Language/Claim.hs), [`assessModelSemantics`](./spc/lib/core/src/O2I/Validation/Semantics.hs)

Weiterlesen: [Claims](./o2i.md#claims), [Modellzustand](./o2i.md#modellzustand)

## WTF "Situation"?

> [!NOTE]
> **Situation** = *Wo* genau in der fachlichen Realität zeigt sich ein Bedarf?

Situation ist das fachliche Wo eines Bedarfs: der konkrete Arbeits-, Leistungs- oder Umfeldzusammenhang, in dem Veränderungsbedarf sichtbar wird. Eine Business Capability, ein Business Process, ein Business Object oder ein Value Stream verankert diesen Zusammenhang als operativen Wirkungsgegenstand. Technologie und Lösung gehören hier noch nicht hinein.

**Mindestinhalt**

- ein fachlich benannter Situationskontext,
- mindestens ein konkreter Situationsanker,
- dessen Typ als Business Capability, Business Process, Business Object oder Value Stream,
- die Relation, durch die der Anker die Situation konstituiert.

**Prüfung**

Der Situationsanker muss nach seiner Business-Architecture-Semantik modelliert sein und denselben operativen Wirkungsgegenstand für Bedarf, Veränderung und Messung bestimmen. Eine technische Lösung, Maßnahme, Business Role oder regulatorische Randbedingung ist kein Situationsanker.

Spezifikation: [`assessModelSemantics`](./spc/lib/core/src/O2I/Validation/Semantics.hs)

Weiterlesen: [Situation](./o2i.md#situation)

## WTF "Bedarf"?

> [!NOTE]
> **Bedarf** = *Was* wird benötigt?

Bedarf ist das fachliche Was: eine situationsbezogene Anforderung an Veränderung. Er beschreibt, was benötigt wird, nicht wie es umgesetzt wird. Ohne Situationsbezug bleibt die Aussage fachlich freischwebend und ist kein O2I-Bedarf.

**Mindestinhalt**

- mindestens ein `Driver @ Need`, der den situierten Veränderungsgrund beschreibt,
- mindestens ein `Objective @ Need`, das die benötigte qualitative Veränderung ausdrückt,
- mindestens eine `Situation --surfaces--> Need`-Relation,
- die Verankerung jedes Need-Drivers an mindestens einem Anker einer sichtbar machenden Situation,
- die Begründung jedes Need-Objectives durch mindestens einen Driver desselben Needs.

**Prüfung**

`assessModelSemantics` prüft die vollständige Situierung. Eine Lösung, Maßnahme oder technische Anforderung ersetzt weder Need-Driver noch Need-Objective.

Spezifikation: [`assessModelSemantics`](./spc/lib/core/src/O2I/Validation/Semantics.hs)

Weiterlesen: [Bedarf](./o2i.md#bedarf)

## WTF "Qualifikationsvorlage"?

> [!NOTE]
> **Qualifikationsvorlage** = *Was muss für die Qualifikationsprüfung vorliegen?*

**Mindestinhalt**

- vollständig situierter Bedarf mit `Driver`, `Objective` und Situationsanker,
- Referenz auf die bestehende Strategie, an der sich der Einreicher ausgerichtet hat,
- vorgeschlagene Verbindung `Key Result @ Strategy --translates-into--> Objective @ Need`,
- fachliche Begründung und nachvollziehbarer Quellenbezug.

**Prüfung**

Agentic AI kann die Verbindung vorschlagen und begründen. Nach vollständiger Situierung des Bedarfs und vor der Modellierung von `translates-into` und `qualifies` prüft die O2I-Spezifikation ihre formale Zulässigkeit. Formale Fehler führen zu keinem Kandidaten und zu keiner Graphänderung. Einen positiven `NeedQualificationCandidate` prüfen fachlich legitimierte Personen.

Spezifikation: [`validateNeedQualificationProposal`](./spc/lib/core/src/O2I/Validation/Qualification.hs)

Ein Nachweisentwurf gehört nicht zur Qualifikationsvorlage. Eine organisationsspezifische Einreichungsregel kann beides gemeinsam verlangen; die O2I-Gates bleiben dennoch unabhängig.

Weiterlesen: [Bedarfsqualifikation](./o2i.md#bedarfsqualifikation), [Evidenzbereitschaft](./o2i.md#evidenzbereitschaft)

## HTH "Bedarfsqualifikation"?

<!-- How the heck to qualify need? -->

**Eingaben**

- ein `SemanticallyValidModel`, das Kandidatenstrategie und vollständig situierten Bedarf enthält,
- eine vollständige Qualifikationsvorlage für diese beiden Kontexte,
- eine fachlich legitimierte Entscheidungsbefugnis.

**Ablauf**

Die Situation macht einen Bedarf sichtbar; die Strategie macht ihn relevant. `validateNeedQualificationProposal` prüft zunächst die formale Zulässigkeit der vorgeschlagenen Primitive-Verbindung. Fachlich legitimierte Personen bewerten anschließend Begründung und Quelle. Bei Annahme werden `Key Result @ Strategy --translates-into--> Objective @ Need` und `Strategy --qualifies--> Need` modelliert und das Modell erneut validiert.

**Ergebnis**

Bei Ablehnung oder formalen Fehlern bleibt der Graph unverändert. Bei Annahme muss `qualifyingStrategies` die qualifizierende Strategie liefern. Erst dann ist der sichtbare Bedarf wirkungsrelevant, aber noch nicht wirksam.

Spezifikation: [`validateNeedQualificationProposal`](./spc/lib/core/src/O2I/Validation/Qualification.hs), [`qualifyingStrategies`](./spc/lib/core/src/O2I/Validation/Semantics.hs)

Weiterlesen: [Bedarfsqualifikation](./o2i.md#bedarfsqualifikation), [Wirkungsrelevanz](./o2i.md#wirkungsrelevanz)

## WTF "Intervention"?

> [!NOTE]
> **Intervention** = *Wie* verändern wir die Situation?

Intervention ist das operative Wie: eine gezielte Einwirkung auf eine Situation, die einen wirkungsrelevanten Bedarf adressiert. Sie kann als Projekt, Experiment, Programm oder Initiative auftreten, bleibt aber zunächst eine Handlungshypothese. Ob für die Bearbeitung des Bedarfs positive Wirkungsevidenz vorliegt, zeigt erst der Wirkungsnachweis.

**Mindestinhalt**

- der adressierte wirkungsrelevante Bedarf,
- mindestens eine `Action @ Intervention`, die die gezielte Einwirkung beschreibt,
- mindestens ein `Key Result @ Intervention`, das das angestrebte überprüfbare Ergebnis ausdrückt,
- mindestens eine `Action --contributes-to--> Key Result`-Relation innerhalb der Intervention,
- die Verbindung zur richtenden Strategie und ihrer Handlungs- und Erfolgslogik,
- der zu verändernde Situationsanker,
- der Zielbezug zur anschließenden Messung.

**Prüfung**

`assessModelSemantics` prüft als lokale semantische Mindestgültigkeit mindestens eine eigene Action, ein eigenes Key Result und einen Contribution-Zusammenhang zwischen solchen Elementen. `validateTraceability` prüft anschließend, ob die Intervention in einem vollständigen Wirkungstrace denselben wirkungsrelevanten Bedarf und Situationsanker mit richtender Strategie und zielbezogener Messung verbindet. `validateEvidenceReadinessAt` prüft davon getrennt den zugehörigen Nachweisentwurf vor Interventionsbeginn.

Spezifikation: [`assessModelSemantics`](./spc/lib/core/src/O2I/Validation/Semantics.hs), [`validateTraceability`](./spc/lib/core/src/O2I/Validation/Trace.hs), [`validateEvidenceReadinessAt`](./spc/lib/core/src/O2I/Validation/Readiness.hs)

Weiterlesen: [Intervention](./o2i.md#intervention)

## WTF "Messung"?

> [!NOTE]
> **Messung** = *Woran* erkennen wir Veränderung?

Messung ist das fachliche Woran: der Rahmen, in dem relevante Zustände und Veränderungen einer Situation beobachtbar werden. Ein KPI ist eine konkrete, stabile Messdefinition innerhalb dieses Rahmens. Messung ist noch keine Wirkung; erst die Nachweislogik begründet, warum Messwerte als Wirkungsevidenz gelten dürfen.

**Mindestinhalt**

- ein fachlicher Messrahmen als `Measure`,
- mindestens eine Messdimension,
- mindestens ein `KPI @ Measure`,
- die Mitgliedschaft mindestens eines eigenen KPI in mindestens einer eigenen Messdimension,
- eine stabile KPI-Definition mit Einheit, Wertebereich, Messmethode und fachlicher Interpretation,
- der beobachtete Situationsanker,
- die Rahmung durch Strategie,
- der Zielbezug durch Intervention.

**Prüfung**

`assessModelSemantics` prüft als lokale semantische Mindestgültigkeit mindestens eine eigene Messdimension, einen eigenen KPI und deren Membership-Zusammenhang. `validateTraceability` prüft anschließend die Rahmung durch Strategie, den Zielbezug durch Intervention und ob ein KPI denselben Situationsanker beobachtet, den die Intervention verändert. `validateEvidenceReadinessAt` prüft davon getrennt die stabile KPI-Definition und den zugehörigen Nachweisentwurf vor Interventionsbeginn.

Spezifikation: [`assessModelSemantics`](./spc/lib/core/src/O2I/Validation/Semantics.hs), [`validateTraceability`](./spc/lib/core/src/O2I/Validation/Trace.hs), [`validateEvidenceReadinessAt`](./spc/lib/core/src/O2I/Validation/Readiness.hs)

Weiterlesen: [Messung](./o2i.md#messung)

## WTF "Nachweisentwurf"?

> [!NOTE]
> **Nachweisentwurf** = *Wie wird die Bearbeitung überprüfbar?*

Für jeden Wirkungstrace einer Intervention muss vor Interventionsbeginn ein Nachweisentwurf vorliegen. Der Nachweisentwurf qualifiziert keinen Bedarf und weist noch keine Wirkung nach.

**Mindestinhalt**

- vollständiger Wirkungstrace,
- stabile KPI-Definition,
- geplanter Interventionsbeginn,
- quellengebundene Baseline am Situationsanker,
- Effektkriterium,
- Zielkriterium und Zieltermin,
- Zeitpunkt und Quellenbezug des Nachweisentwurfs.

**Prüfung**

`validateEvidenceReadinessAt` prüft Vollständigkeit, zeitliche Vorabfestlegung, Trace-Bezug, Wertebereiche und Herkunft. Nur ein fehlerfreies Ergebnis erzeugt ein `EvidenceReadyModel`.

Spezifikation: [`validateEvidenceReadinessAt`](./spc/lib/core/src/O2I/Validation/Readiness.hs)

Weiterlesen: [Evidenzbereitschaft](./o2i.md#evidenzbereitschaft), [Nachweislogik](./o2i.md#nachweislogik)

## HTH "Wirkungsnachweis"?

<!-- How the heck to demonstrate effectiveness? -->

> [!NOTE]
> **Nachweislogik** = *Warum* darf eine Messung als Evidenz für Wirkung gelten?

**Eingaben**

- ein `EvidenceReadyModel`,
- genau ein tatsächlicher Beginn je evidenzbereiter Intervention,
- mindestens eine zeitlich und quellengebundene Folgebeobachtung je Wirkungstrace,
- ein expliziter Bewertungszeitpunkt.

**Ablauf**

`assessEffectEvidenceAt` prüft Zeitpunkt, Trace-, KPI- und Situationsankerbezug sowie den Wertebereich jeder Folgebeobachtung. Anschließend bewertet es Effektkriterium und Zielkriterium unabhängig voneinander.

**Ergebnis**

Das `EvidenceAssessedModel` enthält getrennte Aussagen über positive Wirkungsevidenz und Zielerreichung. Das stützt plausible Attribution, aber keinen Kausalbeweis. `isEffectiveNeed` zeigt, ob mindestens eine Folgebeobachtung die Bearbeitung eines Bedarfs durch positive Wirkungsevidenz stützt.

Spezifikation: [`validateTraceability`](./spc/lib/core/src/O2I/Validation/Trace.hs) -> [`validateEvidenceReadinessAt`](./spc/lib/core/src/O2I/Validation/Readiness.hs) -> [`assessEffectEvidenceAt`](./spc/lib/core/src/O2I/Validation/Evidence.hs)

Weiterlesen: [Nachweislogik](./o2i.md#nachweislogik), [Wirkungstrace](./o2i.md#wirkungstrace), [Wirkungsevidenz](./o2i.md#wirkungsevidenz), [Plausible Attribution](./o2i.md#plausible-attribution)
