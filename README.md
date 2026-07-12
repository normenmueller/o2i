# O2I

O2I ist ein generisches Framework für Wirkungsarchitekturen: Es beschreibt, wie Orientierung, Formierung, Situierung, Operationalisierung und Wirkung fachlich begründet, modelliert und dadurch nachvollzogen werden können. Das O2I-Metamodell bildet den formalen Kern des Frameworks.

Der aktive Artikel ist [`o2i.md`](./o2i.md). Das ArchiMate-Modell liegt unter [`mdl/o2i.archimate`](./mdl/o2i.archimate). Die normative Haskell-Spezifikation liegt als Library unter [`spc/src/lib`](./spc/src/lib/).

## Purpose

O2I dient dazu, *orientierte Wirkung* durch relationale Modellierung nachvollziehbar und durch Messung und Evidenz nachweisbar zu machen. Es verbindet standardliteraturbasierte Terminologie, ein semantisch und syntaktisch ausgearbeitetes Metamodell sowie eine maschinenprüfbare Haskell-Spezifikation.

## USP

- Orientierte Wirkung wird relational nachvollziehbar.
- Kontextrelationen werden durch Primitive-Relationen begründet.
- Strategie wird nicht als Absichtserklärung akzeptiert, sondern durch Handlungsfestlegungen und Erfolgsbezüge prüfbar.
- Bedarfe werden erst wirkungsrelevant, wenn sie situativ sichtbar und strategisch qualifiziert sind.
- Wirkung wird nicht behauptet, sondern über Intervention, Messung und Graph-Nachvollziehbarkeit begründet.

## Layout

```text
o2i/
|- img/
|- mdl/
|- spc/
|  |- src/lib/
|  |- src/app/
|  |- tst/
|- o2i.md
```

- `o2i.md`: aktiver Artikel und fachlicher Referenztext
- `mdl/`: ArchiMate-Modell
- `img/`: Abbildungen für Artikel und Modellkommunikation
- `spc/src/lib/`: normative Haskell-Library, deren Codeauszüge im Artikel eingebunden werden
- `spc/src/app/`: minimaler Einstiegspunkt für spätere Validierungswerkzeuge
- `spc/tst/`: Haskell-Validierungsbeispiele und Tests

## Build

Das PDF wird aus `o2i.md` mit [`md2pdf`](https://github.com/normenmueller/md2pdf) und `pandoc-include` erzeugt:

```sh
md2pdf -- o2i.md
```

## Verify

```sh
cabal --project-dir=spc build all --ghc-options=-Werror
cabal --project-dir=spc test all
hindent --line-length 80 --validate spc/src/lib/O2I.hs spc/src/lib/O2I/*.hs spc/src/app/Main.hs spc/tst/Main.hs
pandoc o2i.md --filter pandoc-include -t markdown
md2pdf -- o2i.md
```

## License

O2I article text, diagrams, and models are licensed under [CC BY 4.0](./LICENSE).

The Haskell specification in [`spc/src/lib`](./spc/src/lib/) is licensed under [Apache-2.0](./spc/LICENSE).

© 2026 [nemron](https://github.com/normenmueller)
