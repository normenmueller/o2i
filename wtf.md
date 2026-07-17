# WTF & HTH

`WTF` steht hier für `What the f**k?`, `HTH` für `How the heck?`. Dieses Dokument beantwortet naheliegende O2I-Fragen bewusst direkt: kurz genug für den Einstieg, präzise genug, um nichts Falsches mitzunehmen. Für die vollständige fachliche Begründung führen die Verweise in den O2I-Artikel.

## WTF "Ethos"?

> [!NOTE]
> **Ethos** = *Wofür* stehen wir?

Ethos ist der kulturell-normative Kompass eines Akteurs: Wofür stehen wir, und was kommt für uns grundsätzlich infrage? Es besteht aus Leitprinzipien, die Handlungsoptionen bewerten und begrenzen. Ethos ist weder Zielbild noch Strategie.

Weiterlesen: [Ethos](./o2i.md#ethos)

## WTF "Mission"?

> [!NOTE]
> **Mission** = *Warum* gibt es uns?

Mission beantwortet, warum es einen Akteur gibt und welchen dauerhaften Beitrag er leisten soll. Sie wird vom Ethos geprägt, legt aber weder einen Zukunftszustand noch den Weg dorthin fest.

Weiterlesen: [Mission](./o2i.md#mission)

## WTF "Vision"?

> [!NOTE]
> **Vision** = *Wohin* wollen wir wirken?

Vision beschreibt, wohin ein Akteur wirken will: den angestrebten, orientierenden Zukunftszustand. Sie gibt Richtung, aber noch keinen Weg. Wer bereits konkrete Handlungen aufzählt, ist gedanklich bei Strategie oder Intervention angekommen.

Weiterlesen: [Vision](./o2i.md#vision)

## WTF "Strategie"?

> [!NOTE]
> **Strategie** = *Wie* verwirklichen wir unsere Vision?

Strategie ist kein Wunschzettel. Sie beschreibt das strategische Wie: die begründete und kohärente Wegentscheidung, wie ein handlungsfähiger Akteur seine Vision unter gegebenen Bedingungen verwirklichen will. Sie legt sich gegenüber Alternativen unterscheidbar fest, bindet Handlungen und Ressourcen und muss als Ganzes kohärent sein.

Weiterlesen: [Strategie](./o2i.md#strategie)

## WTF "Situation"?

> [!NOTE]
> **Situation** = *Wo* genau in der fachlichen Realität zeigt sich ein Bedarf?

Situation ist das fachliche Wo eines Bedarfs: der konkrete Arbeits-, Leistungs- oder Umfeldzusammenhang, in dem Veränderungsbedarf sichtbar wird. Business-Architecture-Artefakte wie Business Capability, Business Process, Business Object, Business Role, Value Stream oder Regulatory Constraint verankern diesen Zusammenhang. Technologie und Lösung gehören hier noch nicht hinein.

Weiterlesen: [Situation](./o2i.md#situation)

## WTF "Bedarf"?

> [!NOTE]
> **Bedarf** = *Was* wird benötigt?

Bedarf ist das fachliche Was: eine situationsbezogene Anforderung an Veränderung. Er beschreibt, was benötigt wird, nicht wie es umgesetzt wird. Ohne Situationsbezug bleibt die Aussage fachlich freischwebend und ist kein O2I-Bedarf.

Weiterlesen: [Bedarf](./o2i.md#bedarf)

## WTF "Qualifikationsvorlage"?

> [!NOTE]
> **Qualifikationsvorlage** = *Was muss für die Qualifikationsprüfung vorliegen?*

- vollständig situierter Bedarf mit `Driver`, `Objective` und Situationsanker,
- Referenz auf die bestehende Strategie, an der sich der Einreicher ausgerichtet hat,
- vorgeschlagene Verbindung `Key Result @ Strategy --translates-into--> Objective @ Need`,
- fachliche Begründung und nachvollziehbarer Quellenbezug.

Agentic AI kann die Verbindung vorschlagen und begründen. Nach vollständiger Situierung des Bedarfs und vor der Modellierung von `translates-into` und `qualifies` prüft die O2I-Spezifikation ihre formale Zulässigkeit. Formale Fehler führen zu keinem Kandidaten und zu keiner Graphänderung. Einen positiven `NeedQualificationCandidate` prüfen fachlich legitimierte Personen: Ablehnung lässt den Graphen unverändert; Annahme modelliert beide Relationen, validiert das Modell erneut und macht die qualifizierende Strategie über `qualifyingStrategies` abfragbar.

Haskell: [`validateNeedQualificationProposal`](./spc/src/lib/O2I/Validation/Qualification.hs)

Ein Nachweisentwurf gehört nicht zur Qualifikationsvorlage. Eine organisationsspezifische Einreichungsregel kann beides gemeinsam verlangen; die O2I-Gates bleiben dennoch unabhängig.

Weiterlesen: [Bedarfsqualifikation](./o2i.md#bedarfsqualifikation), [Evidenzbereitschaft](./o2i.md#evidenzbereitschaft)

## HTH "Bedarfsqualifikation"?

<!-- How the heck to qualify need? -->

Die Situation macht einen Bedarf sichtbar; die Strategie macht ihn relevant. Dafür werden `Strategy --qualifies--> Need` und ihre Primitive-Begründung modelliert, beispielsweise `Key Result @ Strategy --translates-into--> Objective @ Need`. Nach erneuter Modellvalidierung muss `qualifyingStrategies` die Strategie liefern. Erst dann ist der sichtbare Bedarf wirkungsrelevant, aber noch nicht wirksam.

Haskell: [`validateNeedQualificationProposal`](./spc/src/lib/O2I/Validation/Qualification.hs), [`qualifyingStrategies`](./spc/src/lib/O2I/Validation/Semantics.hs)

Weiterlesen: [Bedarfsqualifikation](./o2i.md#bedarfsqualifikation), [Wirkungsrelevanz](./o2i.md#wirkungsrelevanz)

## WTF "Intervention"?

> [!NOTE]
> **Intervention** = *Wie* verändern wir die Situation?

Intervention ist das operative Wie: eine gezielte Einwirkung auf eine Situation, die einen wirkungsrelevanten Bedarf adressiert. Sie kann als Projekt, Experiment, Programm oder Initiative auftreten, bleibt aber zunächst eine Handlungshypothese. Ob für die Bearbeitung des Bedarfs positive Wirkungsevidenz vorliegt, zeigt erst der Wirkungsnachweis.

Weiterlesen: [Intervention](./o2i.md#intervention)

## WTF "Messung"?

> [!NOTE]
> **Messung** = *Woran* erkennen wir Veränderung?

Messung ist das fachliche Woran: der Rahmen, in dem relevante Zustände und Veränderungen einer Situation beobachtbar werden. Ein KPI ist eine konkrete, stabile Messdefinition innerhalb dieses Rahmens. Messung ist noch keine Wirkung; erst die Nachweislogik begründet, warum Messwerte als Wirkungsevidenz gelten dürfen.

Weiterlesen: [Messung](./o2i.md#messung)

## WTF "Nachweisentwurf"?

> [!NOTE]
> **Nachweisentwurf** = *Wie wird die Bearbeitung überprüfbar?*

Für jeden Wirkungstrace einer Intervention muss vor Interventionsbeginn ein Nachweisentwurf vorliegen. Er verbindet Measure und KPI mit Baseline, Effekt- und Zielkriterium, Zieltermin sowie Quellenbezug. Der Nachweisentwurf qualifiziert keinen Bedarf und weist noch keine Wirkung nach. Er ist die Eingabegrundlage, aus der `validateEvidenceReadinessAt` ein `EvidenceReadyModel` erzeugen kann.

Haskell: [`validateEvidenceReadinessAt`](./spc/src/lib/O2I/Validation/Readiness.hs)

Weiterlesen: [Evidenzbereitschaft](./o2i.md#evidenzbereitschaft), [Nachweislogik](./o2i.md#nachweislogik)

## HTH "Wirkungsnachweis"?

<!-- How the heck to demonstrate effectivness? -->

> [!NOTE]
> **Nachweislogik** = *Warum* darf eine Messung als Evidenz für Wirkung gelten?

Wirkung ist nicht nachgewiesen, nur weil ein KPI grün wird. O2I verlangt zunächst einen vollständigen relationalen Wirkungstrace. Der Nachweisentwurf liefert die Eingaben, aus denen `validateEvidenceReadinessAt` vor Interventionsbeginn ein `EvidenceReadyModel` erzeugt; eine spätere Folgebeobachtung desselben KPI am selben Situationsanker liefert die Bewertungsgrundlage. Das Effektkriterium bewertet die Veränderung gegenüber der Baseline, das Zielkriterium getrennt die Zielerreichung. Das stützt plausible Attribution, aber keinen Kausalbeweis.

Haskell: [`validateTraceability`](./spc/src/lib/O2I/Validation/Trace.hs) -> [`validateEvidenceReadinessAt`](./spc/src/lib/O2I/Validation/Readiness.hs) -> [`assessEffectEvidenceAt`](./spc/src/lib/O2I/Validation/Evidence.hs)

Weiterlesen: [Nachweislogik](./o2i.md#nachweislogik), [Wirkungstrace](./o2i.md#wirkungstrace), [Wirkungsevidenz](./o2i.md#wirkungsevidenz), [Plausible Attribution](./o2i.md#plausible-attribution)
