# O2I

O2I ist ein generisches Metamodell für Wirkungsarchitekturen: Es beschreibt, wie Orientierung, Strategie, Bedarf, Ziele, Messung, Umsetzung und Wirkung konsistent modelliert werden können.

Der aktive Artikel ist [`o2i.md`](./o2i.md). Das ArchiMate-Modell liegt unter [`mdl/o2i.archimate`](./mdl/o2i.archimate).

## Purpose

- zentrale Begriffe und Relationen für Wirkungsarchitekturen definieren
- Terminologie, Semantik und ArchiMate-Syntax sauber trennen
- O2I als Metamodell zur Erstellung von Wirkungsarchitekturen definieren, bestehend aus O2I-Primitives, O2I-Kontexten, O2I-Relationen und Wohlgeformtheitsregeln
- ArchiMate als Modellierungssprache für O2I-Modelle verwenden, wobei O2I-Kontexte über O2I-Primitives dargestellt und durch O2I-Relationen zu Wirkungsarchitekturen verbunden werden
- konkrete Instanzen von der generischen Metamodell-Definition getrennt halten

## Layout

```text
o2i/
|- img/
|- mdl/
|- o2i.md
```

- `o2i.md`: aktiver Artikel und fachlicher Referenztext
- `mdl/`: ArchiMate-Modell
- `img/`: Abbildungen für Artikel und Modellkommunikation

## Build

Das PDF wird aus `o2i.md` mit [`md2pdf`](https://github.com/normenmueller/md2pdf) erzeugt:

```sh
md2pdf -o o2i.pdf -- o2i.md
```

## License

See [LICENSE](./LICENSE).
© 2026 [nemron](https://github.com/normenmueller)
