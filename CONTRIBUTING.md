# Beiträge zu O2I

Öffentliche Beiträge beginnen mit einem GitHub Issue. Das Issue besitzt Problem, Ziel, Scope, Entscheidungen, Abhängigkeiten, Annahmekriterien und Review-Evidenz. Das öffentliche Project [O2I](https://github.com/users/normenmueller/projects/4) zeigt ausschließlich Arbeitsstatus und Product-Owner-Reihenfolge.

<!-- BEGIN GENERATED: ai4x-governance -->
## Generierte Governance-Übersicht

> Automatisch aus `.ai4x/governance/policy.json` erzeugt; diese Projektion ist nicht normativ und wird niemals manuell editiert.

### Arbeitsstatus und Autorität

Das Project zeigt Arbeitsstand und Product-Owner-Reihenfolge. `Ready` bedeutet ausschließlich: Der Issue-Vertrag ist geklärt, Voraussetzungen sind bekannt und kein bekannter Blocker verhindert den nächsten Schritt. Ein Status erzeugt niemals Autorität; beliebig viele Issues dürfen `Ready` sein, ihre vertikale Product-Owner-Reihenfolge bestimmt die Planung.

Erlaubte Übergänge: `Backlog` → `Refinement`; `Refinement` → `Ready`; `Ready` → `In progress`; `In progress` → `In review`; `In progress` → `Paused`; `Paused` → `Ready`; `In review` → `Done`. Jeder nicht aufgeführte Übergang ist verboten.

Eine Mutation benötigt gleichzeitig einen aktuellen Subject-Grant, die ereignisspezifischen Guards, die deklarierte und verifizierte Ausführungsidentität sowie die technische Host- oder Tool-Berechtigung. Fehlt eine Bedingung oder bleibt sie unbekannt, wird nicht ausgeführt. Eine technische Berechtigung erzeugt oder widerruft keine Product-Owner-Autorität.

Ein gebundener Grant bleibt bis zu seinem Zielzustand wirksam; nur die Freigabeantwort wird einmalig verbraucht. Vor einer Session-Grenze muss genau ein vollständiger, unveränderlicher Grant-Beleg im owning Issue aktuell beobachtbar und durch die vorgeschriebene Machine-User-Identität verifizierbar sein.

### Entscheidungsereignisse

`authority_request` fordert genau einen begrenzten Agenten-Grant an und akzeptiert allein die unmittelbar folgende, alleinstehende Antwort `Freigegeben.`. `product_owner_action` fordert genau eine Handlung des Product Owners und erzeugt keinen Grant. `cold_start` verwendet ausschließlich die drei festen Übergangsaktionen und erzeugt ebenfalls keinen Grant. Falsche, nicht angrenzende, überholte, rekonstruierte oder bereits verbrauchte Freigaben werden abgewiesen.

### Provenienz und Grenzen

Product-Owner-Entscheidungsautorität, tatsächliche Inhaltsautorschaft, Erzeuger des Git-Commit-Objekts und verifizierte Remote-Publisher-Identität sind unabhängige Fakten. Eine Freigabe macht den Product Owner niemals automatisch zum Autor, Co-Author, Committer oder Publisher.

Ein gewöhnlicher Work-Unit-Grant bis `In review` umfasst insbesondere nicht: `pull-request.merge`, `issue.close`, `completed-work.cleanup`, `release.publish`, `tag.create`, `protected.publication`, `scope.expand`. Scope- oder Zielerweiterung und das Überschreiten eines Ausschlusses benötigen einen neuen exakten Grant.
<!-- END GENERATED: ai4x-governance -->

## Beitragsweg

Die Änderungsklasse richtet sich nach Wirkung, Reversibilität und Reichweite: `Routine` für lokale semantikerhaltende Arbeit, `Significant` für öffentliche oder capability-übergreifende Verträge und `Protected` für fachliche Bedeutung, normative Syntax, Sicherheit, Publikationsautorität oder Repository-Governance. Der kanonische risikogerechte Vertrag steht in [`.ai4x/governance/guidelines.md`](./.ai4x/governance/guidelines.md); die Issue-Formulare erfassen seine erforderlichen Felder.

Ein ausreichend geklärter Issue beschreibt einen frischen kohärenten Zielzustand und echte Nichtziele. Alte Abstraktionen erhalten weder Migrationsschicht noch Kompatibilitätsalias. Fachliche Bedeutung, Metamodell, konkrete Notation, Formalisierung, Implementierung und Verifikation bleiben in ihren jeweiligen Ownern getrennt.

Wenn spezialisiertes Urteil den Kandidaten materiell prägt, arbeitet ein capability-passender Co-Author bereits an Design und Implementierung mit. Jeder materielle Kandidat erhält die risikogerecht erforderlichen unabhängigen, read-only Reviews. Autoren und Implementierer akzeptieren ihren eigenen Kandidaten niemals unabhängig.

Ein Review nennt exakten Gegenstand und Scope, Reviewer-Fähigkeit, Prüfungen, Findings und genau ein Verdict: `accepted`, `accepted with follow-ups` oder `changes required`. Jedes blockierende Finding enthält eine konkrete SOLL-Lösung. Numerische Review-Scores sind ausgeschlossen.

## Umsetzung

- Änderungen bleiben im exakten Issue- oder Routine-Grant; neue fachliche Ideen erhalten einen eigenen Issue.
- Markdown verwendet eine Quellzeile pro Absatz. Unmittelbar vor jeder manuellen Änderung wird der Zielbereich frisch gelesen, danach werden Änderung und Diff geprüft.
- `mdl/o2i.archimate` wird nie direkt durch Agenten editiert; Modelländerungen erfolgen schrittweise durch den Product Owner.
- Commit-Messages sind kleingeschriebenes Englisch ohne Typpräfix. Issue-Commits führen `Refs #N`; agentische Commits zusätzlich den wahrheitsgetreuen Grant-Trailer.
- Agentische Remote-Aktionen verwenden ausschließlich die verifizierte Identität `gertrud-ai4x`. Technische Berechtigung ersetzt keine Governance-Autorität.
- Release-relevante Änderungen aktualisieren `CHANGELOG.md`.
- Vor Commit laufen mindestens alle durch die Pfadmatrix ausgewählten lokalen Stufen; unbekannte oder gemeinsam genutzte Flächen wählen die vollständige Suite.

## Repository-Struktur

| Pfad | Verantwortung |
| --- | --- |
| `README.md`, `o2i.md`, `wtf.md` | Zweck, White Paper, fachliche Referenz und Einstieg |
| `mdl/` | ArchiMate-Modell, Views und Review-Snapshots |
| `spc/` | formale Haskell-Spezifikation, Profile, Adapter, Operation und CLI |
| `acc/`, `img/` | reproduzierbare Abbildungsquellen und Renderings |
| `.ai4x/` | hostneutraler agentischer Betriebsvertrag |
| `utl/` | deterministische Repository-, Governance-, Modell- und Publikationsprüfungen |

Die technische Haskell-Architektur, Installation und Nutzung beschreibt [`spc/README.md`](./spc/README.md).

## Verifikation und White-Paper-Build

Der vollständige lokale Vertrag lautet:

```sh
./utl/verify.sh
```

Fokussierte Entwicklungsläufe verwenden `licensing`, `governance`, `model`, `foundation`, `haskell` oder `paper`. Die ausführbare Pfadmatrix liegt ausschließlich in `utl/verification/verification_scope.py`; Pull Requests zeigen alle fünf Remote-Checks, wobei nicht betroffene Stufen erfolgreich skippen.

Das White Paper und seine TikZ-Abbildungen werden reproduzierbar erzeugt und versiegelt:

```sh
./toPDF.sh
```
