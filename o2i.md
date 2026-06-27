---
title: "Von der Orientierung zur Wirkung\\thanks{Publiziert unter \\url{https://github.com/normenmueller/o2i}}"
subtitle: "Begriffe und Relationen für wirksames Handeln"
author: nemron
version: "0.1 (wip)"
abstract: |
  Wie werden Orientierung, Formierung, Kontextualisierung und Operationalisierung so verbunden, dass nachvollziehbare Wirkung entsteht?
lang: de-DE
figureTitle: "Abb."
figPrefix:
  - "Abb."
  - "Abb."
secPrefix:
  - "Kap."
  - "Kap."
toc: yes
toc-depth: 3
callout-theme: gray
---

\newpage
\begin{flushright}
\begin{minipage}{0.6\textwidth}
\itshape
``We cannot solve our problems with the same thinking we used when we created them.''\\[0.5em]
\raggedleft
--- Albert Einstein zugeschrieben
\end{minipage}
\end{flushright}
\newpage

# Einleitung

O2I beschreibt, wie Orientierung unter gegebenen Bedingungen in strategische Formierung, kontextualisierte Bedarfe, wirkungsgerichtete Operationalisierung und nachvollziehbare Wirkung überführt wird.

O2I begründet fachliche Relationen wie `Strategy --qualifies--> Need` durch Verbindungen zwischen kontextualisierten O2I-Primitives. O2I-Kontexte geben Bedeutung; O2I-Primitives tragen die modellierten Inhalte. Der Wirkungsgraph entsteht aus diesen Primitives und ihren Relationen.

> *Disclaimer*: Der Artikel ist bewusst knapp gehalten. Er ist kein Lehrbuch und keine breite Literaturabhandlung, sondern ein wissenschaftlich fundiertes Begriffs- und Modellierungsdokument mit klaren Definitionen, Quellenankern und expliziten Autorenableitungen.

# Fundament

## Literaturbasis

Bourne, Humphrey; Jenkins, Mark; Parry, Emma (2019): "Mapping Espoused Organizational Values". In: *Journal of Business Ethics*, 159, S. 133-148. URL: https://doi.org/10.1007/s10551-017-3734-9.

Barr, Stacey (2014): *Practical Performance Measurement: Using the PuMP Blueprint for Fast, Easy and Engaging KPIs*. Samford, Qld: The PuMP Press. URL: https://www.staceybarr.com/books/practicalperformancemeasurement/.

Chua, Nathania; Miska, Christof; Mair, Johanna; Stahl, Guenter K. (2024): "Purpose in Management Research: Navigating a Complex and Fragmented Area of Study". In: *Academy of Management Annals*, 18(2). URL: https://doi.org/10.5465/annals.2022.0186.

Collins, James C.; Porras, Jerry I. (1996): "Building Your Company's Vision". In: *Harvard Business Review*, 74(5), S. 65-77. URL: https://hbr.org/1996/09/building-your-companys-vision.

Doerr, John (2018): *Measure What Matters: How Google, Bono, and the Gates Foundation Rock the World with OKRs*. New York: Portfolio/Penguin.

George, Gerard; Haas, Martine R.; McGahan, Anita M.; Schillebeeckx, Simon J. D.; Tracey, Paul (2023): "Purpose in the For-Profit Firm: A Review and Framework for Management Research". In: *Journal of Management*, 49(6), S. 1841-1869. URL: https://doi.org/10.1177/01492063211006450.

Hamel, Gary; Prahalad, C. K. (1989): "Strategic Intent". In: *Harvard Business Review*, 67(3), S. 63-76.

Mintzberg, Henry; Waters, James A. (1985): "Of Strategies, Deliberate and Emergent". In: *Strategic Management Journal*, 6(3), S. 257-272.

Parmenter, David (2020): *Key Performance Indicators: Developing, Implementing, and Using Winning KPIs*. 4. Aufl. Hoboken, NJ: John Wiley & Sons. URL: https://www.oreilly.com/library/view/key-performance-indicators/9781119620778/.

Porter, Michael E. (1996): "What Is Strategy?" In: *Harvard Business Review*, 74(6), S. 61-78.

Rumelt, Richard P. (2011): *Good Strategy/Bad Strategy: The Difference and Why It Matters*. London: Profile Books.

