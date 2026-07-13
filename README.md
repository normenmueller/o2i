# O2I

O2I ist ein generisches Framework für Wirkungsarchitekturen: Es beschreibt, wie Orientierung, Formierung, Situierung, Operationalisierung und Wirkung fachlich begründet, modelliert und dadurch nachvollzogen werden können. Das O2I-Metamodell bildet den formalen Kern des Frameworks.

Der aktive Artikel ist [`o2i.md`](./o2i.md). Das ArchiMate-Modell liegt unter [`mdl/o2i.archimate`](./mdl/o2i.archimate). Die normative Haskell-Spezifikation liegt als Library unter [`spc/src/lib`](./spc/src/lib/).

Die öffentliche Haskell-API gliedert sich in `O2I.Language` für den semantischen Formvorrat, `O2I.Graph` für konkrete Graphen und `O2I.Validation` für gestufte Prüfungen. `O2I` bildet die kuratierte Gesamtfassade.

```text
RawGraph -> WellFormedGraph -> SemanticallyValidModel -> TraceableEffectModel -> EvidenceAssessedModel
```

## Agentic AI

Die hostneutrale Agent-Memory liegt unter [`.ai4X/`](./.ai4X/). Laufzeitspezifische Host-Adapter werden lokal materialisiert und nicht versioniert, beispielsweise mit [ai4X](https://github.com/normenmueller/ai4X).

Für agentische Arbeit gilt folgende Lesereihenfolge:

1. [`.ai4X/BEHAVIOR.md`](./.ai4X/BEHAVIOR.md) für Verhalten und Arbeitsregeln
2. [`.ai4X/CONTEXT.md`](./.ai4X/CONTEXT.md) für Projektverständnis und fachliche Entscheidungen
3. [`.ai4X/STATE.md`](./.ai4X/STATE.md) für aktuellen Stand und nächste Schritte
4. [`o2i.md`](./o2i.md) als fachliche Referenz
5. [`spc/`](./spc/) für Formalisierung und Validierung
6. [`mdl/`](./mdl/) für Modell und konkrete Syntax

## Purpose

<!-- O2I PURPOSE START -->
O2I dient dazu, *orientierte Wirkung* durch relationale Modellierung nachvollziehbar und durch Messung und Evidenz nachweisbar zu machen. Es verbindet standardliteraturbasierte Terminologie, ein semantisch und syntaktisch ausgearbeitetes Metamodell sowie eine maschinenprüfbare Haskell-Spezifikation.
<!-- O2I PURPOSE END -->

## USP

<!-- O2I USP START -->
- Orientierte Wirkung wird relational nachvollziehbar.
- Kontextrelationen werden durch Primitive-Relationen begründet.
- Strategie wird nicht als Absichtserklärung akzeptiert, sondern durch Handlungsfestlegungen und Erfolgsbezüge prüfbar.
- Bedarfe werden erst wirkungsrelevant, wenn sie situativ sichtbar und strategisch qualifiziert sind.
- Wirkung wird nicht behauptet, sondern über Intervention, Messung und Graph-Nachvollziehbarkeit begründet.
<!-- O2I USP END -->

## Layout

```text
o2i/
|- img/
|- mdl/
|- spc/
|  |- src/lib/
|  |- tst/
|- o2i.md
```

- `o2i.md`: aktiver Artikel und fachlicher Referenztext
- `mdl/`: ArchiMate-Modell
- `img/`: Abbildungen für Artikel und Modellkommunikation
- `spc/src/lib/`: normative Haskell-Library, deren Codeauszüge im Artikel eingebunden werden
- `spc/tst/`: Haskell-Validierungsbeispiele und Tests

## Build

Das PDF wird aus `o2i.md` mit [`md2pdf`](https://github.com/normenmueller/md2pdf) und `pandoc-include` erzeugt:

```sh
md2pdf -- o2i.md
```

## Verify

```sh
cabal --project-dir=spc build all --ghc-options=-Werror
cabal --project-dir=spc test all --ghc-options=-Werror
cabal --project-dir=spc haddock all
hindent --line-length 80 --validate spc/src/lib/O2I.hs spc/src/lib/O2I/*.hs spc/src/lib/O2I/Language/*.hs spc/src/lib/O2I/Graph/*.hs spc/src/lib/O2I/Validation/*.hs spc/tst/Main.hs
pandoc o2i.md --filter pandoc-include -t markdown
md2pdf -- o2i.md
```

## License

O2I article text, diagrams, and models are licensed under [CC BY 4.0](./LICENSE).

The Haskell specification in [`spc/src/lib`](./spc/src/lib/) is licensed under [Apache-2.0](./spc/LICENSE).

© 2026 [nemron](https://github.com/normenmueller)
