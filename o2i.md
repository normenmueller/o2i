---
title: "Von Orientierung zur Wirkung\\thanks{Publiziert unter \\url{https://github.com/normenmueller/o2i}}"
subtitle: "Begriffe und Relationen für wirksames Handeln"
author: nemron
version: "0.2"
status: "wip"
abstract: |
  Wie werden Orientierung, Formierung, Situierung und Operationalisierung so verbunden, dass nachvollziehbare Wirkung entsteht?
lang: de-DE
figureTitle: "Abb."
figPrefix:
  - "Abb."
  - "Abb."
listingTitle: "Listing"
lstPrefix:
  - "Lst."
  - "Lst."
secPrefix:
  - "Kap."
  - "Kap."
toc: yes
toc-depth: 3
callout-theme: gray
papersize: a4
geometry:
  - left=4.4cm
  - right=4.4cm
  - top=4.8cm
  - bottom=3.9cm
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

\begin{center}
\begin{minipage}{0.72\textwidth}
\textbf{\textsc{Vorbemerkung}.} \textit{Dieser Artikel ist bewusst knapp gehalten. Er ist kein Lehrbuch und keine breite Literaturabhandlung, sondern ein wissenschaftlich fundiertes Begriffs- und Modellierungsdokument mit klaren Definitionen, Quellenankern und expliziten Autorenableitungen.}
\end{minipage}
\end{center}
\newpage

# Einleitung

O2I steht für *Orientation to Impact*.

!include`snippetStart="<!-- O2I PURPOSE START -->", snippetEnd="<!-- O2I PURPOSE END -->"` README.md

Die zentrale Idee von O2I ist, fachliche Relationen wie die O2I-Relation `Strategy --qualifies--> Need` nicht nur zu behaupten, sondern im O2I-Wirkungsgraphen zu begründen. O2I-Kontexte geben Bedeutung; O2I-Primitives tragen die modellierten Inhalte; Relationen zwischen kontextualisierten Primitives machen die fachliche Begründung nachvollziehbar.

> [!tldr] O2I Wirkungslogik
> O2I lässt sich einführend als Folge fachlicher Übergänge lesen:
>
> - **Orientierung**: normativer und intentionaler Ausgangspunkt
> - **Formierung**: strategische Wegentscheidung
> - **Situierung**: Bedarf wird in einer Situation sichtbar
> - **Operationalisierung**: Sichtbarer Bedarf wird qualifiziert, handlungs- und nachweisfähig
> - **Wirkung**: beobachtete Veränderung und Evidenz

Die Wirkungskette ist nicht linear abgeschlossen: Beobachtete Wirkung liefert Evidenz, um Situationen neu zu bewerten und weitere Bedarfe sichtbar zu machen.

Der Artikel entfaltet O2I als Framework, indem er die fachliche Begriffswelt auf Basis der Standardliteratur terminologisch begründet, semantisch und syntaktisch im Metamodell formalisiert und ihre Anwendung anhand eines zusammenhängenden O2I-Wirkungsgraphen illustriert.

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

Collins und Porras (1996), Schein (2010) sowie Bourne, Jenkins und Parry (2019) stützen Orientierung als normativen und kulturell verankerten Ausgangspunkt. George, Haas, McGahan, Schillebeeckx und Tracey (2023) sowie Chua, Miska, Mair und Stahl (2024) ergänzen den aktuellen Purpose-Diskurs und schärfen Mission als Existenzzweck.

Rumelt (2011), Porter (1996), Hamel und Prahalad (1989) sowie Mintzberg und Waters (1985) stützen die strategische Formierung: Diagnose, strategische Absicht, leitende Handlungslogik, Positionierung, Trade-offs, Fit, Kohärenz sowie intendierte und realisierte Strategie. Parmenter (2020) stützt darin kritische Erfolgsfaktoren als abgeleitete strategische Erfolgsbereiche.

TOGAF und ArchiMate stützen Situierung, indem sie fachliche Business-Architecture-Artefakte bereitstellen, an denen Bedarfe sichtbar und verortbar werden.

Rumelt (2011) und Porter (1996) stützen die Bedarfsqualifikation innerhalb der Operationalisierung, indem sie strategische Relevanz aus Herausforderung, Positionierung, Trade-offs und Aktivitätssystem begründbar machen. Doerr (2018) stützt Operationalisierung über Objectives und Key Results als überprüfbare Umsetzungs- und Evidenzformen.

Parmenter (2020) stützt Performance-Logik und KPI-Disziplin. Barr (2014) ergänzt die methodische KPI-Entwicklung über eine praktische Performance-Measurement-Methodik. Doerr (2018) ergänzt Wirkung und Messung durch Ziel- und Ergebnisbezüge.

The Open Group (2025, 2026) stützt die Modellierungsebene: TOGAF liefert den Enterprise-Architecture-Bezug, ArchiMate liefert die standardisierte Modellierungssprache, mit der O2I-Modelle an Architekturartefakte anschlussfähig werden.

Die Literaturquellen begründen damit unterschiedliche Funktionen innerhalb von O2I: Orientierung wird formiert, Formierung wird situiert und operationalisiert, und Wirkung wird über Messung, Nachweislogik und Modellierbarkeit nachvollziehbar gemacht.

## Definitionsregel

Eine Definition wird nicht bloß behauptet. Sie wird nur verwendet, wenn sie entweder direkt durch eine Quelle gestützt oder als Autorenableitung aus den verwendeten Quellen nachvollziehbar gemacht wird. Jede Definition und jede tragende Argumentationskette erhält deshalb einen Quellenanker oder eine explizite Kennzeichnung als Autorenableitung.

*Direkter Quellenanker:* Der Begriff oder die Argumentationslogik wird unmittelbar aus einer Quelle übernommen oder eng paraphrasiert.

*Autorenableitung in Anlehnung an ...:* Der Artikel bildet eine eigene Systematisierung, die auf mindestens einer Quelle beruht, aber über deren Wortlaut oder Begriffssystem hinausgeht.

# Terminologie

Die Terminologie beschreibt eine *teleologische Wirkungslogik*: von Orientierung über Formierung, Situierung und Operationalisierung zu Wirkung. Diese fünf *fachlichen Domänen* ordnen die Standardbegriffe, welche O2I anschließend als O2I-Kontexte formalisiert.

## Orientierung

> [!definition]
> **Orientierung**[^orientation-domain] bezeichnet in O2I die fachliche Domäne, in der ein handlungsfähiger Akteur seinen normativen Rahmen, seinen grundlegenden Existenzzweck und seinen angestrebten Zukunftszustand bestimmt.
>
> [^orientation-domain]: *Autorenableitung in Anlehnung an Collins und Porras (1996), Schein (2010), Bourne, Jenkins und Parry (2019), George et al. (2023) sowie Chua, Miska, Mair und Stahl (2024)*: O2I fasst kulturell-normative Orientierung, Existenzzweck und Zukunftsbild als zusammenhängende fachliche Domäne.

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
> > [!tldr] Ethos = \textsc{Wofür} stehen wir?
>
> [^ethos]: *Autorenableitung in Anlehnung an Collins und Porras (1996), Schein (2010), Bourne, Jenkins und Parry (2019), Rumelt (2011) und Porter (1996)*: Ethos wird hier als kulturell-normativer Orientierungsrahmen verstanden.
>
> [^principles]: *Autorenableitung in Anlehnung an Collins und Porras (1996), Schein (2010), Bourne, Jenkins und Parry (2019), Rumelt (2011) und Porter (1996)*: Leitprinzipien werden hier als normative Grundsätze verstanden, die Handlungsoptionen begrenzen, Prioritäten prägen und Entscheidungen konsistent machen.

Ethos begrenzt, welche Arten von Zielen, Strategien und Handlungen für einen Akteur überhaupt legitim sind. Es ist damit kein Zielbild und keine Strategie, sondern der normative Maßstab, an dem spätere Wegentscheidungen konsistent ausgerichtet werden.

### Mission

> [!definition]
> Eine **Mission** (en.: *mission*; meta: `Mission`)[^mission] bezeichnet den durch das `Ethos` eines handlungsfähigen Akteurs geprägten *grundlegenden Existenzzweck*: warum der Akteur existiert und welchen Beitrag er leisten soll.
>
> > [!tldr] Mission = \textsc{Warum} gibt es uns?
>
> [^mission]: *Autorenableitung in Anlehnung an Chua, Miska, Mair und Stahl (2024), George et al. (2023), Collins und Porras (1996), Schein (2010) und Rumelt (2011)*: Mission wird hier als grundlegender Existenzzweck eines handlungsfähigen Akteurs verstanden. Die Purpose-Literatur stützt den Beitrags- und Existenzzweck; Collins, Porras und Schein stützen die normative Einbettung; Rumelt stützt die Abgrenzung von Mission gegenüber Strategie.

Mission begründet, warum ein Akteur überhaupt wirken soll. Sie beschreibt den dauerhaften Beitragsgrund, aber noch keinen angestrebten Zukunftszustand und keine Wegentscheidung.

### Vision