Schein, Edgar H. (2010): *Organizational Culture and Leadership*. 4. Aufl. San Francisco: Jossey-Bass. URL: \url{https://www.oreilly.com/library/view/organizational-culture-and/9780470190609/}.

The Open Group (2025): *The TOGAF Standard, 10th Edition*. C220.\
URL: \url{https://publications.opengroup.org/c220}.

The Open Group (2026): *ArchiMate 4 Specification*. C260.\
URL: \url{https://publications.opengroup.org/standards/archimate/c260}.

## Literaturfunktion

Die Literaturquellen werden nicht gleichgewichtig verwendet, sondern nach ihrer Funktion innerhalb von O2I:

Rumelt (2011), Porter (1996), Hamel und Prahalad (1989) sowie Mintzberg und Waters (1985) stützen die Formierung innerhalb von O2I: Diagnose, strategische Absicht, leitende Handlungslogik, Positionierung, Trade-offs, Fit, Kohärenz sowie intendierte und realisierte Strategie.

Doerr (2018) stützt die Operationalisierung über Objectives und Key Results als überprüfbare Umsetzungs- und Evidenzformen.

Parmenter (2020) stützt Messung, Performance-Logik, kritische Erfolgsfaktoren und KPI-Disziplin. Barr (2014) ergänzt die methodische KPI-Entwicklung über eine praktische Performance-Measurement-Methodik.

Collins und Porras (1996), Schein (2010) und Bourne, Jenkins und Parry (2019) stützen Leitprinzipien als kulturell verankerte, normative Orientierungsgröße. George, Haas, McGahan, Schillebeeckx und Tracey (2023) und Chua, Miska, Mair und Stahl (2024) ergänzen den aktuellen Purpose-Diskurs und schärfen Mission als Existenzzweck.

The Open Group (2025, 2026) stützt die Modellierungsebene: TOGAF liefert den Enterprise-Architecture-Bezug, ArchiMate liefert die standardisierte Modellierungssprache, mit der O2I-Modelle an Architekturartefakte anschlussfähig werden.

Die Literaturquellen begründen damit unterschiedliche Funktionen innerhalb von O2I: Orientierung wird strategisch formiert, Formierung wird in wirkungsgerichtete Interventionen operationalisiert, und Wirkung wird über Messung und Nachweislogik nachvollziehbar gemacht.

## Definitionsregel

Eine Definition wird nicht bloß behauptet. Sie wird nur verwendet, wenn sie entweder direkt durch eine Quelle gestützt oder als Autorenableitung aus den verwendeten Quellen nachvollziehbar gemacht wird. Jede Definition und jede tragende Argumentationskette erhält deshalb einen Quellenanker oder eine explizite Kennzeichnung als Autorenableitung.

*Direkter Quellenanker:* Der Begriff oder die Argumentationslogik wird unmittelbar aus einer Quelle übernommen oder eng paraphrasiert.

*Autorenableitung in Anlehnung an ...:* Der Artikel bildet eine eigene Systematisierung, die auf mindestens einer Quelle beruht, aber über deren Wortlaut oder Begriffssystem hinausgeht.

# Terminologie {#sec:terminologie}

Die Terminologie beschreibt eine *teleologische Wirkungslogik*: von Orientierung über Formierung, Kontextualisierung und Operationalisierung zu Wirkung. Diese fünf *fachlichen Domänen* ordnen die Standardbegriffe, welche O2I anschließend als O2I-Kontexte formalisiert.

## Orientierung 

Orientierung bezeichnet in O2I die fachliche Domäne, in der ein handlungsfähiger Akteur seinen normativen Rahmen, seinen grundlegenden Existenzzweck und seinen angestrebten Zukunftszustand bestimmt.

![O2I Orientierung](<img/O2I Orientierung.png>){#fig:o2i-orientation-view width=50%}

@Fig:o2i-orientation-view zeigt die Orientierungsbestandteile von O2I: Ethos, Mission und Vision sowie ihre fachlichen Beziehungen. Die Darstellung greift die spätere Kontextsicht des Metamodells vor, dient hier jedoch der terminologischen Einordnung.

### Ethos

> [!definition]
> Das **Ethos** (en.: *ethos*; meta: `Ethos`)[^ethos] bezeichnet den kulturell-normativen Orientierungsrahmen eines handlungsfähigen Akteurs.
>
> Ein **Leitprinzip** (en.: *principle*; meta: `Principle`)[^principles] bezeichnet einen einzelnen kulturell verankerten und normativen Grundsatz eines handlungsfähigen Akteurs. Es beschreibt, wofür der Akteur steht, welche Maßstäbe sein Handeln leiten und nach welchen Kriterien Handlungsoptionen als gut, schlecht, akzeptabel oder nicht akzeptabel bewertet werden.
>
> Mehrere Leitprinzipien bilden zusammen das Ethos eines Akteurs.
>
> > [!tldr] Ethos - \textsc{Wofür} stehen wir?
>
> [^ethos]: *Autorenableitung in Anlehnung an Collins und Porras (1996), Schein (2010), Bourne, Jenkins und Parry (2019), Rumelt (2011) und Porter (1996)*: Ethos wird hier als kulturell-normativer Orientierungsrahmen verstanden.
>
> [^principles]: *Autorenableitung in Anlehnung an Collins und Porras (1996), Schein (2010), Bourne, Jenkins und Parry (2019), Rumelt (2011) und Porter (1996)*: Leitprinzipien werden hier als normative Grundsätze verstanden, die Handlungsoptionen begrenzen, Prioritäten prägen und Entscheidungen konsistent machen.

### Mission 

> [!definition]
> Eine **Mission** (en.: *mission*; meta: `Mission`)[^mission] bezeichnet den durch das `Ethos` eines handlungsfähigen Akteurs geprägten *grundlegenden Existenzzweck*: warum der Akteur existiert und welchen Beitrag er leisten soll.
> 
> > [!tldr] Mission - \textsc{Warum} gibt es uns?
>
> [^mission]: *Autorenableitung in Anlehnung an Rumelt (2011)*: Rumelt definiert Mission nicht als eigenen Kernbegriff, trennt Strategie aber klar von Ambition, Vision und anderen Führungsbegriffen.

### Vision 

> [!definition]
> Eine **Vision** (en.: *vision*; meta: `Vision`)[^vision] bezeichnet einen vom `Ethos` geprägten und durch die [Mission](#mission) begründeten, von einem handlungsfähigen Akteur *angestrebten, orientierenden Zukunftszustand*: wohin der Akteur wirken will, ohne bereits festzulegen, wie diese Wirkung erreicht wird.
> 
> > [!tldr] Vision - \textsc{Wohin} wollen wir wirken?
>
> [^vision]: *Autorenableitung in Anlehnung an Rumelt (2011)*: Die Definition ist eine redaktionelle Systematisierung. Rumelt liefert vor allem die Abgrenzung: Vision und Ambition sind keine Strategie, weil sie noch nicht erklären, wie eine wesentliche Herausforderung überwunden wird.

*Hinweis*: Eine Vision ist qualitativ, richtungsgebend aber noch keine Wegentscheidung.

## Formierung

Formierung bezeichnet in O2I die fachliche Domäne, in der Orientierung unter gegebenen Bedingungen in eine begründete strategische Wegentscheidung und daraus abgeleitete kritische Erfolgsfaktoren überführt wird.

### Strategie

> [!definition]
> **Strategie** (en.: *strategy*; meta: `Strategy`)[^strategy] bezeichnet die *begründete und kohärente Wegentscheidung* eines handlungsfähigen Akteurs[^actor], der legitim entscheiden, Ressourcen binden und Verantwortung tragen kann. Mit einer Strategie legt dieser Akteur fest, wie er seine [Vision](#vision) unter gegebenen Bedingungen verwirklichen will und sich damit gegenüber relevanten Alternativen, Wettbewerbern oder Vergleichsangeboten differenziert.
>
> > [tl;dr] Strategie - \textsc{Wie} verwirklichen wir unsere Vision?
>
> [^strategy]: *Quellenanker*: Rumelt (2011) für Strategie als kohärente Antwort auf eine wesentliche Herausforderung; Porter (1996) für Positionierung, Trade-offs und Fit; Mintzberg und Waters (1985) für Strategie als intendiertes und realisiertes Handlungsmuster; Parmenter (2020) für Strategie als Weg zur Verwirklichung der Vision und als Grundlage für die Ableitung von CSFs und Performance-Maßen.

[^actor]: Organisationseinheiten besitzen nicht automatisch eine eigene Strategie. Nach der hier verwendeten Definition gilt dies nur, wenn sie legitim entscheiden, Ressourcen binden, Verantwortung tragen und eine eigene Diagnose, Guiding Policy, Trade-offs und kohärente Handlungslogik ausbilden können.

Als Artefakt muss eine Strategie ihre Bestandteile dokumentieren. Eine explizit formulierte Strategie liefert mindestens Geltungsbereich, strategische Verankerung, abgeleitete Leitplanken, Diagnose, strategische Absicht, Guiding Policy, Positionierung, Trade-offs, kohärente Handlungsfestlegungen und Fit.

![O2I Strategiebestandteile](<img/O2I Strategy Constituents.png>){#fig:o2i-strategy-constituents-view}

@Fig:o2i-strategy-constituents-view zeigt O2I Strategiebestandteile und ihre fachlichen Beziehungen. Diese Bestandteile sind keine O2I-Kontexte und keine O2I-Primitives; sie beschreiben die innere fachliche Struktur einer explizit formulierten Strategie.

<!--
ED note:
- Scope frames Diagnosis: passt, weil Geltungsbereich die Einheit bestimmt, für die die Herausforderung gilt.
- Guardrails constrain Guiding Policy: passt, weil Leitplanken Vorgaben/Restriktionen setzen, ohne Diagnose zu ersetzen.
- Diagnosis justifies Intent / Guiding Policy: passt, weil Diagnose erklärt, warum eine Wegentscheidung nötig ist.
- Intent orients Guiding Policy: passt, weil strategische Absicht den angestrebten Beitrag zur Vision vorgibt.
- Guiding Policy guides Positioning / Coherent Action Commitments: passt, weil sie die Stoßrichtung und ausführbare Logik prägt.
- Positioning requires Trade-offs: passt Porter-semantisch.
- Trade-offs constrain Coherent Action Commitments: passt, weil Nicht-Entscheidungen Handlungsfestlegungen begrenzen.
- Anchoring enables Coherent Action Commitments: passt, weil der Text klärt, dass Verankerung Strategie insgesamt betrifft, aber in Handlungsfestlegungen wirksam wird.
- Fit validates Positioning / Trade-offs / Coherent Action Commitments: passt, weil Fit als Kohärenznachweis gelesen wird. Einzige Restnuance: `validates` ist bewusst stark. Da ihr Fit als **Kohärenznachweis** formuliert habt, ist das vertretbar.
-->

#### Geltungsbereich

> [!definition]
> Der **Geltungsbereich einer Strategie**[^scope] bezeichnet die organisatorische oder sachliche Einheit, für die eine Wegentscheidung gilt.
>
> [^scope]: *Autorenableitung in Anlehnung an Rumelt (2011) und Porter (1996)*: Eine Wegentscheidung ist nur dann sinnvoll abgrenzbar, wenn klar ist, für welche Herausforderung, welche Positionierung und welches Aktivitätssystem sie gilt.

Der Geltungsbereich rahmt die Strategie: Er legt fest, für welche Einheit Diagnose, strategische Absicht, Positionierung, Trade-offs, Handlungsfestlegungen und Fit zu beurteilen sind. Ohne klaren Geltungsbereich bleibt unbestimmt, worauf sich die Wegentscheidung bezieht und wer sie verantworten kann.

#### Strategische Verankerung

> [!definition]
> **Strategische Verankerung**[^anchoring] bezeichnet die organisatorische und prozessuale Einbettung, durch die eine Strategie entscheidbar, verantwortbar und umsetzbar wird: organisatorisch durch Zeitraum, Verantwortungsbereich, Entscheidungsebene und tragende Verantwortlichkeiten; prozessual durch Entscheidungswege und Umsetzungslogik.
>
> [^anchoring]: *Autorenableitung in Anlehnung an Rumelt (2011) und Porter (1996)*: Eine Strategie kann nur kohärent wirksam werden, wenn ihre Wegentscheidung nicht isoliert bleibt, sondern durch Verantwortlichkeiten, Entscheidungswege und eine tragfähige Umsetzungslogik in der Organisation verankert ist. Rumelt stützt die Kohärenz der Handlungsfestlegungen; Porter stützt die Einbettung in ein konsistentes Aktivitätssystem.

Strategische Verankerung betrifft die Strategie insgesamt; sie wird besonders dort wirksam, wo kohärente Handlungsfestlegungen entscheidbar, verantwortbar und umsetzbar werden müssen.

#### Abgeleitete Leitplanken

> [!definition]
> **Abgeleitete Leitplanken**[^derived-guardrails] bezeichnen Vorgaben aus übergeordneten Strategien, Agenden, Prinzipien oder verbindlichen Rahmenbedingungen, an die eine Strategie anschließen muss.
>
> [^derived-guardrails]: *Autorenableitung in Anlehnung an Rumelt (2011) und Porter (1996)*: Strategien stehen häufig in übergeordneten und untergeordneten Entscheidungszusammenhängen. Übergeordnete Strategien können Richtung, Prioritäten, Restriktionen oder Zielbezüge setzen; die untergeordnete Strategie muss daraus jedoch eine eigene kohärente Antwort für ihren Geltungsbereich bilden. Rumelt stützt, dass eine untergeordnete Strategie trotz übergeordneter Vorgaben eine eigene kohärente Antwort auf ihre spezifische Herausforderung bilden muss; Porter stützt, dass diese Antwort mit Positionierung, Trade-offs und Aktivitätssystem des jeweiligen Geltungsbereichs konsistent sein muss.

Abgeleitete Leitplanken begrenzen und orientieren die Guiding Policy, ohne die untergeordnete Strategie vollständig festzulegen. Sie sind keine eigene Diagnose und keine fertige Handlungslogik; sie beschreiben die Vorgaben, an die eine Strategie anschließen muss, während sie für ihren Geltungsbereich eine eigenständige kohärente Antwort bildet.

<!--
ED note:
- Rumelt hilft gegen falsche Ableitung: Eine untergeordnete Strategie darf nicht bloß Vorgaben übernehmen. Sie muss für ihren eigenen Geltungsbereich eine eigene Diagnose, Guiding Policy und kohärente Handlungslogik bilden. Deshalb gibt eine übergeordnete Strategie Leitplanken, determiniert die untergeordnete Strategie aber nicht vollständig.
- Porter hilft gegen beliebige Anschlussfähigkeit: Eine Strategie ist nur tragfähig, wenn Aktivitäten, Trade-offs und Positionierung zueinander passen. Wenn eine übergeordnete Strategie Leitplanken setzt, muss die untergeordnete Strategie diese so aufnehmen, dass ihr eigenes Aktivitätssystem weiterhin kohärent ist.
-->

Eine übergeordnete Strategie richtet eine untergeordnete Strategie aus: Sie gibt Richtung, Prioritäten, Leitplanken, Restriktionen oder Zielbezüge vor, ohne die untergeordnete Strategie vollständig zu determinieren. Die untergeordnete Strategie muss daraus eine eigene Diagnose, Guiding Policy und kohärente Handlungsfestlegungen für ihren eigenen Geltungsbereich ableiten.

#### Diagnose

> [!definition]
> Die **Diagnose**[^diagnosis] beschreibt die für den jeweiligen Geltungsbereich strategisch entscheidende Herausforderung: Sie erklärt, warum die Vision unter gegebenen Bedingungen nicht ohne eine kohärente Wegentscheidung erreichbar ist.
>
> [^diagnosis]: *Quellenanker*: Rumelt (2011).

Eine Diagnose reduziert Komplexität, indem sie nicht die Gesamtheit aller beobachtbaren Probleme sammelt, sondern die strategisch relevante Herausforderung herausarbeitet. Dadurch wird zunächst bestimmbar, welchen Beitrag die strategische Absicht zur Vision leisten soll; erst danach wird bewertbar, ob die Guiding Policy tatsächlich auf diese Herausforderung passt.

<!--
ED note:
Diagnose muss eigenständig bleiben. Eine übergeordnete Strategie kann Leitplanken setzen, aber sie darf die Diagnose der untergeordneten Strategie nicht ersetzen. Sonst wäre die untergeordnete Strategie nur abgeleitete Planung, keine eigene Strategie.
-->

#### Strategische Absicht

> [!definition]
> **Strategische Absicht**[^intent] bezeichnet den angestrebten Beitrag einer Strategie zur [Vision](#vision). Sie macht deutlich, welche Wirkung oder welcher Fortschritt durch die Wegentscheidung erreichbar werden soll, ohne bereits die konkrete Intervention festzulegen.
>
> [^intent]: *Autorenableitung in Anlehnung an Hamel und Prahalad (1989), Rumelt (2011), Mintzberg und Waters (1985) und Parmenter (2020)*: Hamel und Prahalad stützen Strategic Intent als langfristig ausrichtende strategische Absicht; Rumelt stützt die Abgrenzung von Vision, Herausforderung und strategischer Antwort; Mintzberg und Waters stützen Strategie als intendiertes Handlungsmuster; Parmenter stützt Strategie als Weg zur Verwirklichung der Vision.

#### Guiding Policy / leitende Handlungslogik

> [!definition]
> Die **Guiding Policy**[^guiding-policy] bezeichnet den grundsätzlichen strategischen Ansatz, mit dem die diagnostizierte Herausforderung im Sinne der strategischen Absicht adressiert wird.
>
> [^guiding-policy]: *Quellenanker*: Rumelt (2011).

Die Guiding Policy übersetzt Diagnose und strategische Absicht in eine leitende Handlungslogik: Die Diagnose begründet, welche Herausforderung zu bewältigen ist; die strategische Absicht klärt, welchen Beitrag zur Vision die Strategie leisten soll; die Guiding Policy legt fest, mit welchem Ansatz diese Herausforderung adressiert wird.

<!--
ED note:
Strategische Absicht: Absicht = angestrebter Beitrag
Guiding Policy = gewählter Ansatz.
-->

Die Guiding Policy ist damit weder Vision noch strategische Absicht noch konkrete Handlungsfestlegung. Sie beschreibt nicht den angestrebten Zukunftszustand, nicht den intendierten Beitrag zur Vision und noch nicht die einzelnen strategierelevanten Entscheidungen oder Ressourcenbindungen. Sie leitet Positionierung und kohärente Handlungsfestlegungen, ohne diese bereits vollständig festzulegen.

#### Strategische Positionierung

> [!definition]
> **Strategische Positionierung**[^positioning] bezeichnet die bewusste Festlegung, wodurch sich der gewählte strategische Ansatz von relevanten Alternativen unterscheidet und welche Position dadurch eingenommen oder gestärkt wird.
>
> [^positioning]: *Quellenanker*: Porter (1996) für Strategie als Wahl einer unterscheidbaren Position und eines dazu passenden Aktivitätssystems. *Autorenableitung in Anlehnung an Porter (1996) und Rumelt (2011)*: In O2I konkretisiert Positionierung die Guiding Policy, indem sie festlegt, wodurch sich der gewählte strategische Ansatz im jeweiligen Geltungsbereich von relevanten Alternativen unterscheidet.

Die Guiding Policy beschreibt den grundsätzlichen strategischen Ansatz; die strategische Positionierung konkretisiert, wodurch dieser Ansatz gegenüber relevanten Alternativen unterscheidbar wird. Positionierung ist damit positiver als Trade-offs: Sie beschreibt, wofür der gewählte Weg steht, während Trade-offs festlegen, was bewusst nicht getan wird, um diese Position nicht zu verwässern.

Strategische Positionierung richtet kohärente Handlungsfestlegungen aus. Entscheidungen und Ressourcenbindungen passen nur dann zur Strategie, wenn sie die gewählte Position stützen, sichtbar machen oder gegen relevante Alternativen abgrenzen.

#### Trade-offs

> [!definition]
> **Trade-offs**[^trade-offs] bezeichnen bewusste Nicht-Entscheidungen: Sie legen fest, was ein handlungsfähiger Akteur nicht tut, um die gewählte Position nicht zu verwässern.
>
> [^trade-offs]: *Quellenanker*: Porter (1996) für Trade-offs als notwendige Bedingung strategischer Positionierung.

Trade-offs folgen aus Positionierung: Wer eine unterscheidbare Position einnimmt, kann nicht zugleich alle alternativen Wege offenhalten. Trade-offs schützen Fokus, Ressourcen und Identität der Strategie, indem sie verhindern, dass Handlungsfestlegungen die gewählte Position verwässern.

Trade-offs sind keine konkreten Maßnahmen. Sie begrenzen kohärente Handlungsfestlegungen, indem sie festlegen, welche Entscheidungen, Aktivitäten oder Ressourcenbindungen nicht zur Strategie passen.

#### Kohärente Handlungsfestlegungen

> [!definition]
> **Kohärente Handlungsfestlegungen**[^coherent-actions] bezeichnen strategierelevante Entscheidungen und Ressourcenbindungen, die die Guiding Policy ausführbar machen und zueinander passen müssen.
>
> [^coherent-actions]: *Quellenanker*: Rumelt (2011) für kohärente Aktionen als Bestandteil guter Strategie. *Autorenableitung in Anlehnung an Porter (1996)*: Handlungsfestlegungen müssen zur gewählten Position, den Trade-offs und dem Aktivitätssystem passen.

Kohärente Handlungsfestlegungen konkretisieren die Guiding Policy, ohne in operative Detailplanung überzugehen. Sie werden durch die Guiding Policy geleitet, durch die strategische Positionierung ausgerichtet, durch Trade-offs begrenzt und durch strategische Verankerung entscheidbar, verantwortbar und umsetzbar gemacht.

Sie gehören zur Wegentscheidung, soweit sie deren Logik beweisbar machen. Detaillierte Projekte, Sprint-Objectives, OKRs und operative Aufgaben gehören zur Operationalisierung.

#### Fit / Kohärenznachweis

> [!definition]
> **Fit**[^fit] bezeichnet den Kohärenznachweis, dass Positionierung, Trade-offs und kohärente Handlungsfestlegungen zueinander passen und sich gegenseitig stützen.
>
> [^fit]: *Quellenanker*: Porter (1996) für Fit zwischen Aktivitäten; Rumelt (2011) für Kohärenz als strategische Mindestanforderung.

Fit ist mehr als Widerspruchsfreiheit. Eine Strategie besitzt Fit, wenn ihre Handlungsfestlegungen die gewählte Position stärken, die bewussten Trade-offs respektieren und sich mit anderen Aktivitäten, Policies und Ressourcenbindungen gegenseitig unterstützen.

Fit validiert damit nicht einzelne Maßnahmen isoliert, sondern das Zusammenspiel von Positionierung, Trade-offs und kohärenten Handlungsfestlegungen. Fehlt dieser Fit, entsteht keine Strategie, sondern eine lose Sammlung einzelner Maßnahmen.

### Kritische Erfolgsfaktoren

> [!definition]
> Ein **kritischer Erfolgsfaktor** (en.: *critical success factor*; meta: `CSF`)[^csf] bezeichnet einen aus der Strategie abgeleiteten Leistungs- oder Erfolgsbereich, in dem ein handlungsfähiger Akteur gut performen muss, damit die Strategie wirksam werden kann.
>
> [^csf]: *Quellenanker*: Parmenter (2020). *Autorenableitung in Anlehnung an Rumelt (2011) und Porter (1996)*: Kritische Erfolgsfaktoren werden in O2I aus der strategischen Wegentscheidung abgeleitet, insbesondere aus Guiding Policy, Positionierung, Trade-offs und Fit.

Kritische Erfolgsfaktoren gehören nicht zum Kernbegriff Strategie im Sinne von Rumelt, Porter oder Mintzberg. Sie werden aus Strategie abgeleitet und verbinden Formierung mit Kontextualisierung, Bedarfsqualifikation, Messung und Nachweislogik.

Sie markieren strategisch relevante Erfolgsbereiche, an denen sichtbar wird, welche Situationen bzw. Bedarfe für die Strategie relevant werden können. Ein kritischer Erfolgsfaktor ist damit noch kein KPI, kein Key Result und keine Maßnahme: Er beschreibt einen Erfolgsbereich, der später in konkreten Situationen kontextualisiert, über Bedarfsqualifikation handlungsrelevant gemacht und über geeignete Messungen überprüfbar wird.

In O2I begründen kritische Erfolgsfaktoren, welche Primitive-Verbindungen zwischen Strategie und Bedarf fachlich plausibel werden können. Dadurch wird eine Relation wie `Strategy --qualifies--> Need` nicht bloß behauptet, sondern über kontextualisierte Primitives motivierbar.

## Kontextualisierung

### Situation

> [!definition]
> Eine **Situation** (en.: *situation*; meta: `Situation`)[^situation] bezeichnet einen konkreten Arbeits-, Leistungs- oder Umfeldzusammenhang, in dem Bedarfe sichtbar, begründbar oder überprüfbar werden, z. B. Prozess, Capability, System, Kundenerlebnis, regulatorische Anforderung oder Schmerzpunkt. Kurz: Situation = Wo wird ein Bedarf sichtbar?
>
> [^situation]: *Autorenableitung in Anlehnung an Rumelt (2011), Porter (1996), Doerr (2018) und Parmenter (2020)*: Situation wird hier als O2I-spezifischer Brückenbegriff eingeführt, um strategische Auswahl mit konkreter Arbeitsrealität, Operationalisierung und Messbarkeit zu verbinden.

### Bedarf

> [!definition]
> Ein **Bedarf** (en.: *need*; meta: `Need`)[^need] bezeichnet eine begründete Anforderung an Veränderung, Fähigkeit oder Ergebnis, die in einer [Situation](#situation) sichtbar, begründbar oder überprüfbar wird, aber noch keine konkrete Lösung festlegt. Ein Bedarf beschreibt, was benötigt wird, nicht wie es umgesetzt oder erfüllt wird. Bedarfe können in weitere Bedarfe verfeinert werden; jede Verfeinerung bleibt auf der Ebene des Was. Kurz: Bedarf = Was wird benötigt?
>
> [^need]: *Autorenableitung in Anlehnung an Rumelt (2011), Porter (1996), Doerr (2018) und Parmenter (2020)*: Bedarf wird hier als O2I-spezifischer Brückenbegriff zwischen Formierung und Operationalisierung eingeführt. Rumelt und Porter stützen die Ableitung aus strategischer Logik; Doerr und Parmenter stützen die anschließende Operationalisierung und Messbarmachung.

Ein Bedarf entsteht nicht aus Strategie allein. Er wird in einer Situation sichtbar und ist dort fachlich verankert. Seine Wirkungsrelevanz wird durch Bedarfsqualifikation in der Operationalisierung bestimmt.

Ein Beispiel für Bedarfsspezialisierungen sind fachliche Bedarfe und daraus abgeleitete Digitalisierungsbedarfe. Beide bleiben Bedarfe: Sie beschreiben das Was, nicht die Lösung.

## Operationalisierung

Operationalisierung übersetzt eine strategische Wegentscheidung und sichtbare Bedarfe in wirkungsgerichtete Handlung. Dazu gehören die Qualifikation von Bedarfen und die Intervention, mit der ein wirkungsrelevanter Bedarf adressiert wird.

### Bedarfsqualifikation

**Bedarfsqualifikation** bezeichnet die strategische Bewertung, ob ein in einer Situation sichtbar gewordener Bedarf für eine Strategie relevant ist. Ein Bedarf wird wirkungsrelevant, wenn er in einer Situation sichtbar ist und durch eine Strategie als strategisch relevant qualifiziert wird.

Sichtbarkeit und strategische Relevanz sind unabhängige Qualitäten eines Bedarfs:

| in Situation sichtbar | strategisch relevant | Begriff |
|---|---:|---|
| nein | nein | latenter Bedarf |
| ja | nein | sichtbar gewordener Bedarf |
| nein | ja | strategisch relevanter Bedarf |
| ja | ja | wirkungsrelevanter Bedarf |

Je stärker eine Situation bereits an einer Strategie ausgerichtet ist, desto einfacher ist die strategische Qualifizierung sichtbar gewordener Bedarfe. Die Ausrichtung der Situation ersetzt die Qualifizierung jedoch nicht: Auch eine strategienahe Situation kann Bedarfe sichtbar machen, die nicht strategisch relevant sind.

Ein wirkungsrelevanter Bedarf ist handlungsrelevant, weil seine Bearbeitung plausibel zur angestrebten Wirkung beitragen kann.

### Intervention

> [!definition]
> Eine **Intervention** (en.: *intervention*; meta: `Intervention`)[^intervention] bezeichnet eine gezielte Einwirkung auf eine [Situation](#situation), mit der ein wirkungsrelevanter Bedarf adressiert und eine strategisch relevante Veränderung erzeugt werden soll. Eine Intervention kann als Projekt, Maßnahme, Experiment, Programm, Initiative oder andere Umsetzungseinheit auftreten. Kurz: Intervention = Womit verändern wir die Situation?
>
> [^intervention]: *Autorenableitung in Anlehnung an Rumelt (2011), Porter (1996) und Doerr (2018)*: Interventionen gehören zur Operationalisierung einer strategischen Wegentscheidung. Sie übersetzen strategische Handlungslogik in konkrete Eingriffe, bleiben aber Wirkungshypothesen und keine Garantie für Zielerreichung.

## Wirkung

Wirkung wird in O2I nicht behauptet, sondern über Messung nachvollziehbar gemacht.

> [!definition]
> **Wirkung**[^effect] bezeichnet eine beobachtbare, zur [Vision](#vision) beitragende Veränderung, die aus der Operationalisierung einer strategischen Wegentscheidung entsteht und an relevanten Ergebnis- und Leistungsmaßen nachvollzogen werden kann.
>
> [^effect]: *Autorenableitung in Anlehnung an Porter (1996), Doerr (2018), Parmenter (2020) und Barr (2014)*: Wirkung wird hier als Ergebnis der Operationalisierung einer strategischen Wegentscheidung verstanden. Porter liefert die Logik des Wertbeitrags durch Aktivitätssysteme; Doerr, Parmenter und Barr liefern Instrumente zur Überprüfung von Fortschritt und Performance.

### Messung

> [!definition]
> Eine **Messung** (en.: *measure*; meta: `Measure`)[^measure] bezeichnet eine stabile Messdefinition, mit der ein relevanter Zustand, eine Leistung oder eine Entwicklung in einer [Situation](#situation) beobachtet wird. Eine Messung kann Zielwerte tragen, wenn eine Intervention festlegt, welche Veränderung erreicht werden soll. Kurz: Messung = Womit machen wir relevante Zustände beobachtbar?
>
> [^measure]: *Quellenanker*: Parmenter (2020) für KPIs und die Abgrenzung zu anderen Performance-Maßen; Barr (2014) für methodische Entwicklung aussagefähiger Performance-Maße. *Autorenableitung in Anlehnung an Doerr (2018) und Parmenter (2020)*: Ein KPI ist eine entscheidungsrelevante Spezialisierung eines Measure. Ein Key Result kann einen konkreten Zielwert für ein Measure in einem Umsetzungszeitraum setzen.

### Nachweislogik

**Nachweislogik** bezeichnet die fachliche Begründung, wie Messungen als plausible Evidenz für Wirkung gelesen werden. Sie verbindet Interventionen, relevante Messungen, Zielwerte, beobachtete Veränderungen und Lernschleifen, ohne daraus einen automatischen Kausalbeweis abzuleiten.

# Metamodell

Das O2I-Metamodell trennt Semantik und Syntax. Die Semantik definiert die O2I-Begriffslogik aus O2I-Primitives, O2I-Kontexten, O2I-Relationen und Wohlgeformtheitsregeln; die Syntax beschreibt, wie diese Begriffslogik in einer Modellierungssprache dargestellt wird.

## Semantik

Die O2I-Semantik übersetzt die Terminologie in eine modellierbare Struktur: Sie legt fest, welche O2I-Primitives das Modell verwendet, welche O2I-Kontexte diesen Primitives fachliche Bedeutung geben, welche Relationen zwischen ihnen zulässig sind und nach welchen Regeln Modelle wohlgeformt sind.

> tl;dr. **Terminologie** definiert, *was die Begriffe fachlich-verbal bedeuten*; **Semantik** konkretisiert diese Bedeutung als *O2I-Primitives, O2I-Kontexte, O2I-Relationen und Wohlgeformtheitsregeln*; **Syntax** definiert, *wie diese Semantik in einer Modellierungssprache dargestellt wird*.

Die O2I-Semantik besteht aus vier Perspektiven: O2I-Kontexte und ihre Relationen bilden die grundlegenden Interpretationsrahmen und Makrorelationen von Wirkungsarchitekturen. O2I-Primitives und ihre Relationen bilden den minimalen abstrakten Formvorrat[^formvorrat]. Wohlgeformtheitsregeln legen fest, welche Strukturen als gültige O2I-Modelle gelten. O2I-Interpretationen beschreiben, welche fachliche Bedeutung ein O2I-Primitive in einem bestimmten O2I-Kontext erhält.

[^formvorrat]: Formvorrat bezeichnet hier die Menge abstrakter Modellformen, mit denen fachliche Inhalte in unterschiedlichen O2I-Kontexten ausgedrückt werden können.

Die in @sec:terminologie eingeführten Domänen Orientierung, Formierung, Kontextualisierung, Operationalisierung und Wirkung bilden die fachliche Ordnung, aus der die O2I-Kontexte hervorgehen.

### Kontexte

#### Elemente

O2I formalisiert die in @sec:terminologie eingeführten fachlichen Standardbegriffe als *O2I-Kontexte*. Ein O2I-Kontext ist ein fachlicher Interpretationsrahmen, in dem O2I-Primitives kontextspezifische Bedeutung erhalten.

Das Kontext-Inventar legt fest, welche O2I-Kontexte das Metamodell verwendet. Die folgenden Codeblöcke sind Auszüge aus der normativen Haskell-Spezifikation `spc/O2I.hs`.

```haskell
!include`snippetStart="-- * Contexts", snippetEnd="-- * Primitives"` spc/O2I.hs
```

Die Kontextarten sind fachlich so zu lesen: `Ethos` bezeichnet den kulturell-normativen Orientierungsrahmen eines Akteurs; darin können einzelne `Principle` liegen. `Mission` bezeichnet den grundlegenden Existenzzweck; ein `Driver` wird darin als grundlegender Existenzzweck, Antrieb oder Beitragsgrund gelesen. `Vision` bezeichnet einen orientierenden Zukunftszustand. `Strategy` bezeichnet die Wegentscheidung unter gegebenen Bedingungen. `Need` bezeichnet einen begründeten Änderungs- oder Handlungsbedarf. `Intervention` bezeichnet eine wirkungsgerichtete Handlung oder Eingriffslogik. `Measure` bezeichnet einen Messrahmen, in dem relevante Zustände beobachtbar werden. `Situation` bezeichnet einen konkreten Arbeits-, Leistungs- oder Umfeldzusammenhang; sie ist vom metasprachlichen Ausdruck "O2I-Kontext" zu unterscheiden.

@Fig:o2i-context-view zeigt das Kontextmodell des O2I-Metamodells: O2I-Kontexte und ihre Relationen.

![O2I Context View](<img/O2I Context.png>){#fig:o2i-context-view width=85%}

Die Darstellung ist als semantische Verdichtung der Terminologie zu lesen: Sie zeigt die fachlichen Standardbegriffe als O2I-Kontexte und macht sichtbar, welche Relationen zwischen diesen Kontexten zulässig sind. Sie ersetzt die terminologischen Definitionen nicht, sondern fasst ihre teleologische Wirkungslogik auf Metamodellebene zusammen.

#### Relationen

Die grafische Sicht dient der Orientierung; die folgenden Kontextrelationen legen explizit fest, welche Relationen zwischen O2I-Kontexten zulässig sind. Sie machen die Darstellung eindeutig, referenzierbar und als Grundlage für Wohlgeformtheitsregeln verwendbar. O2I verwendet dafür eine typisierte Spezifikationssyntax: `RelName :: ContextRelation From To`.

```haskell
!include`snippetStart="-- * Context relations", snippetEnd="-- * Primitive nodes"` spc/O2I.hs
```


Die O2I-Kontextrelationen bilden eine schlanke teleologische Wirkungslogik, d. h. die Relationen drücken Zweck-, Mittel-, Qualifikations- und Nachweiszusammenhänge aus.

> [!tl;dr] Teleologische O2I-Wirkungslogik
> Leitprinzipien leiten Mission und Vision; Mission, verstanden als Existenzzweck, begründet, warum eine Vision angestrebt wird; Vision gibt der Strategie Richtung; Situationen machen Bedarfe unterschiedlicher Art sichtbar; Strategie qualifiziert strategisch relevante Bedarfe. Wirkungsrelevante Bedarfe entstehen dort, wo ein Bedarf in einer Situation sichtbar wird und durch Strategie als strategisch relevant qualifiziert ist. Bedarfe können verfeinert werden und Beiträge zu Strategien nachvollziehbar machen; Interventionen sind in O2I nur für wirkungsrelevante Bedarfe vorgesehen, verändern Situationen und legen Zielwerte für Messungen fest; Messungen machen relevante Zustände in Situationen beobachtbar.

Einige O2I-Kontextrelationen verdienen eine präzisierende Lesart, weil sie leicht missverstanden werden können:

`Intervention --addresses--> Need`: Die Relation setzt einen wirkungsrelevanten Bedarf voraus; ein nur sichtbarer oder nur strategisch relevanter Bedarf reicht nicht.

`Need --requires--> Intervention`: Die Relation setzt einen wirkungsrelevanten Bedarf voraus. Erst ein Bedarf, der in einer Situation sichtbar und durch Strategie als strategisch relevant qualifiziert ist, kann eine Intervention erforderlich machen; er legt aber noch keine Lösung fest.

`Measure --measures--> Situation`: Der unmittelbare Messgegenstand ist die Situation. Ein Measure macht einen relevanten Zustand, eine Leistung oder eine Entwicklung in dieser Situation messbar.

`Intervention --sets-target-for--> Measure`: Die Relation bedeutet nicht, dass eine Intervention selbst misst oder mit einem Key Result identisch ist. Sie bedeutet: Eine Intervention enthält oder erzeugt eine Zielsetzung, die auf einem Measure ausgedrückt wird.

`Strategy --frames--> Measure`: Die Relation steht dafür, dass Measures über strategisch relevante Erfolgsfaktoren mit Strategie verbunden werden. Sie bedeutet nicht, dass Measures direkt aus Strategie entstehen.

### Primitives

#### Elemente

O2I-Primitives sind die abstrakten formalen Träger, die in O2I-Kontexten interpretiert werden und dort fachliche Bedeutung erhalten. Sie bilden den minimalen abstrakten Formvorrat des O2I-Metamodells. Ein O2I-Primitive hat keine vollständige fachliche O2I-Bedeutung für sich allein; seine fachliche Lesart entsteht erst durch Interpretation in einem O2I-Kontext (siehe @Sec:interpretationen).

@Fig:o2i-primitives-view zeigt das Primitives-Modell des O2I-Metamodells: O2I-Primitives, mögliche Strukturierungsrahmen und ihre Relationen.

![O2I Primitives View](<img/O2I Primitives.png>){#fig:o2i-primitives-view width=75%}

Die Darstellung ist als semantische Übersicht des abstrakten Formvorrats zu lesen: Sie zeigt O2I-Primitives, mögliche Strukturierungsrahmen und zulässige Relationen zwischen ihnen, unabhängig von ihrer syntaktischen Abbildung. Die grafische Darstellung dient der Orientierung.

Das Primitive-Inventar legt fest, welche O2I-Primitives das Metamodell verwendet.

```haskell
!include`snippetStart="-- * Primitives", snippetEnd="-- * Structuring"` spc/O2I.hs
```


Eine `KPI-Domäne` ist ein optionaler Strukturtyp im Modell der O2I-Primitives, aber kein O2I-Primitive. Sie bezeichnet einen Messbereich, in dem relevante Zustände beobachtet werden können, bevor konkrete KPIs festgelegt werden.

#### Relationen

Die Primitive-Relationen legen explizit fest, welche Relationen zwischen O2I-Primitives zulässig sind. `KPIDomain` ist dabei als Strukturierungsart zulässig, aber kein O2I-Primitive.

```haskell
!include`snippetStart="-- * Structuring", snippetEnd="-- * Typed instances"` spc/O2I.hs
```

```haskell
!include`snippetStart="-- * Primitive nodes", snippetEnd="-- * Primitive relations"` spc/O2I.hs
```

```haskell
!include`snippetStart="-- * Primitive relations", snippetEnd="-- * Well-formedness invariants"` spc/O2I.hs
```


Die Primitive-Relationen bilden keine zweite Wirkungslogik neben den Kontextrelationen. Sie beschreiben die abstrakte Formlogik, die in O2I-Kontexten interpretiert wird: Prinzipien leiten Treiber und Objectives; Treiber motivieren Objectives und bestimmen relevante Messbereiche; Key Results substantiieren Objectives, können in nachgelagerte Objectives übersetzt werden und setzen Zielwerte für KPIs; KPIs können verfeinert werden; Actions tragen zu Key Results bei und adressieren Gaps.

Einige Primitive-Relationen verdienen eine präzisierende Lesart, weil sie leicht missverstanden werden können:

`Driver --determines--> KPI-Domäne`: Ein Driver bestimmt noch keinen konkreten KPI. Er grenzt einen Messbereich ein, in dem relevante Zustände beobachtet werden können. Die Auswahl konkreter KPIs bleibt ein bewusster Freiheitsgrad der Modellierung.

`Key Result --substantiates--> Objective`: Ein Key Result substantiiert ein Objective durch quantitative Evidenz. Es ersetzt das qualitative Objective nicht und ist selbst keine Messdefinition.

`Key Result --translates-into--> Objective`: Diese Relation beschreibt vertikale Operationalisierung. Ein Key Result einer höheren Ebene kann in ein qualitatives Objective einer nachgelagerten Ebene übersetzt werden.

`Key Result --sets-target-for--> KPI`: Ein Key Result ist nicht selbst die Messdefinition. Es legt einen Zielwert auf einem KPI fest.

`KPI --refines--> KPI`: Ein KPI kann in spezifischere KPIs verfeinert werden, ohne dass dadurch ein neuer O2I-Primitive entsteht.

`Action --contributes-to--> Key Result`: Eine Action ist eine Handlungshypothese. Sie kann zu einem Key Result beitragen, garantiert dessen Erreichung aber nicht.

`Action --addresses--> Gap`: Eine Action adressiert eine sichtbare Abweichung, schließt sie aber nicht automatisch.

### Wohlgeformtheitsregeln

Wohlgeformtheitsregeln wiederholen nicht die zulässigen Relationstypen. Sie formulieren Invarianten über typisierte Modellinstanzen. `Ethos`, `Mission` usw. bezeichnen dabei Kontextarten; `Ctx Mission` bezeichnet eine konkrete Mission-Instanz mit Inhalt. Deshalb hat eine Mission-Regel die Form `wfMission :: Ctx Mission -> Bool`, nicht `Mission -> Bool`.

```haskell
!include`snippetStart="-- * Typed instances", snippetEnd="-- * Context relations"` spc/O2I.hs
```

```haskell
!include`snippetStart="-- * Well-formedness invariants", snippetEnd="-- * Well-formedness support"` spc/O2I.hs
```


Aus diesen Invarianten ergeben sich zusätzliche Modellierungsregeln:

- Ein `Objective` setzt keinen Zielwert für einen `KPI`; Zielwerte werden durch `Key Result` gesetzt.
- Ein `KPI` ist eine stabile Messdefinition, nicht der beobachtete Messwert.
- Ein `Key Result` kann in ein nachgelagertes `Objective` übersetzt werden; direkte Key-Result-zu-Key-Result-Abhängigkeiten werden nicht verwendet.
- Eine `Action` ist eine Handlungshypothese. Sie kann zu einem `Key Result` beitragen, garantiert ihn aber nicht.
- Ein `Gap` wird durch die Abweichung zwischen Key-Result-Zielwert und KPI-Istwert sichtbar.

Die Strategie-Relationen zwischen `Strategy` und `Strategy` sind Ausrichtungsrelationen zwischen Strategien unterschiedlicher Ebenen, z. B. Konzernstrategie, Ressortstrategie, Geschäftsstrategie und Funktionsstrategie. `directs` bedeutet, dass eine übergeordnete Strategie Richtung, Prioritäten, Leitplanken, Restriktionen oder Zielbezüge für eine untergeordnete Strategie vorgibt, ohne diese vollständig zu determinieren. Der messbare Beitrag wird präziser über Bedarfe, Interventionen, Measures und Kontextveränderungen beschrieben. Die Strategie-Relation ist eine verdichtete Kurzrelation, keine Kompositionsrelation.

### Interpretationen {#sec:interpretationen}

O2I-Interpretationen beschreiben, welche fachliche Bedeutung ein O2I-Primitive in einem bestimmten O2I-Kontext erhält. Sie verbinden damit den abstrakten Formvorrat der O2I-Primitives mit den fachlichen Interpretationsrahmen der O2I-Kontexte.

#### Mission

Im Kontext `Mission` sind `Driver` zulässig:

`Driver` $\in$ `Mission`

Ein `Driver` im Kontext `Mission` beschreibt einen grundlegenden Antrieb, Existenzzweck oder Beitragsgrund. Er beantwortet die Frage, warum ein handlungsfähiger Akteur existiert oder welchen grundlegenden Beitrag er leisten soll. Mehrere `Driver` können eine Mission analytisch konkretisieren, gruppieren oder ergänzen; sie ersetzen die terminologische Definition der Mission nicht.

#### Vision

Im Kontext `Vision` sind `Objective` zulässig:

`Objective` $\in$ `Vision`

Ein `Objective` im Kontext `Vision` beschreibt ein qualitatives Zukunftsbild oder eine qualitative Ausrichtung. Es beantwortet die Frage, wohin ein handlungsfähiger Akteur wirken will, ohne bereits festzulegen, wie diese Wirkung erreicht wird. Qualitative Ausrichtungen können zu einem übergeordneten Zukunftsbild beitragen; sie sind Objectives im Kontext `Vision`, keine zusätzlichen O2I-Primitives.

#### Objective

Ein `Objective` im Kontext `Objective` ist ein qualitatives Umsetzungsziel.

#### Strategy

Eine `Action` im Kontext `Strategy` ist eine Wegentscheidung.

#### Intervention

Eine `Action` im Kontext `Intervention` ist eine gezielte Einwirkung.

#### Need

Im Kontext `Need` sind `Driver` zulässig:

`Driver` $\in$ `Need`

Ein `Driver` im Kontext `Need` beschreibt einen begründenden, spannungserzeugenden oder bedarfsanzeigenden Faktor. Er macht nachvollziehbar, warum eine Veränderung, Fähigkeit oder ein Ergebnis benötigt wird, ohne bereits eine Lösung festzulegen.

#### Measure

Im Kontext `Measure` sind `KPI` zulässig:

`KPI` $\in$ `Measure`

Ein `KPI` im Kontext `Measure` beschreibt eine stabile Messdefinition, mit der ein relevanter Zustand, eine Leistung oder eine Entwicklung in einer Situation beobachtbar wird. Ein KPI ist nicht der beobachtete Messwert selbst.

#### Situation

Der Kontext `Situation` wird durch konkrete Arbeits-, Leistungs- oder Umfeldzusammenhänge instanziiert. Eine Situation kann z. B. durch Capabilities, Prozesse, Systeme, Kundenerlebnisse, regulatorische Anforderungen oder fachliche Schmerzpunkte beschrieben werden. Sie bildet den fachlichen Ort, an dem Bedarfe sichtbar, begründbar oder überprüfbar werden.

## Syntax

Die ArchiMate-Profilierung bildet die Syntax-Komponente des O2I-Metamodells. O2I definiert die fachliche Semantik; ArchiMate stellt die visuelle Syntax zur Darstellung und Integration von O2I-Modellen mit Enterprise-Architecture-Artefakten bereit.

O2I kann mit ArchiMate modelliert werden, ohne die O2I-Semantik durch ArchiMate-Semantik zu ersetzen. ArchiMate dient dabei als gemeinsame Modellierungssprache; O2I legt fest, welche fachliche Bedeutung die verwendeten Elemente als O2I-Primitives in einem O2I-Kontext besitzen.

Dadurch können O2I-Modelle mit TOGAF-basierten Architekturmodellen und -sichten (z.B. Business-Capability-Maps, Application Views, Prozessmodellen oder Technologielandschaften) in einer gemeinsamen Modellierungssprache verbunden werden. ArchiMate wird damit nicht nur für Enterprise-Architecture-Strukturen verwendet, sondern auch für die explizite Modellierung von Orientierung und Wirksamkeit. Das Ergebnis ist ein kohärenter Wissensgraph, in dem normative Orientierung, strategische Wegentscheidungen, Interventionen und Architekturartefakte anschlussfähig bleiben.

### ArchiMate-Profil

Die Syntax verwendet ArchiMate als visuelle Notation. O2I-Primitives werden in ArchiMate durch wenige ArchiMate-Basisformen dargestellt. Mission, Vision, Strategy, Need und weitere O2I-Kontexte werden in ArchiMate als strukturierte Modellbereiche aufgeklappt: Ein Mission-Kontext wird durch ArchiMate `Driver` modelliert; ein Vision-Kontext durch ArchiMate `Goal`; ein Measure-Kontext durch ArchiMate `Assessment`.

O2I-Kontexte werden in der ArchiMate-Syntax nicht zwingend als einzelne ArchiMate-Elemente dargestellt. Ein Kontext wie `Mission` oder `Vision` kann durch einen Gruppierungsrahmen, ein Teilmodell oder mehrere ArchiMate-Elemente mit Relationen ausgearbeitet werden.

### Primitives-Abbildung

Die folgende Zuordnung zeigt, wie O2I-Primitives durch ArchiMate-Basisformen dargestellt werden und welche Grundlesart sie im O2I-Metamodell tragen:

```text
O2I-Primitive Principle -> ArchiMate Principle -> normative Orientierung
O2I-Primitive Driver -> ArchiMate Driver -> begründender, spannungserzeugender oder bedarfsanzeigender Faktor
O2I-Primitive Objective -> ArchiMate Goal -> qualitatives Ziel
O2I-Primitive Key Result -> ArchiMate Outcome -> quantitative Evidenzgröße oder Zielwert
O2I-Primitive KPI -> ArchiMate Assessment -> stabile Messdefinition
O2I-Primitive Action -> ArchiMate Course of Action -> Wegentscheidung, Handlungslogik oder Intervention
O2I-Primitive Gap -> ArchiMate Gap -> Differenz zwischen Ist- und Sollzustand
```

Ein ArchiMate `Goal` stellt in O2I das O2I-Primitive `Objective` dar. Im Kontext einer Vision ist es als qualitativer Orientierungszustand oder qualitative Ausrichtung zu verstehen. Im Kontext der Operationalisierung ist es als Objective im OKR-Sinn zu verstehen. Ein ArchiMate `Outcome` stellt in O2I das O2I-Primitive `Key Result` dar. Ein ArchiMate `Assessment` stellt in O2I das O2I-Primitive `KPI` dar.

Ein ArchiMate `Work Package` kann eine konkrete Umsetzungseinheit darstellen, die eine Action realisiert. Es gehört jedoch nicht zum minimalen O2I-Primitive-Vorrat, weil die Semantik der Handlungshypothese bereits durch `Action` getragen wird.

Ein ArchiMate `Driver` bezeichnet in O2I grundsätzlich einen begründenden, spannungserzeugenden oder bedarfsanzeigenden Faktor. Im Kontext einer Mission beschreibt ein `Driver` einen Treiber des grundlegenden Existenzzwecks. Im Kontext eines Need beschreibt ein `Driver` einen begründeten Änderungs- oder Handlungsbedarf.

Ein O2I-Kontext wird über Kontext- oder Gruppierungsrahmen und konsistente Modellkonventionen gekennzeichnet, z. B. `Mission : O2I Ctx` oder `Vision : O2I Ctx`. Die Elementsemantik ergibt sich aus dem O2I-Primitive und dem jeweiligen O2I-Kontext.

Der O2I-Kontext `Situation` ist kein isolierter ArchiMate-Motivationstyp. Ein operativer Kontext wird in ArchiMate durch konkrete Architekturartefakte modelliert, z. B. Business Capability, Business Process oder regulatorische Anforderungen. O2I `Situation` ist damit ein fachlicher Interpretationskontext, der durch passende ArchiMate-Elemente instanziiert wird.

### Relationsabbildung

O2I-Relationen sind fachliche Makrorelationen zwischen O2I-Kontexten bzw. zwischen kontextualisierten O2I-Primitives. In ArchiMate werden sie durch zulässige ArchiMate-Relationen zwischen konkreten Elementen dargestellt. Die Relation wird mit dem O2I-Relationsnamen beschriftet, wenn dadurch die fachliche Bedeutung präziser wird.

Eine O2I-Relation zwischen O2I-Kontexten muss in der ArchiMate-Syntax nicht als einzelne Kante zwischen zwei Elementen erscheinen. Sie kann durch mehrere Relationen zwischen enthaltenen ArchiMate-Elementen realisiert oder als abgeleitete Makrorelation dokumentiert werden.

```text
Principle --influence[guides]--> Driver im Kontext Mission
Principle --influence[guides]--> Goal im Kontext Vision
Driver im Kontext Mission --influence[motivates]--> Goal im Kontext Vision
Goal im Kontext Vision --influence[orients]--> Course of Action im Kontext Strategy
Driver im Kontext Need --influence[motivates]--> Goal im Kontext Objective
Outcome im Kontext Key Result --influence[translates-into]--> Goal im Kontext Objective
Outcome im Kontext Key Result --realization[substantiates]--> Goal im Kontext Objective
Outcome im Kontext Key Result --association[sets-target-for]--> Assessment im Kontext Measure
Assessment im Kontext Measure --association[measures]--> Situation
Course of Action im Kontext Intervention --influence[addresses]--> Driver im Kontext Need
Course of Action im Kontext Intervention --influence[changes]--> Situation
```

Die O2I-Relation `Vision --orients--> Strategy` kann in ArchiMate als `Influence`-Relation von einem `Goal` im Kontext `Vision` zu einem `Course of Action` im Kontext `Strategy` abgebildet werden. Fachlich bedeutet sie: Die Vision gibt der Strategie Richtung; die Strategie bleibt die Wegentscheidung, die diese Richtung unter gegebenen Bedingungen verfolgt.

### Abgeleitete Relationen

Eine O2I-Relation darf abgeleitet sein. Sie fasst dann mehrere ArchiMate-Elemente und -Relationen zu einer fachlichen Makrorelation zusammen.

Beispiel:

```text
O2I: Ethos --guides--> Mission
```

wird syntaktisch modelliert als:

```text
O2I-Kontext Ethos contains Principle
O2I-Kontext Mission contains Driver
Principle --influence[guides]--> Driver
```

Die äußeren O2I-Kästen sind damit O2I-Kontexte; die fachlich wirksame Relation liegt zwischen den enthaltenen ArchiMate-Elementen.

### Modellierungsregeln

- ArchiMate ist Syntax; O2I ist Semantik.
- O2I-Begriffe wie Mission, Vision oder Strategy werden als O2I-Kontexte beziehungsweise strukturierte Teilmodelle über O2I-Primitives modelliert.
- Ein ArchiMate `Goal` stellt in O2I ein `Objective` dar; ein ArchiMate `Outcome` stellt ein `Key Result` dar; ein ArchiMate `Assessment` stellt einen `KPI` dar.
- O2I-Makrorelationen dürfen aus mehreren ArchiMate-Relationen abgeleitet werden.
- Aggregations- oder Kompositionskanten zwischen O2I-Kontexten ersetzen keine fachliche Relation zwischen den enthaltenen Elementen.
- Gleichartige Elemente dürfen komponiert oder aggregiert werden, wenn dadurch eine fachliche Zerlegung ausgedrückt wird.
- `Situation` wird nicht auf ein einzelnes ArchiMate-Element reduziert, sondern durch konkrete Architekturartefakte instanziiert.
- Wenn eine O2I-Relation nicht mit einer zulässigen ArchiMate-Relation ausdrückbar ist, muss sie als abgeleitete Relation dokumentiert werden.
