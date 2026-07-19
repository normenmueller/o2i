# O2I

<details>
<summary><strong>Agentic AI Support:</strong> Hier weiterlesen.</summary>

Die hostneutrale Agent-Memory liegt unter [`.ai4X/`](./.ai4X/). Laufzeitspezifische Host-Adapter werden lokal materialisiert und nicht versioniert, beispielsweise mit [ai4X](https://github.com/normenmueller/ai4X).

Empfohlene Lesereihenfolge: [`.ai4X/BEHAVIOR.md`](./.ai4X/BEHAVIOR.md) → [`.ai4X/CONTEXT.md`](./.ai4X/CONTEXT.md) → [`.ai4X/STATE.md`](./.ai4X/STATE.md) → [`o2i.md`](./o2i.md). Für Formalisierung und Validierung folgt [`spc/`](./spc/), für Modell und konkrete Syntax [`mdl/`](./mdl/).

</details>

O2I ist ein generisches Framework für Wirkungsarchitekturen: Es beschreibt, wie Orientierung, Formierung, Situierung, Operationalisierung und Wirkung fachlich begründet, modelliert und dadurch nachvollzogen werden können. Das O2I-Metamodell bildet den formalen Kern des Frameworks.

## Purpose

<!-- O2I PURPOSE START -->
O2I dient dazu, *orientierte Wirkung* durch relationale Modellierung nachvollziehbar und durch Messung und Evidenz nachweisbar zu machen. Es verbindet standardliteraturbasierte Terminologie mit einem semantisch und syntaktisch ausgearbeiteten Metamodell. Dessen normative, maschinenprüfbare Formalisierung bildet die Haskell-Spezifikation.
<!-- O2I PURPOSE END -->

## USP

<!-- O2I USP START -->
- Orientierte Wirkung wird relational nachvollziehbar.
- Kontextrelationen werden durch Primitive-Relationen begründet.
- Strategie wird nicht als Absichtserklärung akzeptiert, sondern durch Handlungsfestlegungen und Erfolgsbezüge prüfbar.
- Bedarfe werden erst wirkungsrelevant, wenn sie situativ sichtbar und strategisch qualifiziert sind.
- Wirkung wird nicht behauptet, sondern über Intervention, Messung und Graph-Nachvollziehbarkeit begründet.
<!-- O2I USP END -->

## Specification

Die Haskell-Spezifikation unter [`spc/lib/core`](./spc/lib/core/) ist die normative, maschinenprüfbare Formalisierung des O2I-Metamodells. Ihre öffentliche API gliedert sich in `O2I.Language` für den semantischen Formvorrat, `O2I.Graph` für konkrete Graphen und `O2I.Validation` für gestufte Prüfungen. `O2I` bildet die kuratierte Gesamtfassade.

Die formatneutrale Library `O2I.Inspection` führt Modellimport, gestufte
Validierung, Provenienz und Berichterstattung zusammen. `O2I.Adapter.AMX`
bindet native Archi-Modelle an diesen Vertrag. Der dünne Client `o2i` stellt
die Inspection für genau eine ausgewählte View bereit:

```sh
o2i inspect MODEL (--view NAME | --view-id ID) [--verbose | --debug] [--json]
```

Die Library überführt einen ungeprüften O2I-Graphen durch aufeinander aufbauende Validierungsstufen in ein evidenzbewertetes Wirkungsmodell:

```text
RawGraph -> WellFormedGraph -> SemanticallyValidModel -> TraceableEffectModel -> EvidenceReadyModel -> EvidenceAssessedModel
```

Graph bezeichnet als Oberbegriff die Knoten-Kanten-Repräsentation. `RawGraph` ist ihre ungeprüfte, `WellFormedGraph` ihre lokal validierte Form. Ab `SemanticallyValidModel` bezeichnet `Model` die fachlich angereicherte Einheit. Die Modellstufen ergänzen den wohlgeformten Graphen nacheinander um globale fachliche Invarianten, Wirkungstraces, ex-ante Evidenzpläne und ex-post Evidenzbewertungen.

## Layout

```text
o2i/
|- img/
|- mdl/
|- spc/
|  |- lib/
|  |  |- core/
|  |  |- inspection/
|  |  `- adapter/amx/
|  `- cli/
|- wtf.md
|- o2i.md
```

- [`wtf.md`](./wtf.md): kurzer, bewusst direkter Einstieg in zentrale O2I-Fragen
- [`o2i.md`](./o2i.md): aktiver Artikel und fachlicher Referenztext
- `mdl/`: ArchiMate-Modell
- `img/`: Abbildungen für Artikel und Modellkommunikation
- `spc/lib/core/`: normative Haskell-Library, deren Codeauszüge im Artikel eingebunden werden
- `spc/lib/inspection/`: formatneutrale Inspection-Pipeline und Berichtsmodell
- `spc/lib/adapter/amx/`: Adapter für native Archi Model XML-Dateien
- `spc/cli/`: dünner Kommandozeilen-Client für die Inspection
- `spc/lib/core/tst/`: Haskell-Validierungsbeispiele und Tests

## Build

Das PDF und die TikZ-basierte Nachweisfolge werden reproduzierbar mit `toPDF.sh` erzeugt. Das Skript rendert zuerst die Grafik nach `img/` und ruft anschließend [`md2pdf`](https://github.com/normenmueller/md2pdf) auf:

```sh
./toPDF.sh
```

## Verify

```sh
python3 -B utl/extract-archimate-view.py --preset all --check
python3 -B -m unittest discover -s utl -p 'test_*.py'
./utl/check-package-licenses.sh
cabal --project-dir=spc build all --ghc-options=-Werror
cabal --project-dir=spc test all --ghc-options=-Werror
cabal --project-dir=spc haddock all
rg --files spc -g '*.hs' | xargs hindent --line-length 80 --validate
pandoc o2i.md --filter pandoc-include -t markdown
./toPDF.sh
```

## License

O2I article text, diagrams, and models are licensed under [CC BY 4.0](./LICENSE).

The Haskell code under [`spc/`](./spc/) is licensed under [Apache-2.0](./spc/LICENSE).

© 2026 [nemron](https://github.com/normenmueller)
