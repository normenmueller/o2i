# O2I

[![Verify](https://github.com/normenmueller/o2i/actions/workflows/verify.yml/badge.svg)](https://github.com/normenmueller/o2i/actions/workflows/verify.yml)

<details>
<summary><strong>Agentic AI Support:</strong> Hier weiterlesen.</summary>

Die hostneutrale Agent-Memory liegt unter [`.ai4X/`](./.ai4X/). Versionierte Host-Fassaden wie [`AGENTS.md`](./AGENTS.md) und [`.github/agents/o2i.agent.md`](./.github/agents/o2i.agent.md) verweisen auf diesen kanonischen Vertrag. [ai4X](https://github.com/normenmueller/ai4X) unterstützt die Materialisierung und Verwaltung solcher laufzeitspezifischen Integrationen.

Empfohlene Lesereihenfolge: [`.ai4X/BEHAVIOR.md`](./.ai4X/BEHAVIOR.md) → [`.ai4X/CONTEXT.md`](./.ai4X/CONTEXT.md) → [`.ai4X/STATE.md`](./.ai4X/STATE.md) → [`o2i.md`](./o2i.md). Für Formalisierung und Validierung folgt [`spc/`](./spc/), für Modell und konkrete Syntax [`mdl/`](./mdl/).

Für die maschinenlesbare Prüfung von O2I-Modellen dient das Kommando [`o2i`](#command-line); Agenten sollten dessen deterministische JSON-Ausgabe verwenden.

Vor Abschluss einer Änderung prüft `./utl/verify.sh` den vollständigen Repository-Vertrag.

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

Die Library überführt einen ungeprüften O2I-Graphen durch aufeinander aufbauende Validierungsstufen in ein evidenzbewertetes Wirkungsmodell:

```text
RawGraph -> WellFormedGraph -> SemanticallyValidModel -> TraceableEffectModel -> EvidenceReadyModel -> EvidenceAssessedModel
```

Graph bezeichnet als Oberbegriff die Knoten-Kanten-Repräsentation. `RawGraph` ist ihre ungeprüfte, `WellFormedGraph` ihre lokal validierte Form. Ab `SemanticallyValidModel` bezeichnet `Model` die fachlich angereicherte Einheit. Die Modellstufen ergänzen den wohlgeformten Graphen nacheinander um globale fachliche Invarianten, Wirkungstraces, ex-ante Evidenzpläne und ex-post Evidenzbewertungen.

## Command Line

Die formatneutrale Library `O2I.Inspection` führt den gestuften Prüfablauf, Provenienz und Berichterstattung zusammen. `O2I.Adapter.AMX` bindet native Archi-Modelle an diesen Vertrag. Der dünne Client `o2i` prüft genau eine ausgewählte View:

```sh
o2i inspect MODEL (--view NAME | --view-id ID) [--verbose | --debug] [--json]
```

Ein Modell kann als Datei oder über die Standardeingabe geprüft werden. JSON eignet sich für reproduzierbare Automatisierung und agentische Verarbeitung:

```sh
o2i inspect mdl/my.archimate --view "My view"
cat mdl/my.archimate | o2i inspect - --view "My view" --json
```

Der lokale Client wird standardmäßig unter `~/.local/bin/o2i` installiert. `PREFIX` bestimmt ein abweichendes Zielpräfix; `DESTDIR` ermöglicht eine vorgelagerte Paketierungswurzel:

```sh
cd spc
make install
make uninstall
```

## Layout

```text
o2i/
|- acc/
|- img/
|- mdl/
|- spc/
|  |- Makefile
|  |- README.md
|  |- lib/
|  |  |- core/
|  |  |- inspection/
|  |  `- adapter/amx/
|  `- cli/
|- wtf.md
|- o2i.md
|- o2i.pdf
```

- [`wtf.md`](./wtf.md): kurzer, bewusst direkter Einstieg in zentrale O2I-Fragen
- [`o2i.md`](./o2i.md): aktives White Paper und fachlicher Referenztext
- [`o2i.pdf`](./o2i.pdf): bleeding-edge PDF-Fassung des aktiven White Papers
- `acc/`: reproduzierbare TikZ-Quellen der White-Paper-Abbildungen
- `mdl/`: ArchiMate-Modell
- `img/`: Abbildungen für White Paper und Modellkommunikation
- [`spc/README.md`](./spc/README.md): technische Architektur, Build und Nutzung der Haskell-Codebasis
- `spc/lib/core/`: normative Haskell-Library, deren Codeauszüge im White Paper eingebunden werden
- `spc/lib/inspection/`: formatneutrale Inspection-Pipeline und Berichtsmodell
- `spc/lib/adapter/amx/`: Adapter für native Archi Model XML-Dateien
- `spc/cli/`: dünner Kommandozeilen-Client für die Inspection
- `spc/Makefile`: reproduzierbare lokale Installation und Deinstallation des Clients
- `spc/lib/core/tst/`: Haskell-Validierungsbeispiele und Tests

## Build

Das PDF und die TikZ-basierten Abbildungen werden reproduzierbar mit `toPDF.sh` erzeugt. Das Skript rendert zunächst alle Abbildungen aus `acc/` nach `img/` und ruft anschließend [`md2pdf`](https://github.com/normenmueller/md2pdf) auf:

```sh
./toPDF.sh
```

## Verify

Der lokale Prüfvertrag entspricht dem GitHub-Workflow und verändert keine getrackten Arbeitsartefakte:

```sh
./utl/verify.sh
```

## License

The O2I white paper, diagrams, and models are licensed under [CC BY 4.0](./LICENSE).

The Haskell code under [`spc/`](./spc/) is licensed under [Apache-2.0](./spc/LICENSE).

© 2026 [nemron](https://github.com/normenmueller)
