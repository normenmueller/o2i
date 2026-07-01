# O2I

O2I ist ein generisches Framework für Wirkungsarchitekturen: Es beschreibt, wie Orientierung, Formierung, Situierung, Operationalisierung und Wirkung fachlich begründet, modelliert und nachvollzogen werden können. Das O2I-Metamodell bildet den formalen Kern des Frameworks.

Der aktive Artikel ist [`o2i.md`](./o2i.md). Das ArchiMate-Modell liegt unter [`mdl/o2i.archimate`](./mdl/o2i.archimate).

## Purpose

- O2I als Framework für Wirkungsarchitekturen beschreiben
- zentrale Begriffe und Relationen für Wirkung definieren
- Terminologie, Semantik und ArchiMate-Syntax sauber trennen

## Layout

```text
o2i/
|- img/
|- mdl/
|- spc/
|- o2i.md
```

- `o2i.md`: aktiver Artikel und fachlicher Referenztext
- `mdl/`: ArchiMate-Modell
- `img/`: Abbildungen für Artikel und Modellkommunikation
- `spc/`: normative Haskell-Spezifikation, deren Codeauszüge im Artikel eingebunden werden

## Build

Das PDF wird aus `o2i.md` mit [`md2pdf`](https://github.com/normenmueller/md2pdf) und `pandoc-include` erzeugt:

```sh
md2pdf -- o2i.md
```

## License

O2I article text, diagrams, and models are licensed under [CC BY 4.0](./LICENSE).

The Haskell specification in [`spc/`](./spc/) is licensed under [Apache-2.0](./spc/LICENSE).

© 2026 [nemron](https://github.com/normenmueller)
