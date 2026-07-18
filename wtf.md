# WTF & HTH

`WTF` steht hier für `What the f**k?`, `HTH` für `How the heck?`. Dieses Dokument beantwortet naheliegende O2I-Fragen bewusst direkt: kurz genug für den Einstieg, präzise genug, um nichts Falsches mitzunehmen. Für die vollständige fachliche Begründung führen die Verweise in den O2I-Artikel.

> [!NOTE]
> `Mindestinhalt` bezeichnet, was fachlich vorliegen muss; ein bestimmtes Dokumentformat schreibt O2I nicht vor. `Prüfung` grenzt knapp ab, wann der Inhalt als das jeweilige O2I-Konstrukt gelten kann.

## WTF "Ethos"?

> [!NOTE]
> **Ethos** = *Wofür* stehen wir?

Ethos ist der kulturell-normative Kompass eines Akteurs: Wofür stehen wir, und was kommt für uns grundsätzlich infrage? Es besteht aus Leitprinzipien, die Handlungsoptionen bewerten und begrenzen. Ethos ist weder Zielbild noch Strategie.

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
- ein `Driver @ Mission`, der diesen Beitragsgrund ausdrückt,
- der Bezug zu den prägenden Leitprinzipien des Ethos.

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
- die begründende Verbindung zum `Driver @ Mission`,
- der Bezug zu den prägenden Leitprinzipien des Ethos.

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

Spezifikation: [`validateModelSemantics`](./spc/lib/core/src/O2I/Validation/Semantics.hs)

Weiterlesen: [Strategie](./o2i.md#strategie)

## WTF "Situation"?

> [!NOTE]
> **Situation** = *Wo* genau in der fachlichen Realität zeigt sich ein Bedarf?

Situation ist das fachliche Wo eines Bedarfs: der konkrete Arbeits-, Leistungs- oder Umfeldzusammenhang, in dem Veränderungsbedarf sichtbar wird. Business-Architecture-Artefakte wie Business Capability, Business Process, Business Object, Business Role, Value Stream oder Regulatory Constraint verankern diesen Zusammenhang. Technologie und Lösung gehören hier noch nicht hinein.

**Mindestinhalt**

- ein fachlich benannter Situationskontext,
- mindestens ein konkreter Situationsanker,
- dessen Typ als Business Capability, Business Process, Business Object, Business Role, Value Stream oder Regulatory Constraint,
- die Relation, durch die der Anker die Situation konstituiert.

**Prüfung**

Der Situationsanker muss nach seiner Business-Architecture-Semantik modelliert sein und den fachlichen Bezugsraum bestimmen. Eine technische Lösung oder Maßnahme ist kein Situationsanker.

Spezifikation: [`validateModelSemantics`](./spc/lib/core/src/O2I/Validation/Semantics.hs)

Weiterlesen: [Situation](./o2i.md#situation)

## WTF "Bedarf"?

> [!NOTE]
> **Bedarf** = *Was* wird benötigt?

Bedarf ist das fachliche Was: eine situationsbezogene Anforderung an Veränderung. Er beschreibt, was benötigt wird, nicht wie es umgesetzt wird. Ohne Situationsbezug bleibt die Aussage fachlich freischwebend und ist kein O2I-Bedarf.

**Mindestinhalt**

- ein `Driver @ Need`, der den situierten Veränderungsgrund beschreibt,
- ein `Objective @ Need`, das die benötigte qualitative Veränderung ausdrückt,
- eine `Situation --surfaces--> Need`-Relation,
- die Verankerung des Need-Drivers an einem konstituierenden Situationsanker,
- `Driver @ Need --grounds--> Objective @ Need`.

**Prüfung**

`validateModelSemantics` prüft die vollständige Situierung. Eine Lösung, Maßnahme oder technische Anforderung ersetzt weder Need-Driver noch Need-Objective.

Spezifikation: [`validateModelSemantics`](./spc/lib/core/src/O2I/Validation/Semantics.hs)

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
- eine `Action @ Intervention`, die die gezielte Einwirkung beschreibt,
- ein `Key Result @ Intervention`, das das angestrebte überprüfbare Ergebnis ausdrückt,
- die Verbindung zur richtenden Strategie und ihrer Handlungs- und Erfolgslogik,
- der zu verändernde Situationsanker,
- der Zielbezug zur anschließenden Messung.

**Prüfung**

Die Intervention ist als Handlungshypothese nur nachweisfähig, wenn sie in einem vollständigen Wirkungstrace denselben Bedarf und Situationsanker mit Strategie und Messung verbindet.

Spezifikation: [`validateTraceability`](./spc/lib/core/src/O2I/Validation/Trace.hs)

Weiterlesen: [Intervention](./o2i.md#intervention)

## WTF "Messung"?

> [!NOTE]
> **Messung** = *Woran* erkennen wir Veränderung?

Messung ist das fachliche Woran: der Rahmen, in dem relevante Zustände und Veränderungen einer Situation beobachtbar werden. Ein KPI ist eine konkrete, stabile Messdefinition innerhalb dieses Rahmens. Messung ist noch keine Wirkung; erst die Nachweislogik begründet, warum Messwerte als Wirkungsevidenz gelten dürfen.

**Mindestinhalt**

- ein fachlicher Messrahmen als `Measure`,
- eine Messdimension für die zugehörigen KPIs,
- mindestens ein `KPI @ Measure`,
- eine stabile KPI-Definition mit Einheit, Wertebereich, Messmethode und fachlicher Interpretation,
- der beobachtete Situationsanker,
- Rahmung durch Strategie und Zielbezug durch Intervention.

**Prüfung**

Ein KPI muss denselben Situationsanker beobachten, den die Intervention verändert. Seine Definition bleibt über Baseline, Kriterien und Folgebeobachtungen stabil.

Spezifikation: [`validateEvidenceReadinessAt`](./spc/lib/core/src/O2I/Validation/Readiness.hs)

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