> [!definition]
> Eine **Vision** (en.: *vision*; meta: `Vision`)[^vision] bezeichnet einen vom `Ethos` geprägten und durch die [Mission](#mission) begründeten, von einem handlungsfähigen Akteur *angestrebten, orientierenden Zukunftszustand*: wohin der Akteur wirken will, ohne bereits festzulegen, wie diese Wirkung erreicht wird.
>
> > [!tldr] Vision = \textsc{Wohin} wollen wir wirken?
>
> [^vision]: *Autorenableitung in Anlehnung an Collins und Porras (1996), Hamel und Prahalad (1989), Rumelt (2011) und Porter (1996)*: Collins und Porras stützen Vision als orientierendes Zukunftsbild; Hamel und Prahalad stützen langfristige strategische Ausrichtung; Rumelt und Porter stützen die Abgrenzung von Vision gegenüber Strategie, weil Vision noch keine kohärente Wegentscheidung, Positionierung, Trade-offs oder Fit liefert.

Vision gibt Richtung, ohne den Weg festzulegen. Sie macht die angestrebte Wirkung qualitativ verständlich und bildet damit den Bezugspunkt, an dem Strategie später begründen muss, wie dieser Zukunftszustand unter gegebenen Bedingungen erreichbar werden soll.

## Formierung

> [!definition]
> **Formierung**[^formation-domain] bezeichnet in O2I die fachliche Domäne, in der Orientierung unter gegebenen Bedingungen in eine begründete strategische Wegentscheidung und daraus abgeleitete kritische Erfolgsfaktoren überführt wird.
>
> [^formation-domain]: *Autorenableitung in Anlehnung an Rumelt (2011), Porter (1996), Hamel und Prahalad (1989), Mintzberg und Waters (1985) sowie Parmenter (2020)*: O2I fasst strategische Wegentscheidung und abgeleitete Erfolgsbereiche als zusammenhängende fachliche Domäne.

### Strategie

> [!definition]
> **Strategie** (en.: *strategy*; meta: `Strategy`)[^strategy] bezeichnet die *begründete und kohärente Wegentscheidung* eines handlungsfähigen Akteurs[^actor], der legitim entscheiden, Ressourcen binden und Verantwortung tragen kann. Mit einer Strategie legt dieser Akteur fest, wie er seine [Vision](#vision) unter gegebenen Bedingungen verwirklichen will und sich dabei gegenüber relevanten Alternativen unterscheidbar festlegt.
>
> > [!tldr] Strategie = \textsc{Wie} verwirklichen wir unsere Vision?
>
> [^strategy]: *Quellenanker*: Rumelt (2011) für Strategie als kohärente Antwort auf eine wesentliche Herausforderung; Porter (1996) für Positionierung, Trade-offs und Fit; Mintzberg und Waters (1985) für Strategie als intendiertes und realisiertes Handlungsmuster; Parmenter (2020) für Strategie als Weg zur Verwirklichung der Vision und als Grundlage für die Ableitung von CSFs und Performance-Maßen.

[^actor]: *Autorenableitung in Anlehnung an Rumelt (2011), Porter (1996) und Mintzberg und Waters (1985)*: Organisationseinheiten besitzen nicht automatisch eine eigene Strategie. Nach der hier verwendeten Definition gilt dies nur, wenn sie legitim entscheiden, Ressourcen binden, Verantwortung tragen und eine eigene Diagnose, Guiding Policy, Trade-offs und kohärente Handlungslogik ausbilden können.

Als Artefakt muss eine Strategie ihre Bestandteile dokumentieren. Eine explizit formulierte Strategie liefert mindestens Geltungsbereich, strategische Verankerung, abgeleitete Leitplanken, Diagnose, strategische Absicht, Guiding Policy, Positionierung, Trade-offs, kohärente Handlungsfestlegungen, strategische Erfolgsbezüge und Fit.

O2I modelliert Strategie dabei nicht als bloße Absichtserklärung. Strategische Handlungsfestlegungen sind durch Rumelts Konzept kohärenter Handlungen, Porters Aktivitätssysteme und Mintzbergs Verständnis von Strategie als Handlungsmuster begründbar. Ergänzend macht O2I eine Wegentscheidung prüfbar, indem sie mit nachvollziehbaren Erfolgsbezügen verbunden wird; diese Lesart ist eine Autorenableitung in Anlehnung an Doerr.

![O2I Strategiebestandteile](<img/O2I Strategy Constituents.png>){#fig:o2i-strategy-constituents-view}

@Fig:o2i-strategy-constituents-view zeigt O2I Strategiebestandteile und ihre fachlichen Beziehungen. Diese Bestandteile sind keine O2I-Kontexte und keine O2I-Primitives; sie beschreiben die innere fachliche Struktur einer explizit formulierten Strategie.

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

Eine übergeordnete Strategie richtet eine untergeordnete Strategie aus: Sie gibt Richtung, Prioritäten, Leitplanken, Restriktionen oder Zielbezüge vor, ohne die untergeordnete Strategie vollständig zu determinieren. Die untergeordnete Strategie muss daraus eine eigene Diagnose, Guiding Policy und kohärente Handlungsfestlegungen für ihren eigenen Geltungsbereich ableiten.

#### Diagnose

> [!definition]
> Die **Diagnose**[^diagnosis] beschreibt die für den jeweiligen Geltungsbereich strategisch entscheidende Herausforderung: Sie erklärt, warum die Vision unter gegebenen Bedingungen nicht ohne eine kohärente Wegentscheidung erreichbar ist.
>
> [^diagnosis]: *Quellenanker*: Rumelt (2011).

Eine Diagnose reduziert Komplexität, indem sie nicht die Gesamtheit aller beobachtbaren Probleme sammelt, sondern die strategisch relevante Herausforderung herausarbeitet. Dadurch wird zunächst bestimmbar, welchen Beitrag die strategische Absicht zur Vision leisten soll; erst danach wird bewertbar, ob die Guiding Policy tatsächlich auf diese Herausforderung passt.

#### Strategische Absicht

> [!definition]
> **Strategische Absicht**[^intent] bezeichnet den angestrebten Beitrag einer Strategie zur [Vision](#vision). Sie macht deutlich, welche Wirkung oder welcher Fortschritt durch die Wegentscheidung erreichbar werden soll, ohne bereits die konkrete Intervention festzulegen.
>
> [^intent]: *Autorenableitung in Anlehnung an Hamel und Prahalad (1989), Rumelt (2011), Mintzberg und Waters (1985) und Parmenter (2020)*: Hamel und Prahalad stützen Strategic Intent als langfristig ausrichtende strategische Absicht; Rumelt stützt die Abgrenzung von Vision, Herausforderung und strategischer Antwort; Mintzberg und Waters stützen Strategie als intendiertes Handlungsmuster; Parmenter stützt Strategie als Weg zur Verwirklichung der Vision.

Strategische Absicht fokussiert die Strategie auf den Beitrag, den sie zur Vision leisten soll. Sie ist konkreter als Vision, aber noch nicht Guiding Policy: Sie beschreibt den intendierten Fortschritt, nicht den gewählten strategischen Ansatz.

#### Guiding Policy / leitende Handlungslogik

> [!definition]
> Die **Guiding Policy**[^guiding-policy] bezeichnet den grundsätzlichen strategischen Ansatz, mit dem die diagnostizierte Herausforderung im Sinne der strategischen Absicht adressiert wird.
>
> [^guiding-policy]: *Quellenanker*: Rumelt (2011).

Die Guiding Policy übersetzt Diagnose und strategische Absicht in eine leitende Handlungslogik: Die Diagnose begründet, welche Herausforderung zu bewältigen ist; die strategische Absicht klärt, welchen Beitrag zur Vision die Strategie leisten soll; die Guiding Policy legt fest, mit welchem Ansatz diese Herausforderung adressiert wird.

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

#### Strategischer Erfolgsbezug

> [!definition]
> Ein **strategischer Erfolgsbezug**[^strategic-success-reference] bezeichnet ein vorab formuliertes, überprüfbares Ergebnis, dessen Erreichen den angestrebten Beitrag einer Strategie stützt.
>
> [^strategic-success-reference]: *Autorenableitung in Anlehnung an Rumelt (2011), Porter (1996) und Doerr (2018)*: Rumelt und Porter stützen die Kohärenz zwischen strategischer Absicht, Handlungsfestlegungen und Ergebnislogik; Doerr stützt überprüfbare Ergebnisbezüge. O2I führt den strategischen Erfolgsbezug als verpflichtenden Strategiebestandteil ein, ohne Strategie auf OKR-Mechanik zu reduzieren.

Ein strategischer Erfolgsbezug verbindet strategische Absicht und kohärente Handlungsfestlegungen: Handlungsfestlegungen tragen zu ihm bei; er substantiiert, woran der angestrebte strategische Beitrag erkennbar werden soll. Er ist weder KPI noch Messbeobachtung noch Wirkungsevidenz. Messung und empirische Bewertung folgen erst in Operationalisierung und Wirkung.

Im O2I-Metamodell wird jeder strategische Erfolgsbezug durch mindestens ein `Key Result @ Strategy` modelliert. Diese Key Results gehören nur dann zur Strategie, wenn sie deren Wegentscheidung überprüfbar machen und mit strategischer Absicht sowie kohärenten Handlungsfestlegungen relational verbunden sind.

#### Fit / Kohärenznachweis

> [!definition]
> **Fit**[^fit] bezeichnet den Kohärenznachweis, dass Positionierung, Trade-offs, kohärente Handlungsfestlegungen und strategische Erfolgsbezüge zueinander passen und sich gegenseitig stützen.
>
> [^fit]: *Quellenanker*: Porter (1996) für Fit zwischen Aktivitäten; Rumelt (2011) für Kohärenz als strategische Mindestanforderung.

Fit ist mehr als Widerspruchsfreiheit. Eine Strategie besitzt Fit, wenn ihre Handlungsfestlegungen die gewählte Position stärken, die bewussten Trade-offs respektieren, zu ihren Erfolgsbezügen beitragen und sich mit anderen Aktivitäten, Policies und Ressourcenbindungen gegenseitig unterstützen.

Fit validiert damit nicht einzelne Bestandteile isoliert, sondern das Zusammenspiel von Positionierung, Trade-offs, kohärenten Handlungsfestlegungen und strategischen Erfolgsbezügen. Fehlt dieser Fit, entsteht keine Strategie, sondern eine lose Sammlung einzelner Festlegungen und Ergebnisbezüge.

### Kritische Erfolgsfaktoren

> [!definition]
> Ein **kritischer Erfolgsfaktor** (en.: *critical success factor*)[^csf] bezeichnet einen aus der Strategie abgeleiteten Leistungs- oder Erfolgsbereich, in dem ein handlungsfähiger Akteur gut performen muss, damit die Strategie wirksam werden kann.
>
> [^csf]: *Quellenanker*: Parmenter (2020). *Autorenableitung in Anlehnung an Rumelt (2011) und Porter (1996)*: Kritische Erfolgsfaktoren werden in O2I aus der strategischen Wegentscheidung abgeleitet, insbesondere aus Guiding Policy, Positionierung, Trade-offs und Fit.

Kritische Erfolgsfaktoren gehören nicht zum Kernbegriff Strategie im Sinne von Rumelt, Porter oder Mintzberg. Sie werden aus Strategie abgeleitet und verbinden Formierung mit Situierung, Bedarfsqualifikation, Messung und Nachweislogik.

Sie markieren strategisch relevante Erfolgsbereiche, an denen sichtbar wird, welche Situationen bzw. Bedarfe für die Strategie relevant werden können. Ein kritischer Erfolgsfaktor ist damit noch kein KPI, kein Key Result und keine Maßnahme: Er beschreibt einen Erfolgsbereich, der später in konkreten Situationen situiert, über Bedarfsqualifikation handlungsrelevant gemacht und über geeignete Messungen überprüfbar wird.

In O2I begründen kritische Erfolgsfaktoren, welche Primitive-Verbindungen zwischen Strategie und Bedarf fachlich plausibel werden können. Dadurch wird eine Relation wie `Strategy --qualifies--> Need` nicht bloß behauptet, sondern über kontextualisierte Primitives motivierbar.

## Situierung

> [!definition]
> **Situierung**[^situating-domain] bezeichnet in O2I die fachliche Domäne, in der ein Bedarf in einer konkreten Situation verankert und dadurch sichtbar, begründbar und später überprüfbar wird.
>
> [^situating-domain]: *Autorenableitung in Anlehnung an Rumelt (2011), Porter (1996), Doerr (2018), Parmenter (2020) und The Open Group (2025, 2026)*: O2I verbindet strategische Relevanz mit fachlich beschriebener Arbeitsrealität in einer eigenständigen Domäne.

### Situation

> [!definition]
> Eine **Situation** (en.: *situation*; meta: `Situation`)[^situation] bezeichnet einen fachlich beschriebenen Arbeits-, Leistungs- oder Umfeldzusammenhang, in dem Bedarfe sichtbar, begründbar und später überprüfbar werden. O2I versteht `Situation` als abstrakten fachlichen Interpretationskontext: Konkrete Business-Architecture-Artefakte wie Business Capability, Business Process, Business Object, Business Role, Value Stream oder Regulatory Constraint konstituieren eine Situation als Situationsanker, wenn an ihnen Bedarfe sichtbar werden.
>
> > [!tldr] Situation = \textsc{Wo} genau in der fachlichen Realität zeigt sich ein Bedarf?
>
> [^situation]: *Autorenableitung in Anlehnung an Rumelt (2011), Porter (1996), Doerr (2018), Parmenter (2020) und The Open Group (2025, 2026)*: Situation wird hier als O2I-spezifischer Brückenbegriff eingeführt, um strategische Auswahl mit fachlich beschriebener Arbeitsrealität, Operationalisierung und Messbarkeit zu verbinden. TOGAF und ArchiMate sind geeignete Strukturierungs- und Notationsgrundlagen für solche Business-Architecture-Artefakte, aber nicht Quelle der O2I-Semantik.

![O2I Situation](<img/O2I Situation.png>){#fig:o2i-situation-view}

@Fig:o2i-situation-view zeigt `SituationAnchor` als abstrakte Metamodellkategorie und Business Capability, Business Process, Business Object, Business Role, Value Stream sowie Regulatory Constraint als deren zulässige Spezialisierungen. Eine Situation wird durch mindestens einen solchen Anker konstituiert. Die Sicht modelliert keine vollständige Business Architecture; Relationen zwischen konkreten Business-Architecture-Artefakten folgen der jeweiligen ArchiMate- bzw. TOGAF-Modellierung.

![O2I Situationsverankerung](<img/O2I Situation Anchoring.png>){#fig:o2i-situation-anchoring-view}

@Fig:o2i-situation-anchoring-view beantwortet darauf aufbauend die Frage: Wie verbindet ein Situationsanker Situation, Bedarf, Intervention und Messung fachlich? Derselbe Anker verortet einen `Driver @ Need`, wird durch eine `Action @ Intervention` verändert und durch einen `KPI @ Measure` beobachtet. Dadurch bleibt der Situationsbezug über Bedarf, Intervention und Messung hinweg relational nachvollziehbar.

Eine Situation muss somit fachlich, nicht technisch, beschrieben werden. Sie beschreibt nicht, mit welcher Technologie oder Lösung ein Bedarf erfüllt werden soll, sondern in welchem fachlichen Bezugsraum ein Bedarf sichtbar wird.

### Bedarf

> [!definition]
> Ein **Bedarf** (en.: *need*; meta: `Need`)[^need] bezeichnet eine begründete, auf eine konkrete [Situation](#situation) bezogene Anforderung an Veränderung, die dort sichtbar, begründbar und später überprüfbar wird, aber noch keine konkrete Lösung festlegt. Ein Bedarf beschreibt, was benötigt wird, nicht wie es umgesetzt oder erfüllt wird.
>
> > [!tldr] Bedarf = \textsc{Was} wird benötigt?
>
> [^need]: *Autorenableitung in Anlehnung an Rumelt (2011), Porter (1996), Doerr (2018) und Parmenter (2020)*: Bedarf wird hier als O2I-spezifischer Brückenbegriff zwischen Formierung und Operationalisierung eingeführt. Rumelt und Porter stützen die Ableitung aus strategischer Logik; Doerr und Parmenter stützen die anschließende Operationalisierung und Messbarmachung.

Ein Bedarf in O2I ist eine *situationsbezogene Anforderung an Veränderung* und folglich nur zulässig, wenn die erforderliche Veränderung an mindestens einem Situationsanker einer konkreten Situation sichtbar wird, etwa an einer Business Capability, einem Business Process, einem Business Object, einer Business Role, einem Value Stream oder einem Regulatory Constraint. Die Makrorelation `Situation --surfaces--> Need` macht diesen Bezug explizit. Ohne diesen Situationsbezug bleibt der Bedarf eine unqualifizierte Aussage über gewünschten Wandel, aber kein O2I-Bedarf.

Ein Bedarf ist keine Lösung, keine Maßnahme, kein Projekt und keine Anforderungsspezifikation. Diese können seine spätere Bearbeitung konkretisieren, dürfen ihn aber nicht ersetzen. Ein Bedarf bleibt auf der Ebene des benötigten fachlichen Ergebnisses.

Durch seinen Situationsbezug ist ein O2I-Bedarf sichtbar und prüfbar, aber noch nicht strategisch relevant. Diese Relevanz wird erst durch die Bedarfsqualifikation begründet, die den Bedarf über anschlussfähige Primitive-Verbindungen auf eine Strategie bezieht. Erst als sichtbar gewordener und strategisch relevanter Bedarf ist er wirkungsrelevant.

## Operationalisierung

> [!definition]
> **Operationalisierung**[^operationalization-domain] bezeichnet in O2I die fachliche Domäne, in der sichtbar gewordene Bedarfe strategisch qualifiziert und durch Interventionen handlungs- und nachweisfähig gemacht werden.
>
> [^operationalization-domain]: *Autorenableitung in Anlehnung an Rumelt (2011), Porter (1996), Doerr (2018), Parmenter (2020) und Barr (2014)*: O2I fasst Bedarfsqualifikation, Intervention und Messanschluss als zusammenhängende fachliche Domäne.

### Bedarfsqualifikation

> [!definition]
> Eine **Bedarfsqualifikation**[^needs-based-qualification] bezeichnet die strategische Bewertung, ob ein in einer Situation sichtbar gewordener Bedarf für eine Strategie relevant ist.
>
> [^needs-based-qualification]: *Autorenableitung in Anlehnung an Rumelt (2011), Porter (1996), Doerr (2018) und Parmenter (2020)*: Bedarfsqualifikation wird in O2I als strategische Bewertung sichtbar gewordener Bedarfe eingeführt. Rumelt und Porter stützen die strategische Begründung und Kohärenz der Qualifikation; Doerr und Parmenter stützen die Operationalisierung qualifizierter Bedarfe.

Die Bedarfsqualifikation unterscheidet folgende Stufen:

Bedarf

: situationsbezogene Anforderung an Veränderung.

sichtbar gewordener Bedarf

: Ein Bedarf ist in einer konkreten Situation fachlich sichtbar und prüfbar.

strategisch relevanter Bedarf

: Ein Bedarf ist durch Strategie qualifiziert.

wirkungsrelevanter Bedarf

: Ein Bedarf ist sichtbar und strategisch relevant.

Ein Bedarf ist strategisch relevant qualifiziert, wenn seine Veränderungsanforderung durch eine nachvollziehbare Relation zu Strategieinhalten begründet ist.

> [!addendum]
> Terminologisch erfolgt diese Begründung über kontextualisierte O2I-Primitives, ohne an dieser Stelle den Formalismus des Metamodells vollständig auszubreiten. Beispiel: `Key Result @ Strategy --translates-into--> Objective @ Need`. Damit ist `Strategy --qualifies--> Need` in O2I keine freie Behauptung, sondern eine als Autorenableitung eingeführte Makrorelation.

> [!definition]
> Eine **Qualifikationsvorlage** (en.: *need qualification proposal*)[^need-qualification-proposal] bezeichnet die vollständige Vorlage eines situierten Bedarfs zur Prüfung gegen eine bestehende Kandidatenstrategie. Sie referenziert den Bedarf und die Strategie, benennt ein `Key Result @ Strategy` und ein `Objective @ Need` als vorgeschlagene Primitive-Verbindung und enthält dafür eine fachliche Begründung mit Quellenbezug.
>
> [^need-qualification-proposal]: *Autorenableitung*: O2I operationalisiert die Bedarfsqualifikation durch die Trennung von fachlicher Begründung, formaler Zulässigkeitsprüfung und legitimierter Entscheidung.

Die Qualifikationsprüfung folgt einer klaren Arbeitsteilung:

1. Der Einreicher legt einen vollständig situierten Bedarf vor und referenziert die bestehende Strategie, an der er sich ausgerichtet hat. Die Strategie selbst ist Bestandteil des O2I-Modells und wird nicht mit der Vorlage eingereicht.
2. Eine fachliche Analyse schlägt die Primitive-Verbindung samt Begründung und Quellenbezug vor. Agentic AI kann diese Analyse unterstützen; O2I setzt ihren Einsatz nicht voraus und behandelt ihren Vorschlag nicht als Entscheidung.
3. Nach vollständiger Situierung des Bedarfs und vor der Modellierung von `translates-into` und `qualifies` prüft die O2I-Spezifikation mit `validateNeedQualificationProposal` deterministisch Situierung, Typen, Ownership, Strategy-Rollen, die formale Zulässigkeit der vorgeschlagenen Verbindung sowie das Vorliegen einer nichtleeren Begründung und Quellenreferenz. Ein Fehlerergebnis erzeugt keinen Kandidaten und keine fachliche Annahmeentscheidung; die Prüfung lässt den Graphen unverändert.
4. Ein positives Ergebnis ist ein formal zulässiger `NeedQualificationCandidate`, noch keine akzeptierte Qualifikation. Fachlich legitimierte Personen prüfen Begründung und Quelle. Eine Ablehnung lässt den Graphen unverändert.
5. Bei Annahme werden `Key Result @ Strategy --translates-into--> Objective @ Need` und `Strategy --qualifies--> Need` modelliert und das Modell erneut validiert. Erst wenn `qualifyingStrategies` danach die Strategie als qualifizierend liefert, ist der situierte Bedarf wirkungsrelevant.

Die Qualifikationsvorlage bleibt vom späteren Nachweisentwurf getrennt. Dieser entscheidet nicht über die strategische Relevanz des Bedarfs, sondern bereitet dessen Handlungs- und Nachweisfähigkeit vor.

Wirkungsrelevant heißt plausibel handlungsrelevant, nicht bereits wirksam. Erst eine spätere Messung kann zeigen, ob für die Bearbeitung eines wirkungsrelevanten Bedarfs positive Wirkungsevidenz vorliegt.

### Intervention

> [!definition]
> Eine **Intervention** (en.: *intervention*; meta: `Intervention`)[^intervention] bezeichnet eine gezielte Einwirkung auf eine [Situation](#situation), mit der ein wirkungsrelevanter Bedarf adressiert und eine strategisch relevante Veränderung erzeugt werden soll. Eine Intervention kann als Projekt, Maßnahme, Experiment, Programm, Initiative oder andere Umsetzungseinheit auftreten.
>
> > [!tldr] Intervention = \textsc{Wie} verändern wir die Situation?
>
> [^intervention]: *Autorenableitung in Anlehnung an Rumelt (2011), Porter (1996) und Doerr (2018)*: Interventionen gehören zur Operationalisierung einer strategischen Wegentscheidung. Sie übersetzen strategische Handlungslogik in konkrete Eingriffe, bleiben aber Wirkungshypothesen und keine Garantie für Zielerreichung.

Eine Intervention setzt einen wirkungsrelevanten Bedarf voraus. Sie adressiert nicht beliebige Wünsche, Lösungsideen oder sichtbare, aber strategisch irrelevante Bedarfe, sondern einen Bedarf, der in einer Situation sichtbar geworden und durch Bedarfsqualifikation als strategisch relevant qualifiziert ist.

Eine Intervention ist weder der Bedarf selbst noch die Wirkung. Sie ist eine Handlungshypothese: Sie beschreibt, wie eine Situation verändert werden soll, und macht die angestrebte Wirkung überprüfbar, ohne sie vorab zu behaupten.

> [!addendum]
> Das `Wie` einer Strategie und das `Wie` einer Intervention liegen auf unterschiedlichen Ebenen: Strategie beantwortet, wie eine Vision unter gegebenen Bedingungen verwirklicht werden soll; Intervention beantwortet, wie eine konkrete Situation wirkungsgerichtet verändert werden soll.
>
> > [!tldr] Strategie beschreibt das strategische `Wie`, Intervention das operative `Wie`.

Damit eine Intervention überprüfbar bleibt, *muss* sie an Messung anschließen. Sie verändert eine Situation und kann Zielwerte oder Zielbezüge für Messungen setzen, an denen später nachvollzogen wird, ob für die Bearbeitung des wirkungsrelevanten Bedarfs positive Wirkungsevidenz vorliegt.

## Wirkung

> [!definition]
> **Wirkung** bezeichnet in O2I die fachliche Domäne, in der beobachtete Veränderung relational und empirisch begründet wird. Eine **Wirkung**[^effect] bezeichnet darin eine beobachtbare und relational nachvollziehbare Veränderung, die als möglicher Beitrag der Operationalisierung einer strategischen Wegentscheidung zur [Vision](#vision) begründet werden kann.
>
> [^effect]: *Autorenableitung in Anlehnung an Porter (1996), Doerr (2018), Parmenter (2020) und Barr (2014)*: Wirkung wird hier als beobachtete Veränderung mit plausibler relationaler Attribution zur Operationalisierung einer strategischen Wegentscheidung verstanden. Porter liefert die Logik des Wertbeitrags durch Aktivitätssysteme; Doerr, Parmenter und Barr liefern Instrumente zur Überprüfung von Fortschritt und Performance.

Wirkung ist nicht die Intervention selbst, kein Zielwert und keine bloße Aktivität. Sie bezeichnet eine beobachtbare Veränderung, die über Messung und O2I-Relationen plausibel mit Intervention, Situation, Bedarf und Strategie verbunden ist.

Aus dieser Unterscheidung folgt die ex-post-Bewertung eines Bedarfs: Ein Bedarf ist zunächst wirkungsrelevant, wenn er situativ sichtbar und strategisch relevant ist. Wirkungsvoll wird er erst, wenn für seine Bearbeitung positive Wirkungsevidenz vorliegt.

> [!definition]
> Ein **wirkungsvoller Bedarf**[^effective-need] bezeichnet einen zuvor wirkungsrelevanten Bedarf, dessen Bearbeitung ex post durch positive Wirkungsevidenz gestützt wird.
>
> > [!tldr] wirkungsvoller Bedarf = ex post durch positive Wirkungsevidenz gestützter Bedarf
>
> [^effective-need]: *Autorenableitung in Anlehnung an Porter (1996), Doerr (2018), Parmenter (2020) und Barr (2014)*: Wirkungsvoller Bedarf wird in O2I als ex-post-Begriff eingeführt, um wirkungsrelevante Bedarfe von Bedarfen mit positiver Wirkungsevidenz zu unterscheiden. Porter stützt den strategischen Wirkungsbezug; Doerr, Parmenter und Barr stützen Messung und Nachweislogik.

Wirkungsrelevanz ist damit eine Ex-ante-Handlungsrelevanz; Wirkungsvollheit ist eine Ex-post-Nachweisqualität.

### Messung

> [!definition]
> Eine **Messung** (en.: *measure*; meta: `Measure`)[^measure] bezeichnet den fachlichen Messrahmen, in dem ein relevanter Zustand, eine relevante Leistung oder eine relevante Entwicklung in einer [Situation](#situation) beobachtbar gemacht wird. Sie wird durch Strategie fachlich gerahmt und macht die durch Interventionen angestrebten Veränderungen über KPIs beobachtbar.
>
> > [!tldr] Messung = \textsc{Woran} erkennen wir Veränderung?
>
> [^measure]: *Quellenanker*: Parmenter (2020) für KPIs und die Abgrenzung zu anderen Performance-Maßen; Barr (2014) für methodische Entwicklung aussagefähiger Performance-Maße. *Autorenableitung in Anlehnung an Doerr (2018), Parmenter (2020) und Barr (2014)*: `Measure` wird in O2I als Messrahmen modelliert; konkrete stabile Messdefinitionen werden als KPIs innerhalb dieses Rahmens geführt.

In O2I misst eine Messung eine Situation (`Measure --measures--> Situation`). Strategie rahmt, was gemessen werden muss (`Strategy --frames--> Measure`). Interventionen setzen Zielwerte oder Zielbezüge für Messungen, wenn sie eine angestrebte Veränderung überprüfbar machen (`Intervention --sets-target-for--> Measure`).

> [!definition]
> Ein **KPI** (en.: *key performance indicator*; meta: `KPI`)[^kpi] bezeichnet eine stabile, entscheidungsrelevante Messgröße innerhalb einer `Measure`. Seine KPI-Definition legt Maßeinheit, zulässigen Wertebereich, Messmethode und fachliche Interpretation verbindlich fest. Messbeobachtungen sowie Effekt- und Zielkriterien beziehen sich auf diese Definition.
>
> [^kpi]: *Quellenanker*: Parmenter (2020) für die stabile, entscheidungsrelevante Definition von KPIs; Barr (2014) für Messmethode und fachliche Interpretation aussagefähiger Performance-Maße. *Autorenableitung*: O2I fasst diese Merkmale in einer validierbaren KPI-Definition zusammen.

`Measure` und KPI bezeichnen unterschiedliche Modellebenen: `Measure` ist der fachliche Messrahmen; ein KPI ist eine stabile, entscheidungsrelevante Messgröße innerhalb dieses Rahmens. Die Evidenzebene repräsentiert ihre verbindliche Semantik durch genau eine validierte `KPIDefinition` je verwendetem KPI.

Messung ist nicht Wirkung selbst. Sie macht Zustände und Veränderungen beobachtbar und liefert Evidenz, die erst durch Nachweislogik als Wirkung gelesen werden kann.

> [!definition]
> Eine **Messbeobachtung**[^observation] bezeichnet einen zeitlich bestimmten, quellengebundenen Messwert eines KPI an einem Situationsanker. Einheit und zulässiger Wertebereich dieses Messwerts werden durch die referenzierte KPI-Definition bestimmt.
>
> [^observation]: *Autorenableitung in Anlehnung an Parmenter (2020) und Barr (2014)*: Messbeobachtung verbindet eine stabile KPI-Definition mit Messwert, Zeitpunkt, Quelle und fachlichem Beobachtungsgegenstand.

> [!definition]
> Ein **Effektkriterium**[^effect-criterion] bezeichnet die vorab festgelegte Mindestveränderung gegenüber einer Baseline, ab der eine Beobachtung als Evidenz für positive Wirkung gilt.
>
> [^effect-criterion]: *Autorenableitung in Anlehnung an Parmenter (2020) und Barr (2014)*: Das Effektkriterium operationalisiert eine relevante Veränderung unabhängig von der Zielerreichung.

Ein Effektkriterium kann eine absolute Veränderung in der Einheit des KPI oder eine relative Veränderung im Verhältnis zur Baseline fordern. Messbeobachtungen und Zielkriterien bezeichnen absolute Messniveaus; absolute Effektkriterien bezeichnen dagegen Veränderungen zwischen Messniveaus. Bei Prozentwerten wird eine absolute Veränderung in Prozentpunkten angegeben; eine relative Veränderung bleibt davon semantisch getrennt.

> [!definition]
> Ein **Zielkriterium**[^target-criterion] bezeichnet den vorab festgelegten Messwert oder Wertebereich, anhand dessen die Zielerreichung zu einem Beobachtungszeitpunkt beurteilt wird.
>
> [^target-criterion]: *Autorenableitung in Anlehnung an Doerr (2018), Parmenter (2020) und Barr (2014)*: Das Zielkriterium operationalisiert den angestrebten Ergebniszustand unabhängig von der gegenüber der Baseline beobachteten Wirkung.

Effekt und Zielerreichung sind damit getrennte Aussagen: Eine relevante Verbesserung kann eintreten, ohne dass das Ziel bereits erreicht ist; umgekehrt kann ein Zielwert erreicht sein, ohne dass die Intervention eine relevante Verbesserung gegenüber der Baseline erzeugt hat.

> [!definition]
> Ein **Nachweisentwurf** (en.: *evidence design*)[^evidence-design] bezeichnet die ex-ante festgelegte fachliche Planung, wie die Bearbeitung eines wirkungsrelevanten Bedarfs überprüfbar werden soll. Er verbindet eine geplante Intervention mit Measure und KPI, stabiler KPI-Definition, Baseline, Effekt- und Zielkriterium, Zieltermin sowie Quellenbezug.
>
> [^evidence-design]: *Autorenableitung in Anlehnung an Doerr (2018), Parmenter (2020) und Barr (2014)*: O2I fasst die vor Interventionsbeginn erforderlichen Mess-, Bewertungs-, Termin- und Herkunftsfestlegungen als eigenständigen Nachweisentwurf zusammen.

Der Nachweisentwurf qualifiziert keinen Bedarf und weist noch keine Wirkung nach. Er bildet die fachliche Grundlage für die anschließende Prüfung der Evidenzbereitschaft.

> [!definition]
> **Evidenzbereitschaft**[^evidence-readiness] bezeichnet die ex-ante Nachweisqualität eines vollständigen Wirkungstraces, für den vor Beginn der Intervention eine stabile KPI-Definition, Baseline, Effekt- und Zielkriterium, Zieltermin sowie Quellenbezug verbindlich festgelegt sind.
>
> > [!tldr] Evidenzbereitschaft = Wirkungstrace vor Interventionsbeginn mess- und bewertbar festgelegt
>
> [^evidence-readiness]: *Autorenableitung in Anlehnung an Doerr (2018), Parmenter (2020) und Barr (2014)*: O2I verbindet die Vorabfestlegung von Messgröße, Baseline, Kriterien, Zieltermin und Quellenbezug zu einer prüfbaren ex-ante Nachweisqualität.

Evidenzbereitschaft ist noch keine Wirkungsevidenz. Sie stellt sicher, dass die spätere Wirkungsbewertung nicht erst im Nachhinein an beobachtete Ergebnisse angepasst wird. Der geplante Interventionsbeginn wird dabei ex ante festgelegt; der tatsächliche Interventionsbeginn wird für die ex-post-Bewertung gesondert erfasst.

Eine organisatorische Einreichung kann den Nachweisentwurf bereits gemeinsam mit der Qualifikationsvorlage verlangen. Im O2I-Modell bleibt die Evidenzbereitschaft jedoch ein nachgelagerter Prüfschritt: Sie setzt einen akzeptierten wirkungsrelevanten Bedarf und einen vollständigen Wirkungstrace voraus und entscheidet nicht über dessen strategische Relevanz.

### Nachweislogik

> [!definition]
> Eine **Nachweislogik**[^evidence-logic] bezeichnet die nachvollziehbare Verknüpfung von wirkungsrelevantem Bedarf, Intervention, Messung und beobachteter Situationsveränderung, durch die Messwerte als Evidenz für Wirkung interpretiert werden können.
>
> > [!tldr] Nachweislogik = \textsc{Warum} darf eine Messung als Evidenz für Wirkung gelten?
>
> [^evidence-logic]: *Autorenableitung in Anlehnung an Doerr (2018), Parmenter (2020) und Barr (2014)*: Nachweislogik wird in O2I als verbindendes Begründungselement zwischen Messung und Wirkung eingeführt. Doerr stützt Ziel- und Ergebnisbezüge; Parmenter und Barr stützen Performance-Measurement-Disziplin und die methodische Qualität aussagefähiger Maße.

Nachweislogik ist kein eigener O2I-Typ und kein Modellelement. Sie ergibt sich als Begründungsstruktur aus dem vollständigen Wirkungstrace, dem Evidenzplan, der KPI-Definition, den Messbeobachtungen sowie deren Effekt- und Zielbewertung.

> [!addendum]
> Eine Messung darf in O2I nur dann als Evidenz für eine auf die Vision einzahlende Wirkung interpretiert werden, wenn sie eine relevante Situationsveränderung beobachtet, die auf einen wirkungsrelevanten Bedarf bezogen ist, dieser Bedarf durch eine Intervention adressiert wurde und im O2I-Graphen relational nachvollziehbar mit Strategie und Vision verbunden ist.

Nachweislogik verbindet Interventionen, relevante Messungen, Zielwerte, beobachtete Veränderungen und Lernschleifen. Sie erklärt, warum beobachtete Veränderungen als plausible Evidenz für Wirkung gelten, ohne daraus einen automatischen Kausalbeweis abzuleiten.

Damit bleibt Nachweislogik von Messung getrennt: Messung macht beobachtbar, Nachweislogik begründet die Wirkungslesart.

<a id="plausible-attribution"></a>

> [!addendum] Wirkungsevidenz und Kausalität
> Nachweislogik ermöglicht die begründete Zuordnung einer beobachteten Veränderung zu einer Intervention anhand des vollständigen O2I-Wirkungszusammenhangs. O2I bezeichnet diese Zuordnung als **plausible Attribution**[^plausible-attribution]; sie ist kein Beweis alleiniger Verursachung.
>
> O2I kann feststellen:
>
> - Eine Intervention adressiert einen wirkungsrelevanten Bedarf.
> - Sie ist auf denselben Situationsanker gerichtet, den der KPI misst.
> - Der Messwert steigt nach der Intervention von 40 % auf 75 %.
> - Effekt- und Zielkriterium sind erfüllt.
>
> O2I kann daraus jedoch nicht nachweisen, dass allein die Intervention den Anstieg verursacht hat. Auch parallele Maßnahmen, organisatorische Veränderungen oder externe Einflüsse können beigetragen haben.
>
> Ein kausaler Nachweis benötigt zusätzlich ein geeignetes Untersuchungsdesign, beispielsweise eine Kontrollgruppe, einen kontrafaktischen Vergleich oder eine belastbare Zeitreihenanalyse.

[^plausible-attribution]: O2I zeigt: "Diese Intervention ist eine plausible Erklärung für die Wirkung." Es beweist jedoch nicht: "Ausschließlich diese Intervention hat die Wirkung verursacht." Dafür ist ein kausales Untersuchungsdesign erforderlich.

# Metamodell

## Zweck

Das O2I-Metamodell ist der formale Kern des O2I Frameworks. Es übersetzt die O2I-Terminologie in eine prüfbare Modellstruktur: Begriffe werden als Typen gefasst, konkrete Modellelemente werden als Instanzen dieser Typen beschrieben, Primitives erhalten ihre Bedeutung durch Interpretation in Kontexten, und die gestufte Validierung prüft, ob ein Modell die O2I-Wirkungslogik einhält.

Die Haskell-Spezifikation in `spc/src/lib/` ist die normative, maschinenprüfbare Formalisierung des O2I-Metamodells. Sie typisiert zulässige Modellformen und unterscheidet strukturelle Wohlgeformtheit, semantische Gültigkeit, relationale Wirkungsnachvollziehbarkeit, ex-ante Evidenzbereitschaft und empirische Wirkungsevidenz. Das Metamodell bleibt technologieunabhängig; GADTs, Module und opake Validierungsstufen sind Haskell-Designentscheidungen und keine zusätzliche O2I-Fachsemantik.

Das Metamodell ersetzt die Terminologie nicht. Die Terminologie legt die fachliche Bedeutung fest; das Metamodell macht diese Bedeutung modellierbar, referenzierbar und validierbar.

> [!tldr]
> Terminologie erklärt Bedeutung; das Metamodell formalisiert sie; die Haskell-Spezifikation macht sie maschinenprüfbar; Syntax stellt sie dar.

## Semantik

Die O2I-Semantik definiert, welche Modellformen zulässig sind und wie sie gelesen werden. Sie wird in den folgenden semantischen Bausteinen konkretisiert:

Die Haskell-Library trennt dafür drei Verantwortungsbereiche: `O2I.Language` definiert den semantischen Formvorrat, `O2I.Graph` repräsentiert konkrete O2I-Graphen und `O2I.Validation` prüft diese Graphen stufenweise. Das Typsystem beschränkt zulässige Interpretationen und Relationsdomänen; die Laufzeitvalidierung prüft konkrete Bezeichner, Eigentümerschaft, globale Invarianten und vollständige Wirkungspfade. `O2I` bildet die kuratierte Gesamtfassade.

Typen

: legen fest, welche Kontexte, Primitives, Strukturierungen und Relationen O2I kennt.

Instanziierung

: beschreibt, wie aus O2I-Typen konkrete Modellelemente und Relationen in einem O2I-Modell gebildet werden.

Interpretation

: legt fest, welche Bedeutung ein Primitive in einem Kontext erhält.

Die Haskell-Spezifikation verwendet `DataKinds` und GADTs, um zulässige Relationstypen auf Typebene auszudrücken. Dadurch wird ein Teil der O2I-Semantik bereits in der Spezifikation typisiert.

Typen und Instanziierung beschreiben die formale Struktur eines O2I-Modells. Interpretation legt fest, welche Bedeutung diese Struktur trägt. Wohlgeformtheit und Validierung prüfen anschließend, ob ein Modell O2I-konform ist.

Die Syntax ist davon getrennt. Sie beschreibt erst anschließend, wie diese Semantik in einer Modellierungssprache, insbesondere ArchiMate, dargestellt wird.

### Typen

O2I-Typen beschreiben die abstrakten Arten von Modellelementen. Sie enthalten noch keine konkreten fachlichen Inhalte; sie legen nur fest, welche Formen ein O2I-Modell verwenden darf.

#### Kontexte

> [!definition]
> Ein **O2I-Kontext**[^o2i-context] bezeichnet einen fachlichen Interpretationsrahmen, der einem O2I-Primitive seine kontextspezifische Bedeutung gibt.
>
> [^o2i-context]: *Autorenableitung in Anlehnung an Collins und Porras (1996), Schein (2010), Rumelt (2011), Porter (1996), Doerr (2018), Parmenter (2020), Barr (2014) und The Open Group (2025, 2026)*: O2I formalisiert die quellenbasierten Terminologiebegriffe als unterscheidbare semantische Interpretationsrahmen.

@Fig:o2i-context-view zeigt das Kontextmodell des O2I-Metamodells: O2I-Kontexte und ihre Relationen.

![O2I Kontextmodell](<img/O2I Context.png>){#fig:o2i-context-view}

Die Darstellung ist als semantische Verdichtung der Terminologie zu lesen. Sie ersetzt die terminologischen Definitionen nicht, sondern zeigt, welche Kontextrelationen auf Metamodellebene zulässig sind.

##### Elemente

@Lst:o2i-context-types zeigt das Kontext-Inventar und legt fest, welche fachlichen Interpretationsrahmen O2I als Kontexttypen kennt.

```{#lst:o2i-context-types .haskell caption="O2I Kontexttypen"}
!include`snippetStart="-- ** Contexts", snippetEnd="-- ** Primitives"` spc/src/lib/O2I/Language/Element.hs
```

`Ethos`, `Mission` und `Vision` bilden eine Orientierung. `Strategy` ist der Kontext für eine strategische Wegentscheidung innerhalb einer Formierung. Kritische Erfolgsfaktoren sind in O2I kein eigener Kontext, sondern strukturieren die strategische Erfolgslogik; sie vermitteln zwischen Strategie, Bedarfsqualifikation, Messrahmung und späterer Operationalisierung. `Need`, `Intervention`, `Measure` und `Situation` bilden die Kontexte für Situierung, Operationalisierung und Wirkung.

##### Relationen

Kontextrelationen beschreiben fachliche Relationen zwischen Kontexttypen. @Lst:o2i-context-relations zeigt exemplarisch ihre kontextsensitive Typisierung; das vollständige Inventar liegt in der totalen Relationsregistry der Spezifikation.

```{#lst:o2i-context-relations .haskell caption="O2I Kontextrelationen (Auszug)"}
!include`snippetStart="-- ** Context macrorelations", snippetEnd="-- ** Remaining context macrorelations"` spc/src/lib/O2I/Language/Relation.hs
```

Diese typisierte Spezifikation verhindert, dass beliebige Kontextrelationen als O2I-Relationen ausgegeben werden. Beispielsweise ist `Strategy --qualifies--> Need` zulässig; `Need --qualifies--> Strategy` ist kein O2I-Relationstyp.

#### Primitives

> [!definition]
> Ein **O2I-Primitive**[^o2i-primitive] bezeichnet einen abstrakten formalen Träger fachlicher Inhalte, dessen O2I-Bedeutung durch Interpretation in einem O2I-Kontext entsteht.
>
> [^o2i-primitive]: *Autorenableitung in Anlehnung an Rumelt (2011), Porter (1996), Doerr (2018), Parmenter (2020), Barr (2014) und The Open Group (2026)*: O2I verdichtet fachliche Strategie-, Ziel-, Handlungs- und Messbegriffe zu einem kleinen kontextualisierbaren Formvorrat.

@Fig:o2i-primitives-view zeigt das O2I Primitives-Modell des O2I-Metamodells.

![O2I Primitives-Modell](<img/O2I Primitives.png>){#fig:o2i-primitives-view width=75%}

Die Darstellung ist als semantische Übersicht des abstrakten Formvorrats zu lesen. Sie ersetzt weder die Interpretation der Primitives in Kontexten noch die typisierte Spezifikation, sondern zeigt, welche Primitives, Strukturierungstypen und Primitive-Relationen auf Metamodellebene vorkommen. Die konkrete Zulässigkeit einer Relation ergibt sich erst aus ihren kontextualisierten Endpunkten in der typisierten Spezifikation; beispielsweise ist `sets-target-for` in O2I als `KeyResult @ Intervention -> KPI @ Measure` typisiert.

##### Elemente

Das Primitive-Inventar legt fest, welche abstrakten Träger fachlicher Inhalte O2I kennt. @Lst:o2i-primitive-types zeigt diese Primitive-Typen.

```{#lst:o2i-primitive-types .haskell caption="O2I Primitive-Typen"}
!include`snippetStart="-- ** Primitives", snippetEnd="-- ** Structuring"` spc/src/lib/O2I/Language/Element.hs
```

##### Relationen

Primitive-Relationen beschreiben die abstrakte Begründungsstruktur zwischen modellierten Inhalten. Sie verbinden kontextualisierte Primitives und, wo erforderlich, Strukturierungen oder Situationsanker. Die Spezifikation gliedert repräsentative typisierte Ausschnitte in Orientierungs- und Strategie-Bezüge, Bedarfs- und Messrahmungsbezüge sowie Interventions- und Wirkungsbezüge; die totale Relationsregistry enthält das vollständige Inventar.

@Lst:o2i-primitive-relations-orientation-strategy zeigt den typisierten Übergang von Orientierung zu Formierung.

```{#lst:o2i-primitive-relations-orientation-strategy .haskell caption="O2I Primitive-Relationen: Orientierung und Strategie (Auszug)"}
!include`snippetStart="-- ** Orientation and strategy evidence", snippetEnd="-- ** Remaining orientation and strategy evidence"` spc/src/lib/O2I/Language/Relation.hs
```

@Lst:o2i-primitive-relations-need-measure konkretisiert die Begründungsstruktur für Bedarfsqualifikation und Messrahmung.

```{#lst:o2i-primitive-relations-need-measure .haskell caption="O2I Primitive-Relationen: Bedarf und Messrahmung (Auszug)"}
!include`snippetStart="-- ** Need and measurement evidence", snippetEnd="-- ** Remaining need and measurement evidence"` spc/src/lib/O2I/Language/Relation.hs
```

@Lst:o2i-primitive-relations-intervention-effect konkretisiert die Begründungsstruktur für Intervention, Zielbezug, Situationsveränderung und Messbeobachtung.

```{#lst:o2i-primitive-relations-intervention-effect .haskell caption="O2I Primitive-Relationen: Intervention und Wirkung (Auszug)"}
!include`snippetStart="-- ** Intervention and effect evidence", snippetEnd="-- ** Remaining intervention and effect evidence"` spc/src/lib/O2I/Language/Relation.hs
```

Diese typisierten Spezifikationen verhindern, dass beliebige Primitive-Relationen als O2I-Relationen ausgegeben werden. Eine Relation wird nicht nur nach Primitive-Art, sondern nach kontextualisiertem Endpunkt typisiert, etwa `KeyResult @ Strategy -> Objective @ Need`.

#### Strukturierung

> [!definition]
> Eine **Performance-Dimension** (en.: *performance dimension*; meta: `PerformanceDimension`)[^o2i-performance-dimension] bezeichnet eine typisierte Ordnungsachse für Leistung und Erfolg in genau einer von zwei Rollen: Als strategische Erfolgsdimension strukturiert sie `Key Result`-Primitives einer `Strategy`; als Messdimension strukturiert sie `KPI`-Primitives einer `Measure`. Sie ist weder O2I-Kontext noch O2I-Primitive.
>
> [^o2i-performance-dimension]: *Autorenableitung in Anlehnung an Parmenter (2020) und The Open Group (2026)*: O2I verbindet fachliche Erfolgs- und Messbereiche in einem einheitlichen, typisierten Strukturierungskonzept.

@lst:o2i-structuring-types zeigt den Strukturierungstyp und seine beiden geschlossenen Rollen.

```{#lst:o2i-structuring-types .haskell caption="O2I Performance-Dimensionen"}
!include`snippetStart="-- ** Structuring", snippetEnd="-- ** Situation anchors"` spc/src/lib/O2I/Language/Element.hs
```

`PerformanceDimension` ist ein einheitlicher, geschlossener Strukturierungstyp des O2I-Metamodells. `StrategySuccessDimension` und `MeasureMeasurementDimension` bezeichnen seine beiden zulässigen Rollen, keine zusätzlichen Metamodelltypen. Ein kritischer Erfolgsfaktor (`CSF`) kann als benannte strategische Erfolgsdimension modelliert werden; eine Messdimension strukturiert zugehörige KPIs. Andere Gruppierungen sind keine O2I-Performance-Dimensionen.

Die Haskell-Spezifikation typisiert jede Performance-Dimension durch einen `PerformanceDimensionRole`-Zeugen. Derselbe Zeuge bestimmt Eigentümerkontext, zulässigen Mitgliedstyp und `contains`-Relation. Dadurch sind andere Kontexte oder Mitgliedschaften weder Teil des Metamodells noch als typisierte O2I-Relation konstruierbar.

#### Situationsanker

> [!definition]
> Ein **Situationsanker**[^o2i-situation-anchor] bezeichnet ein konkretes Business-Architecture-Artefakt, das eine `Situation` fachlich konstituiert und an dem Bedarfe sichtbar, Interventionen wirksam und Messungen beobachtbar werden. Er ist weder O2I-Kontext noch O2I-Primitive.
>
> [^o2i-situation-anchor]: *Autorenableitung in Anlehnung an The Open Group (2025, 2026)*: O2I verwendet Business-Architecture-Artefakte als fachliche Anker für Situierung, Intervention und Messung.

@Lst:o2i-situation-anchor-types zeigt das zulässige Inventar dieser Anker.

```{#lst:o2i-situation-anchor-types .haskell caption="O2I Situationsanker"}
!include`snippetStart="-- ** Situation anchors", snippetEnd="-- ** Node kinds"` spc/src/lib/O2I/Language/Element.hs
```

### Instanziierung

Instanziierung beschreibt, wie aus O2I-Typen konkrete Modellelemente in einem O2I-Modell entstehen. `Need` ist ein Kontexttyp; ein konkreter Bedarf in einem Modell ist eine `Need`-Instanz. `Objective` ist ein Primitive-Typ; ein konkretes Objective in einem Modell ist eine `Objective`-Instanz.

Graph bezeichnet als Oberbegriff die Knoten-Kanten-Repräsentation eines O2I-Modells. `RawGraph` ist ihre ungeprüfte, `WellFormedGraph` ihre lokal validierte Form. Ein `WellFormedGraph` erfüllt die lokale graphbezogene Zulässigkeit von Identitäten, Ownership, Interpretationen und Relationsdomänen. Ab `SemanticallyValidModel` bezeichnet `Model` die fachlich angereicherte Einheit, die den wohlgeformten Graphen stufenweise mit globalen fachlichen Invarianten, abgeleiteten Wirkungstraces und Evidenzbewertungen verbindet. Der Übergang markiert damit die Grenze zwischen lokaler graphbezogener Zulässigkeit und globaler fachlicher Invariantenprüfung.

Die Validierung überführt eine Modellinstanz in aufeinander aufbauende Stufen:

```text
RawGraph
  -> WellFormedGraph
  -> SemanticallyValidModel
  -> TraceableEffectModel
  -> EvidenceReadyModel
  -> EvidenceAssessedModel
```

@lst:o2i-model-graph zeigt den generischen konkreten O2I-Modellgraphen, mit dem konkrete Kontexte, Primitives, Strukturierungen, Situationsanker und Relationen repräsentiert werden.

```{#lst:o2i-model-graph .haskell caption="O2I Modellgraph"}
!include`snippetStart="-- * Typed graph", snippetEnd="-- * Well-formed graph stage"` spc/src/lib/O2I/Graph/Typed.hs
```

#### Kontextinstanzen

Eine Kontextinstanz ist ein konkreter fachlicher Interpretationsrahmen in einem Modell, etwa eine konkrete Vision, eine konkrete Strategie, ein konkreter Bedarf oder eine konkrete Situation.

#### Primitive-Instanzen

Eine Primitive-Instanz ist ein konkretes modelliertes Inhaltselement, das einer Kontextinstanz zugeordnet ist. Seine Bedeutung ergibt sich nicht allein aus dem Primitive-Typ, sondern aus dem Zusammenspiel von Primitive-Typ und Kontextinstanz.

#### Relationsinstanzen

Eine Relationsinstanz verbindet konkrete Kontext-, Primitive-, Strukturierungs- oder Ankerinstanzen. Ihre Zulässigkeit wird gegen die im Metamodell definierten Relationstypen geprüft.

> [!note]
> Verfeinerung ist eine generische Modellierungsoperation zur fachlichen Präzisierung von O2I-Modellelementen. Sie verändert weder deren O2I-Typ noch deren kontextuelle Interpretation und begründet keine Wirkungsrelevanz oder Wirkungsevidenz. Deshalb führt das O2I-Metamodell `refines` nicht als eigene Relation.

### Interpretation

Interpretation legt fest, welche Bedeutung ein O2I-Primitive in einem O2I-Kontext erhält. Dadurch wird derselbe abstrakte Primitive-Typ in unterschiedlichen Kontexten fachlich unterschiedlich lesbar.

@lst:o2i-interpretations zeigt die zulässigen Interpretationen von Primitives in Kontexten.

```{#lst:o2i-interpretations .haskell caption="O2I Interpretationen"}
!include`snippetStart="-- ** Interpretations", snippetEnd="-- ** Interpretation registry"` spc/src/lib/O2I/Language/Interpretation.hs
```

Die GADT-Konstruktoren bilden den typisierten Spezifikationskern der Interpretationen. Die endliche Registry projiziert diese Interpretationszeugen in eine zur Laufzeit prüfbare Zuordnung für konkrete Modellelemente. Dadurch wird keine zweite fachliche Zulässigkeitstabelle gepflegt.

#### Primitives

Ein `Objective` im Kontext `Vision` beschreibt ein qualitatives Zukunftsbild. Ein `Objective` im Kontext `Need` beschreibt ein benötigtes fachliches Ergebnis. Ein `Driver` im Kontext `Strategy` beschreibt die Diagnose; ein `Principle` im Kontext `Strategy` beschreibt die leitende Handlungslogik. Eine `Action` im Kontext `Strategy` beschreibt eine kohärente strategische Handlungsfestlegung; eine `Action` im Kontext `Intervention` beschreibt eine gezielte Einwirkung. Ein `Key Result` im Kontext `Intervention` beschreibt den überprüfbaren Ziel- oder Ergebnisbezug einer Intervention.

Im Metamodell werden kohärente strategische Handlungsfestlegungen als `Action @ Strategy` modelliert. Strategische Erfolgsbezüge werden als `Key Result @ Strategy` modelliert. `Key Result @ Strategy` ist keine klassische Strategiekategorie, sondern eine O2I-Autorenableitung in Anlehnung an Rumelt, Porter und Doerr.

#### Kontextrelationen

Kontextrelationen sind fachliche Makrorelationen. Sie machen sichtbar, wie O2I-Kontexte zueinander stehen, etwa `Strategy --qualifies--> Need`, `Intervention --addresses--> Need` oder `Measure --measures--> Situation`.

Eine Kontextrelation ist nicht automatisch hinreichend begründet. O2I unterscheidet deshalb zwischen zulässiger Makrorelation und validierter Makrorelation.

#### Primitive-Relationen

Primitive-Relationen bilden die Begründungsstruktur unterhalb von Kontextrelationen. Sie zeigen, warum eine Makrorelation fachlich belastbar ist. Für `Strategy --frames--> Measure` unterscheidet O2I dabei bewusst zwei Rollen: `Driver @ Strategy --indicates--> PerformanceDimension @ Measure` zeigt den relevanten Beobachtungsbereich an; `Key Result @ Strategy --determines--> PerformanceDimension @ Measure` bestimmt, welche Messdimension für den strategischen Erfolgsbezug maßgeblich ist.

Beispiel:

```text
Key Result @ Strategy --translates-into--> Objective @ Need
```

Diese Primitive-Relation kann begründen, warum eine konkrete Strategie einen konkreten Bedarf qualifiziert. Damit wird `Strategy --qualifies--> Need` nicht bloß behauptet, sondern über kontextualisierte Primitives motiviert.

## Wohlgeformtheit und Validierung

O2I unterscheidet einen ungeprüften Rohgraphen und fünf aufeinander aufbauende Validierungsstufen. Ein `RawGraph` enthält ungeprüfte Eingabedaten. Ein `WellFormedGraph` erfüllt die strukturellen Typ-, Interpretations- und Relationsregeln. Ein `SemanticallyValidModel` erfüllt zusätzlich die globalen Need- und Strategy-Invarianten. Ein `TraceableEffectModel` weist für jeden durch eine Intervention adressierten Bedarf einen vollständigen relationalen Wirkungstrace von Vision bis Situationsanker nach. Ein `EvidenceReadyModel` ergänzt jeden Trace vor Interventionsbeginn um einen validierten Evidenzplan. Ein `EvidenceAssessedModel` bewertet konsistente Folgebeobachtungen getrennt nach Effekt und Zielerreichung.

@Fig:o2i-evidence-sequence verdichtet die fachliche Nachweisfolge vom sichtbaren Bedarf bis zur Wirkungsevidenz. Sie trennt Bedarfsqualifikation, relationale Wirkungsnachvollziehbarkeit, ex-ante Evidenzbereitschaft und ex-post Evidenzbewertung und markiert den Interventionsbeginn als zeitliche Grenze.

![O2I Nachweisfolge](<img/O2I Nachweisfolge.png>){#fig:o2i-evidence-sequence width=65%}

Die Abbildung fokussiert die Nachweisfolge ab dem semantisch gültigen Modell. Die folgenden Listings zeigen ergänzend die vollständige Validierungskette von der strukturellen Elaborierung bis zur Evidenzbewertung.

@Lst:o2i-validation zeigt die strukturelle Elaborierung eines `RawGraph` in einen opaken `WellFormedGraph`.

```{#lst:o2i-validation .haskell caption="O2I Strukturvalidierung"}
!include`snippetStart="-- * Structural validation", snippetEnd="nodeErrors ::"` spc/src/lib/O2I/Validation/Structure.hs
```

@Lst:o2i-semantic-validation zeigt die zweite Validierungsstufe für semantische Gültigkeit.

```{#lst:o2i-semantic-validation .haskell caption="O2I Semantikvalidierung"}
!include`snippetStart="-- * Semantic validation", snippetEnd="-- * Validated model access"` spc/src/lib/O2I/Validation/Semantics.hs
```

@Lst:o2i-effect-trace zeigt die dritte Validierungsstufe für relational nachvollziehbare Wirkung.

```{#lst:o2i-effect-trace .haskell caption="O2I Wirkungstrace"}
!include`snippetStart="-- * Traceability validation", snippetEnd="matchesInterventionNeed ::"` spc/src/lib/O2I/Validation/Trace.hs
```

@Lst:o2i-readiness-validation zeigt die vierte Validierungsstufe für ex-ante Evidenzbereitschaft.

```{#lst:o2i-readiness-validation .haskell caption="O2I Evidenzbereitschaft"}
!include`snippetStart="-- * Readiness validation", snippetEnd="plansByTrace ::"` spc/src/lib/O2I/Validation/Readiness.hs
```

@Lst:o2i-evidence-validation zeigt die fünfte Validierungsstufe für empirische Wirkungsevidenz.

```{#lst:o2i-evidence-validation .haskell caption="O2I Evidenzvalidierung"}
!include`snippetStart="-- * Evidence validation", snippetEnd="followUpsByTrace ::"` spc/src/lib/O2I/Validation/Evidence.hs
```

### Grundregeln

Ein Modell ist wohlgeformt, wenn Bezeichner eindeutig sind, Eigentümer existieren, Primitives nur in zulässigen Kontexten verwendet werden, Performance-Dimensionen nur in ihren zulässigen Rollen stehen, Situationsanker nur in `Situation` vorkommen und Relationsendpunkte typgerecht sind. Fehler werden akkumuliert, damit eine Prüfung sämtliche erkannten Strukturverletzungen gemeinsam ausweist.

### Semantische Gültigkeit

Ein strukturell wohlgeformter Graph ist semantisch gültig, wenn jeder Bedarf einen `Driver` und ein `Objective` besitzt, durch mindestens eine Situation sichtbar wird, jeder Need-Driver an einen diese Situation konstituierenden Situationsanker gebunden ist und jedes Need-Objective durch einen Need-Driver begründet wird. Die strategische Qualifikation ist davon unabhängig: Ein vollständig situierter Bedarf kann semantisch gültig sein, ohne bereits wirkungsrelevant zu sein.

Jede Strategy-Instanz besitzt genau eine vollständige Formulierung. Sie umfasst Geltungsbereich, strategische Verankerung, abgeleitete Leitplanken, Diagnose, strategische Absicht, Guiding Policy, Positionierung, Trade-offs, kohärente Handlungsfestlegungen, strategische Erfolgsbezüge und Fit-Begründung. Jeder strategische Erfolgsbezug wird durch ein `Key Result @ Strategy` modelliert. Sämtliche Textfelder müssen nichtleer sein; Action- und Key-Result-Referenzen müssen innerhalb ihrer Rolle eindeutig sein. @Lst:o2i-strategy-formulation zeigt die strukturierte Repräsentation dieser Bestandteile.

```{#lst:o2i-strategy-formulation .haskell caption="O2I Strategy-Formulierung"}
!include`snippetStart="-- * Strategy formulation input", snippetEnd="-- | A Strategy formulation"` spc/src/lib/O2I/Validation/Semantics.hs
```

Die Formulierung muss ihre Primitive-Rollen derselben Strategy-Instanz zuordnen und relational kohärent sein: Der Diagnosis-Driver begründet das Intent-Objective, die Guiding Policy führt jede gelistete Action, jede gelistete Action trägt zu mindestens einem gelisteten Key Result bei und jedes gelistete Key Result substantiiert das Intent-Objective.

```text
Driver --grounds--> Objective
Principle --guides--> Action
Action --contributes-to--> Key Result
Key Result --substantiates--> Objective
```

Nur O2I-Primitives, die einer validierten Strategy-Formulierung in der jeweiligen Rolle zugeordnet sind, dürfen Strategy-bezogene Makrorelationen oder Wirkungstraces begründen. Weitere Strategy-Primitives können im Graphen bestehen, tragen jedoch ohne diese Zuordnung keine formale Strategy-Evidenz.

### Wirkungsrelevanz

Eine `Need`-Instanz ist im Metamodell wirkungsrelevant, wenn sie in einer `Situation`-Instanz sichtbar wird und durch eine `Strategy`-Instanz qualifiziert ist. Die strategische Qualifikation muss durch Primitive-Relationen begründbar sein.

Die Spezifikation konkretisiert dafür den zentralen O2I-USP: Eine `Strategy --qualifies--> Need`-Relation zählt nur dann als belastbar, wenn es eine passende Primitive-Begründung gibt, etwa `Key Result @ Strategy --translates-into--> Objective @ Need`.

Die Funktion `validateNeedQualificationProposal` prüft nach vollständiger Situierung des Bedarfs und vor der Modellierung dieser Relationen, ob eine Kombination aus Kandidatenstrategie, situiertem Bedarf, strategischem Key Result und Need-Objective formal zulässig ist und eine nichtleere fachliche Begründung mit Quellenreferenz enthält. Bei Fehlern bleibt das Modell unverändert. Ihr opakes Ergebnis `NeedQualificationCandidate` bestätigt ausschließlich die formale Zulässigkeit der Vorlage; es ersetzt weder die fachlich legitimierte Entscheidung noch persistiert es eine Qualifikation. Nach fachlicher Annahme werden beide Relationen modelliert, das Modell erneut validiert und die Qualifikation mit `qualifyingStrategies` abgefragt.

Die Abfrage `qualifyingStrategies` ermittelt diese Strategien direkt am semantisch gültigen Modell. Sie benötigt weder Intervention noch Messung und hält Bedarfsqualifikation damit von der späteren Operationalisierung und Wirkungsevidenz getrennt.

### Wirkungstrace

Ein Wirkungstrace entsteht, wenn dieselbe `Strategy`-Instanz eine `Need`-Instanz qualifiziert, eine `Intervention`-Instanz richtet und eine `Measure`-Instanz rahmt; wenn diese Intervention den wirkungsrelevanten Bedarf adressiert, eine über Situationsanker verankerte `Situation` verändert, Zielbezüge für die Messung setzt und diese Messung denselben Situationsbezug beobachtet. Die Messrahmung ist nur belastbar, wenn ein Strategy-Driver den Beobachtungsbereich anzeigt und ein Strategy-Key-Result denselben Messbereich für den Erfolgsnachweis bestimmt.

Ein vollständiger Wirkungstrace ist relational nachvollziehbar, aber weder evidenzbereit noch empirisch bewertet. Die Abfrage `readyTracesForIntervention` liefert ausschließlich Wirkungstraces einer Intervention, deren Evidenzpläne bereits ex ante validiert sind.

### Evidenzbereitschaft

Evidenzbereitschaft setzt einen vollständigen Wirkungstrace voraus. Die Spezifikation formalisiert den Nachweisentwurf durch `EvidencePlan`, die zugehörige `KPIDefinition` und `PlannedInterventionStart`. Für jeden im Trace verwendeten KPI wird genau eine `KPIDefinition`, für jede Intervention genau ein geplanter Beginn und für jeden Trace genau ein `EvidencePlan` validiert. Die KPI-Definition legt Einheit, zulässigen Wertebereich, Messmethode und fachliche Interpretation fest. Der Plan bindet Baseline, Effektkriterium, Zielkriterium, Zieltermin sowie Quellenbezug an denselben KPI und Situationsanker. Plan und Baseline müssen spätestens zum expliziten Prüfzeitpunkt feststehen; dieser Prüfzeitpunkt muss vor dem geplanten Interventionsbeginn liegen. Messniveaus, Kriterien und spätere Beobachtungen müssen dem definierten Wertebereich entsprechen; Quellen müssen eindeutig benannt sein.

`EvidenceReadyModel` bezeichnet damit den validierten ex-ante Zustand des Wirkungsmodells. Er enthält noch keine Folgebeobachtung und keine Aussage darüber, ob Wirkung oder Zielerreichung eingetreten sind.

### Wirkungsevidenz

Wirkungsevidenz bewertet ein evidenzbereites Wirkungsmodell zu einem expliziten Bewertungszeitpunkt. Für jede Intervention wird genau ein tatsächlicher Beginn erfasst. Jede Folgebeobachtung muss nach diesem Beginn und spätestens zum Bewertungszeitpunkt vorliegen, zum Trace, KPI und Situationsanker passen, innerhalb des durch die KPI-Definition festgelegten Wertebereichs liegen und einen Quellenbezug tragen. Damit gilt `readinessCheckedAt < actualStartAt < observedAt <= assessedAt`. Für jeden Trace ist mindestens eine Folgebeobachtung erforderlich; mehrere zeitlich unterscheidbare Folgebeobachtungen bilden getrennte Bewertungen. Das Effektkriterium prüft die relevante Veränderung gegenüber der Baseline. Das Zielkriterium prüft unabhängig davon, ob die jeweilige Beobachtung den Zielwert vor oder nach dem Zieltermin erfüllt; es bestimmt ohne Beobachtungsreihe nicht den Zeitpunkt erstmaliger Zielerreichung.

Die Evidenzebene besteht insbesondere aus `KPIDefinition`, `ValueDomain`, `Level`, `Delta`, `Observation`, `EvidencePlan`, `EffectCriterion`, `TargetCriterion`, `PlannedInterventionStart`, `ActualInterventionStart` und `FollowUpObservation`. Diese Typen sind weder O2I-Kontexte noch O2I-Primitives. Sie definieren, planen und bewerten die empirische Evidenz eines relational vollständigen Wirkungstraces.

### Abgeleitete Makrorelationen

Makrorelationen dürfen abgeleitet sein. Eine abgeleitete Makrorelation fasst mehrere Primitive-Relationen oder Syntaxrelationen zu einer fachlichen O2I-Relation zusammen. Entscheidend ist, dass die Ableitung explizit und prüfbar bleibt.

## Syntax

Die Syntax beschreibt, wie die O2I-Semantik in einer Modellierungssprache dargestellt wird. O2I verwendet ArchiMate als visuelle Darstellungs- und Integrationssyntax, ohne die O2I-Semantik durch ArchiMate-Semantik zu ersetzen.

Evidenztypen wie `KPIDefinition`, `ValueDomain`, `Level`, `Delta`, `Observation`, `EvidencePlan`, `EffectCriterion`, `TargetCriterion`, `PlannedInterventionStart`, `ActualInterventionStart` und `FollowUpObservation` sind weder O2I-Kontexte noch O2I-Primitives. Ihre konkrete Persistenz- oder Darstellungsform ist nicht Bestandteil des ArchiMate-Profils; sie werden durch die Validierungsspezifikation an einen Wirkungstrace gebunden.

### ArchiMate-Profil

Jeder O2I-Kontext wird als ArchiMate `Grouping` dargestellt. Ein O2I-Primitive wird durch seine Platzierung innerhalb des zugehörigen Kontext-Groupings kontextualisiert; `Primitive @ Context` ist die textuelle Notation dieses Containments. Die O2I-Primitives selbst werden durch wenige ArchiMate-Basisformen dargestellt.

### Primitives-Abbildung

Die folgende Zuordnung zeigt, wie O2I-Primitives durch ArchiMate-Basisformen dargestellt werden:

```text
O2I-Primitive Principle -> ArchiMate Principle -> normative Orientierung
O2I-Primitive Driver -> ArchiMate Driver -> begründender, spannungserzeugender oder bedarfsanzeigender Faktor
O2I-Primitive Objective -> ArchiMate Goal -> qualitatives Ziel
O2I-Primitive Key Result -> ArchiMate Outcome -> quantitative Evidenzgröße oder Zielwert
O2I-Primitive KPI -> ArchiMate Assessment -> stabile Messdefinition
O2I-Primitive Action -> ArchiMate Course of Action -> Wegentscheidung, Handlungslogik oder Intervention
```

Ein ArchiMate `Goal` stellt in O2I das O2I-Primitive `Objective` dar. Seine Bedeutung hängt vom O2I-Kontext ab: Im Kontext `Vision` beschreibt es einen orientierenden Zukunftszustand; im Kontext `Need` beschreibt es ein benötigtes fachliches Ergebnis.

Ein ArchiMate `Outcome` stellt in O2I das O2I-Primitive `Key Result` als quantitatives, überprüfbares Ergebnis oder als Zielwert dar. Im Kontext `Strategy` repräsentiert es einen strategischen Erfolgsbezug; im Kontext `Intervention` einen überprüfbaren Ziel- oder Ergebnisbezug. Es beschreibt, welches Ergebnis Beitrag oder Zielerreichung belegt, nicht wie dieses Ergebnis erreicht wird.

Ein ArchiMate `Assessment` stellt in O2I das O2I-Primitive `KPI` als stabile Messdefinition dar. Beobachtungen und Messwerte gehören zur Evidenzebene und werden nicht durch das `Assessment` selbst repräsentiert.

### Strukturierungsabbildung

Eine O2I-Performance-Dimension wird als ArchiMate `Grouping` innerhalb ihres Eigentümerkontexts dargestellt. Der Kontext bestimmt ihre Rolle und ihre zulässigen Mitglieder: Eine strategische Erfolgsdimension in `Strategy` enthält `Key Result`-Primitives; eine Messdimension in `Measure` enthält `KPI`-Primitives.

### Situationsanker-Abbildung

Situationsanker werden durch die jeweils semantisch entsprechenden ArchiMate-Business-Architecture-Elemente dargestellt:

```text
O2I BusinessCapability -> ArchiMate Capability
O2I BusinessProcess -> ArchiMate Process
O2I BusinessObject -> ArchiMate Business Object
O2I BusinessRole -> ArchiMate Role
O2I ValueStream -> ArchiMate Value Stream
O2I RegulatoryConstraint -> ArchiMate Requirement
```

`Process` und `Role` werden dabei fachlich als Business Process bzw. Business Role spezialisiert; `Requirement` wird als Regulatory Constraint spezialisiert. Die fachlichen O2I-Ankertypen bleiben dadurch von den generischen ArchiMate-4-Elementtypen unterscheidbar.

Für jede zulässige Ankerform `A` gilt dieselbe parametrisierte Relationsabbildung:

```text
Situation --aggregation[is-constituted-by]--> A
A --association[anchors]--> Driver im Kontext Need
Course of Action im Kontext Intervention --association[changes]--> A
Assessment im Kontext Measure --association[measures]--> A
```

Die drei `association`-Relationen sind gerichtet. Die konkrete ArchiMate-Semantik des jeweiligen Business-Architecture-Elements bleibt dabei erhalten.

### Relationsabbildung

O2I-Relationen werden in ArchiMate durch zulässige ArchiMate-Relationen zwischen konkreten Elementen dargestellt. Dabei sind Primitive-Begründungen und Kontext-Makrorelationen zu unterscheiden.

Primitive-Relationen werden zwischen ArchiMate-Elementen abgebildet, die O2I-Primitives darstellen:

```text
Principle im Kontext Ethos --influence[guides]--> Driver im Kontext Mission
Principle im Kontext Ethos --influence[guides]--> Goal im Kontext Vision
Driver im Kontext Mission --influence[grounds]--> Goal im Kontext Vision
Principle im Kontext Strategy --association[guides]--> Course of Action im Kontext Strategy
Outcome im Kontext Strategy --influence[translates-into]--> Goal im Kontext Need
Outcome im Kontext Strategy --realization[substantiates]--> Goal im Kontext Strategy
Driver im Kontext Strategy --influence[indicates]--> Grouping im Kontext Measure
Outcome im Kontext Strategy --influence[determines]--> Grouping im Kontext Measure
Grouping im Kontext Strategy --aggregation[contains]--> Outcome im Kontext Strategy
Grouping im Kontext Measure --aggregation[contains]--> Assessment im Kontext Measure
Outcome im Kontext Intervention --association[sets-target-for]--> Assessment im Kontext Measure
```

Kontext-Makrorelationen sind dokumentierte O2I-Relationen. In ArchiMate werden sie nicht als primäre ArchiMate-Semantik verstanden, sondern durch Relationen zwischen enthaltenen Elementen, durch beschriftete Dokumentationskanten zwischen Kontextbereichen oder durch explizit dokumentierte Ableitungen dargestellt:

```text
Ethos --guides--> Mission
Ethos --guides--> Vision
Mission --grounds--> Vision
Vision --orients--> Strategy
Strategy --directs--> Strategy
Strategy --contributes-to--> Strategy
Strategy --qualifies--> Need
Strategy --directs--> Intervention
Strategy --frames--> Measure
Situation --surfaces--> Need
Intervention --addresses--> Need
Intervention --changes--> Situation
Intervention --sets-target-for--> Measure
Measure --measures--> Situation
```

Die O2I-Relation `Vision --orients--> Strategy` kann in ArchiMate als `Influence`-Relation von einem `Goal` im Kontext `Vision` zu einem `Course of Action` im Kontext `Strategy` abgebildet werden. Fachlich bedeutet sie: Eine Vision gibt einer Strategie Richtung; die Strategie bleibt die Wegentscheidung, die diese Richtung unter gegebenen Bedingungen verfolgt.

### Abgeleitete Relationen

Eine O2I-Makrorelation darf aus mehreren ArchiMate-Elementen und -Relationen abgeleitet werden. Entscheidend ist, dass die fachlich wirksame Relation zwischen den enthaltenen Elementen nachvollziehbar bleibt.

Beispiel:

```text
O2I: Strategy --qualifies--> Need
```

kann syntaktisch begründet werden als:

```text
O2I-Kontext Strategy contains Outcome
O2I-Kontext Need contains Goal
Outcome im Kontext Strategy --influence[translates-into]--> Goal im Kontext Need
```

Die äußeren O2I-Kästen sind damit O2I-Kontexte; die fachlich wirksame Begründung liegt zwischen den enthaltenen Primitives.

### Modellierungsregeln

- ArchiMate ist Syntax; O2I ist Semantik.
- O2I-Kontexte werden als strukturierte Modellbereiche über O2I-Primitives modelliert.
- Ein ArchiMate `Goal` stellt in O2I ein `Objective` dar; ein ArchiMate `Outcome` stellt ein `Key Result` dar; ein ArchiMate `Assessment` stellt einen `KPI` dar.
- O2I-Makrorelationen dürfen aus mehreren Primitive-Relationen oder Syntaxrelationen abgeleitet werden.
- Aggregations- oder Kompositionskanten zwischen O2I-Kontexten ersetzen keine fachliche Relation zwischen den enthaltenen Primitives.
- `Situation` wird nicht auf ein einzelnes ArchiMate-Motivationselement reduziert, sondern durch konkrete fachliche Architekturartefakte instanziiert.
- Wenn eine O2I-Relation nicht mit einer zulässigen ArchiMate-Relation ausdrückbar ist, muss sie als abgeleitete Relation dokumentiert werden.

# Illustration

Der O2I Layered Cake ist eine beispielhafte Referenzsicht auf einen zusammenhängenden O2I-Wirkungsgraphen. Die Sicht zeigt, wie O2I-Kontexte mit Primitives befüllt und Makrorelationen durch Primitive-Relationen begründet werden.

\clearpage
\newgeometry{margin=8mm}
\begin{landscape}
\begin{center}
\vspace*{\fill}
\includegraphics[width=\linewidth,height=0.86\textheight,keepaspectratio]{img/O2I Layered Cake.png}
\captionof{figure}{O2I Layered Cake}
\label{fig:o2i-layered-cake}
\vspace*{\fill}
\end{center}
\end{landscape}
\restoregeometry
\clearpage

## Orientierung

@Fig:o2i-layered-cake beginnt mit dem Übergang von `Ethos` zu `Mission`. Im Kontext `Ethos` werden `Respect`, `Discipline` und `Independence` als `Principle` interpretiert. `Respect` bezeichnet den normativen Maßstab für den Umgang mit Menschen. `Discipline` bezeichnet den Anspruch an Verlässlichkeit, Konsequenz und Ausführung. `Independence` bezeichnet den Anspruch, eigenständig zu urteilen und zu handeln.

Diese Leitprinzipien prägen die Mission `#hggt` (*honest good time together*): eine aufrichtige, gute gemeinsame Zeit. `Respect` prägt, dass diese gemeinsame Zeit nicht instrumentell oder manipulativ verstanden wird. `Discipline` prägt, dass Aufrichtigkeit gepflegt und belastbar bleibt. `Independence` prägt, dass gemeinsames Handeln eigenständiges Urteil voraussetzt.

Damit wird die Makrorelation `Ethos --guides--> Mission` durch Primitive-Relationen der Form `Principle @ Ethos --guides--> Driver @ Mission` begründet.

Der nächste Übergang führt von `Mission` zu `Vision`. Im Kontext `Vision` wird `People act confidently from shared understanding` als `Objective` interpretiert. Die Mission `#hggt` begründet dieses Objective: Eine aufrichtige, gute gemeinsame Zeit entsteht, wenn Menschen aus geteilter Verständigung heraus sicher und begründet handeln können. Die Vision übersetzt damit den Mission-Driver in einen orientierenden Zustand gemeinsamer Wissens- und Entscheidungsgrundlagen.

Die Leitprinzipien aus `Ethos` prägen zugleich diese Vision. `Respect` verhindert, dass geteilte Verständigung instrumentell oder manipulativ verstanden wird. `Discipline` macht sie belastbar und konsequent. `Independence` stellt sicher, dass gemeinsames Verständnis eigenständiges Urteil nicht ersetzt, sondern ermöglicht.

Damit werden auch die Makrorelationen `Mission --grounds--> Vision` und `Ethos --guides--> Vision` durch Primitive-Relationen begründet.

## Formierung

Aus Orientierung wird Formierung, sobald die Vision in eine strategische Wegentscheidung übersetzt wird.

Aus der Vision `People act confidently from shared understanding` wird im Layered Cake die Strategie `Shared understanding` ausgerichtet. Das Objective `Make shared understanding actionable` konkretisiert, wie der visionäre Zustand strategisch bearbeitbar wird. Die Diagnose wird durch `Fragmented understanding blocks confident action` als `Driver` modelliert; dieser Driver begründet das strategische Objective. Der `Key Result` `80% of decisions reference shared decision records` substantiiert dieses Objective, während die `Action` `Create shared decision records` zu diesem Key Result beiträgt. Das Principle `Act from evidence, not assumptions` leitet die Action. Die Performance-Dimension `Shared decision evidence use` ordnet den strategischen Key Result als kritischen Erfolgsbereich; sie ist eine benannte strategische Erfolgsdimension, kein eigener O2I-Typ.

Damit adressiert die Strategy-Struktur zentrale Strategiebestandteile aus der Terminologie: Diagnose, strategische Absicht, Guiding Policy, Trade-offs, kohärente Handlungsfestlegungen und strategischen Erfolgsbezug. Strategische Positionierung und Fit/Kohärenznachweis werden im Layered Cake nicht als eigene Primitives modelliert. Positionierung ergibt sich als abgeleitete Lesart aus der strukturierten Kombination von Objective, Principle, Action und Key Result. Fit ist eine Validierungslogik über diese Struktur: Die Strategy-Primitives müssen kohärent zusammenpassen und durch ihre Relationen eine belastbare strategische Wegentscheidung tragen.

Die zweite Strategie `Organizational transparency` ist im Layered Cake als übergeordnete Strategie modelliert. Ihre eigene Ethos- und Mission-Herleitung wird bewusst nicht ausmodelliert, damit die Sicht den Fokus auf Strategy-to-Strategy-Begründungen behält. Die Vision `Organizational transparency` richtet das strategische Objective `Make critical knowledge transparent and usable` aus. Die Diagnose `Hidden knowledge fragments organizational action` begründet dieses Objective; der `Key Result` `90% of critical decisions are traceable to shared evidence` substantiiert es. Die Action `Establish shared evidence practices` trägt zu diesem Key Result bei; das Principle `Default to shared evidence over private interpretation` leitet die Action.

Zwischen beiden Strategien zeigt der Layered Cake zwei Begründungsebenen. `Default to shared evidence over private interpretation @ Organizational transparency` leitet `Act from evidence, not assumptions @ Shared understanding` und begründet damit die Makrorelation `Organizational transparency --directs--> Shared understanding`. Die Relation `80% of decisions reference shared decision records @ Shared understanding --contributes-to--> 90% of critical decisions are traceable to shared evidence @ Organizational transparency` zeigt den Erfolgsbeitrag. Zusätzlich zeigt `Create shared decision records @ Shared understanding --contributes-to--> Establish shared evidence practices @ Organizational transparency` den Umsetzungsbeitrag. Zusammen begründen diese Beitragsrelationen die Makrorelation `Shared understanding --contributes-to--> Organizational transparency`. Die Action-Relation begründet nicht `directs`; `directs` wird durch die Principle-Relation getragen.

## Situierung

Aus Formierung wird Situierung, sobald eine Strategie auf eine konkrete Situation trifft und Bedarfe sichtbar sowie strategisch qualifizierbar werden.

Der Übergang zu `Situation` und `Need` zeigt, wie ein Bedarf sichtbar und anschließend strategisch qualifiziert wird. Die Situation wird durch `Information Management` als `Business Capability` fachlich verankert. In einer realen Instanz wäre diese Situation typischerweise durch eine Business Architecture, etwa eine Business Capability Map, weiter ausmodelliert. `Information Management` umfasst das Sammeln, Organisieren, Verteilen und Sichern von Informationen sowie Werkzeuge, Richtlinien und Prozesse für Informationsnutzung, Archivierung und Pflichtkommunikation. Damit wird sichergestellt, dass Bedarfe nicht freischwebend formuliert werden, sondern in einem fachlich beschriebenen Bezugsraum sichtbar werden.

Im Need-Kontext beschreibt `Unshared and untraceable decisions create action uncertainty` als `Driver`, warum in dieser Situation Veränderung benötigt wird. Aus diesem Driver können unterschiedliche Need-Objectives entstehen: `Increase traceable decisions` und `Increase shared decision traceability`. Das erste Objective ist in der Situation sichtbar, wird durch die Strategie aber nicht als strategisch relevant qualifiziert. Das zweite Objective kann dagegen durch die Strategie als wirkungsrelevant qualifiziert werden: Der strategische Key Result `80% of decisions reference shared decision records` verlangt nicht nur nach nachverfolgbaren Entscheidungen, sondern nach Entscheidungen, die in einer gemeinsamen, referenzierbaren Form nachvollziehbar werden. Dadurch wird `Increase shared decision traceability` zum wirkungsrelevanten Bedarf.

Der Need-Kontext enthält bewusst keine Key Results. Ein Bedarf beschreibt, was benötigt wird, nicht wie Erfolg gemessen oder umgesetzt wird. Zielwerte und Messlogik werden später über `Intervention` und `Measure` operationalisiert. Auch die strategische Action `Create shared decision records` wird nicht direkt mit dem Need gleichgesetzt; sie bleibt eine kohärente strategische Handlungsfestlegung, die im nächsten Schritt eine Intervention leiten kann.

## Operationalisierung

Aus Situierung wird Operationalisierung, sobald ein wirkungsrelevanter Bedarf durch eine Intervention adressiert wird.

Die Intervention `Establish shared decision evidence practice` wird als `Action` modelliert. Sie adressiert den wirkungsrelevanten Bedarf `Increase shared decision traceability`, nicht den lediglich sichtbaren Bedarf `Increase traceable decisions`. Damit bleibt die Intervention an den strategisch qualifizierten Bedarf gebunden.

Die strategische Action `Create shared decision records` wird nicht mit der Intervention gleichgesetzt. Sie leitet die Intervention, indem sie die strategische Handlungsfestlegung in eine konkrete Einwirkung übersetzt. Dadurch wird `Strategy --directs--> Intervention` durch `Action @ Strategy --guides--> Action @ Intervention` begründet. Der interventionsbezogene Key Result `70% of relevant decisions are captured as shared decision records` substantiiert den qualifizierten Bedarf `Increase shared decision traceability` und trägt zugleich zum strategischen Key Result `80% of decisions reference shared decision records` bei.

Damit wird `Intervention --addresses--> Need` nicht als bloße Behauptung gelesen: Die Intervention setzt eine konkrete Action an, formuliert einen überprüfbaren Ergebnisbezug und verbindet diesen Ergebnisbezug relational mit dem wirkungsrelevanten Need-Objective.

## Wirkung

Aus Operationalisierung wird Wirkung erst, wenn die veränderte Situation messbar beobachtet und relational in den O2I-Graphen eingeordnet wird.

Im Layered Cake rahmt die Strategie die Messung über `Strategy --frames--> Measure`. Diese Makrorelation wird durch zwei Primitive-Relationen konkretisiert: `Fragmented understanding blocks confident action @ Strategy --indicates--> Shared decision traceability @ Measure` zeigt den relevanten Beobachtungsbereich an; `80% of decisions reference shared decision records @ Strategy --determines--> Shared decision traceability @ Measure` bestimmt dieselbe Messdimension für den strategischen Erfolgsbezug. Innerhalb dieser Messdimension wird `Shared decision traceability rate` als `KPI` modelliert.

Die Intervention setzt den Zielbezug für diese Messung: `70% of relevant decisions are captured as shared decision records @ Intervention --sets-target-for--> Shared decision traceability rate @ Measure`. Zugleich verändert die Intervention die Situation über `Establish shared decision evidence practice @ Intervention --changes--> Information Management @ Situation`. Der KPI misst damit nicht abstrakt Wirkung, sondern beobachtet den Situationsanker, an dem die Intervention eine Veränderung bewirken soll.

Vor dem geplanten und tatsächlichen Beginn der Intervention legt ein Evidenzplan eine Baseline von 40 %, eine absolute Steigerung um mindestens zehn Prozentpunkte als Effektkriterium, mindestens 70 % als Zielkriterium sowie den Zieltermin fest. Damit ist der Wirkungstrace evidenzbereit. Für die ex-post-Bewertung werden der tatsächliche Interventionsbeginn und der Bewertungszeitpunkt gesondert erfasst. Eine dazwischen liegende Folgebeobachtung von 75 % erfüllt beide Kriterien: Sie belegt eine relevante Verbesserung gegenüber der Baseline und einen beobachteten Zielstatus. Beide Aussagen bleiben getrennt prüfbar; aus einer einzelnen Beobachtung folgt nicht der Zeitpunkt erstmaliger Zielerreichung.

Wirkung wird im Layered Cake daher nicht als isoliertes Modellelement behauptet. Sie wird durch die nachvollziehbare Kette von wirkungsrelevantem Bedarf, Intervention, veränderter Situation, strategisch gerahmter Messung und konsistenter Evidenz begründet. Fit bleibt dabei eine Validierungsfrage: Die Relationen von Vision, Strategie, Need, Intervention, Measure und Situation müssen kohärent zusammenpassen, damit eine Messbeobachtung als Evidenz für orientierte Wirkung gelesen werden darf.

# Fazit

O2I beschreibt ein Framework für Wirkungsarchitekturen: Es verbindet standardliteraturbasierte Terminologie und ein semantisch und syntaktisch ausgearbeitetes Metamodell zu einer prüfbaren Denk-, Modellierungs- und Nachweislogik für *orientierte Wirkung*.

> [!tldr] O2I USP
>
> !include`snippetStart="<!-- O2I USP START -->", snippetEnd="<!-- O2I USP END -->"` README.md

\begin{center}
\texttt{\detokenize{Strategy --qualifies--> Need <--surfaces-- Situation}}
\end{center}

O2I folgt damit einer einfachen Grundidee: *panta rhei* - alles fließt. Orientierung, Strategie, Bedarfe, Interventionen und Wirkung bleiben nicht statisch, sondern werden im Wirkungsgraphen fortlaufend nachvollziehbar, überprüfbar und lernfähig verbunden.

# Danksagung

!include ACKNOWLEDGEMENTS.md
