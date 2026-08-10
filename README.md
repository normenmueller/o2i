# O2I

[![Verify](https://github.com/normenmueller/o2i/actions/workflows/verify.yml/badge.svg)](https://github.com/normenmueller/o2i/actions/workflows/verify.yml)

<details>
<summary><strong>Agentic AI Support:</strong> Hier weiterlesen.</summary>

Die hostneutrale Agent-Memory liegt unter [`.ai4x/`](./.ai4x/). Versionierte Host-Fassaden wie [`AGENTS.md`](./AGENTS.md) und [`.github/agents/o2i.agent.md`](./.github/agents/o2i.agent.md) verweisen auf diesen kanonischen Vertrag. [ai4X](https://github.com/normenmueller/ai4X) unterstützt die Materialisierung und Verwaltung solcher laufzeitspezifischen Integrationen.

Empfohlene Lesereihenfolge: [`.ai4x/BEHAVIOR.md`](./.ai4x/BEHAVIOR.md) → [`.ai4x/CONTEXT.md`](./.ai4x/CONTEXT.md) → [`.ai4x/STATE.md`](./.ai4x/STATE.md) → [`o2i.md`](./o2i.md). Für Formalisierung und Validierung folgt [`spc/`](./spc/), für Modell und konkrete Syntax [`mdl/`](./mdl/).

Für die maschinenlesbare Prüfung von O2I-Modellen dient das Kommando [`o2i`](./spc/README.md#inspect); Agenten sollten dessen deterministische JSON-Ausgabe verwenden.

Vor Abschluss einer Änderung prüft `./utl/verify.sh` den vollständigen Repository-Vertrag.

</details>

O2I ist ein generisches Framework für Wirkungsarchitekturen: Es beschreibt, wie Orientierung, Formierung, Situierung, Operationalisierung und Wirkung fachlich begründet, modelliert und dadurch nachvollzogen werden können. Das O2I-Metamodell bildet den formalen Kern des Frameworks.

## Purpose

<!-- O2I PURPOSE START -->
O2I dient dazu, *orientierte Wirkung* durch relationale Modellierung nachvollziehbar und durch Messung und Evidenz nachweisbar zu machen. Es verbindet standardliteraturbasierte Terminologie mit einem semantisch und syntaktisch ausgearbeiteten Metamodell. Die Haskell-Spezifikation formalisiert dieses Metamodell normativ und maschinenprüfbar.
<!-- O2I PURPOSE END -->

## USP

<!-- O2I USP START -->
- Orientierte Wirkung wird relational nachvollziehbar.
- Kontextrelationen werden durch Primitive-Relationen begründet.
- Strategie wird nicht als Absichtserklärung akzeptiert, sondern durch Handlungsfestlegungen und Erfolgsbezüge prüfbar.
- Bedarfe werden erst wirkungsrelevant, wenn sie situativ sichtbar und strategisch qualifiziert sind.
- Wirkung wird nicht behauptet, sondern über Intervention, Messung und Graph-Nachvollziehbarkeit begründet.
<!-- O2I USP END -->

## Start

- **Projektplanung:** [O2I Project](https://github.com/users/normenmueller/projects/4) und [`CONTRIBUTING.md`](./CONTRIBUTING.md)
- **White Paper:** [`o2i.pdf`](./o2i.pdf) als bleeding-edge PDF-Fassung und [`o2i.md`](./o2i.md) als fachlicher Referenztext
- **Direkteinstieg:** [`wtf.md`](./wtf.md) beantwortet zentrale O2I-Fragen kurz und bewusst direkt
- **Spezifikation und CLI:** [`spc/README.md`](./spc/README.md) beschreibt Architektur, Build, Installation und Nutzung

## License

O2I verwendet pfadabhängig [CC BY 4.0 und Apache-2.0](./LICENSING.md). Die Lizenzübersicht und `REUSE.toml` weisen jedem getrackten Inhalt genau eine Lizenz zu.

© 2026 [nemron](https://github.com/normenmueller)
