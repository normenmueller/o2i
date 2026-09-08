# Einen Ethos modellieren

Wir beginnen mit der Frage: **Wofür stehen wir?** Unser Beispiel nennt drei
Leitprinzipien: Respekt, Unabhängigkeit und Disziplin.

## 1. Welche fachliche Aussage wollen wir ausdrücken?

Diese drei Prinzipien bilden unseren gemeinsamen Orientierungsrahmen.
Das ist unser [Ethos](../paper/o2i.md#ethos). Die Begriffe geben einen Anfang;
ihre Bedeutung im Alltag konkretisieren wir beim Weiterentwickeln der Geschichte.
Dabei fragen wir: Woran erkennen wir jedes Prinzip in einer Entscheidung?

## 2. Welche O2I-Begriffe und ArchiMate-Elemente benötigen wir?

O2I unterscheidet den Kontext `Ethos` von seinem Inhalt, den `Principle`-Elementen.
In ArchiMate verwenden wir dafür:

| Inhalt | O2I-Typ | ArchiMate-Element |
| --- | --- | --- |
| Ethos | `Ethos` | Grouping |
| Respekt | `Principle` | Principle |
| Unabhängigkeit | `Principle` | Principle |
| Disziplin | `Principle` | Principle |

Je eine gerichtete Composition vom Grouping zu jedem Principle drückt dessen
Zugehörigkeit aus. Sie heißt exakt `contextualizes`.
Die [Kontextualisierungssicht](../../meta/o2i-syntax-contextualization.md) zeigt
dieses allgemeine Muster.

So sieht die View **O2I Illustration - Orientierung - Ethos** im Beispielmodell aus.
Das Grouping steht oben;
die drei Compositions ordnen ihm die Principles zu. Die ausgefüllte Raute
kennzeichnet jeweils die Quellseite am Ethos.

![Ethos mit Respekt, Unabhängigkeit und Disziplin](<../images/O2I Illustration - Orientierung - Ethos.png>)

## 3. Welche Properties und Beziehungen setzen wir in Archi?

Wir bauen eine eigene View **O2I Illustration - Orientierung - Ethos** auf.
Sie zeigt genau diesen Lernschritt.
Falls du das Beispielmodell verwendest, nutze seine bereits vorhandenen Elemente
und Beziehungen erneut: Eine weitere View zeigt dieselben Modellobjekte.

1. **Modell öffnen oder anlegen.** Öffne die `.archimate`-Datei oder wähle
   **File > New > Empty Model**. Markiere den Modellnamen im Modellbaum.
   Öffne **Properties** im Kontextmenü und dort den Reiter **Properties**.
   Füge über **New** die Property `o2i.profile` mit dem Wert
   `o2i.archimate-profile@0.3` hinzu, falls sie noch fehlt.
2. **View anlegen.** Wähle am View-Ordner im Modellbaum
   **New > ArchiMate View**, nenne sie **O2I Illustration - Orientierung - Ethos**
   und öffne sie per Doppelklick.
   Falls diese View bereits existiert, öffne sie.
3. **Elemente platzieren.** Wähle in der Palette **Grouping**, klicke auf die
   Zeichenfläche und nenne das Element **Ethos**. Lege auf dieselbe Weise mit
   **Principle** die Elemente **Respekt**, **Unabhängigkeit** und **Disziplin** an.
   Bereits vorhandene Elemente ziehst du stattdessen aus dem Modellbaum in die
   View; dabei entstehen keine neuen fachlichen Elemente.
4. **Elemente typisieren.** Markiere jedes Element und ergänze im Reiter
   **Properties** die folgenden Schlüssel und Werte jeweils einmal:

   | Element | Schlüssel | Wert |
   | --- | --- | --- |
   | Ethos | `o2i.type` | `Ethos` |
   | Jedes Principle | `o2i.type` | `Principle` |
   | Alle vier Elemente | `o2i.commitment` | `asserted` |

5. **Zugehörigkeit verbinden.** Wähle **Composition** in der Palette, klicke
   zuerst auf das Grouping, danach auf ein Principle. Nenne die Beziehung
   **contextualizes** und setze an ihr `o2i.commitment=asserted`.
   Wiederhole dies für die beiden anderen Principles. Bestehende Beziehungen
   verwendest du erneut; fehlende Darstellungen kannst du aus dem Relations-Ordner
   in die View ziehen. Kontrolliere: drei Compositions, jeweils Ethos als Quelle.
6. **Lesbar anordnen und speichern.** Platziere das Grouping oberhalb der drei
   Principles, sodass alle Beziehungen sichtbar bleiben. Trage an der View als
   Zweck ein: „Zeigt die drei Leitprinzipien unseres fiktiven Ethos und ihre
   Kontextzuordnung.“ Speichere das Modell.

Die Bedienbegriffe folgen dem [Archi-Handbuch](https://www.archimatetool.com/downloads/archi/Archi%20User%20Guide.pdf).
`o2i.type` legt den O2I-Typ fest; `o2i.commitment=asserted` macht die Aussage
innerhalb unseres Beispiels verbindlich. Räumliches Verschachteln ist optional;
die Kontextzuordnung entsteht durch die Composition-Beziehungen.

## 4. Was prüft die CLI jetzt, und was fehlt noch?

Prüfe nach dem Speichern aus dem Repository-Stamm. Beim eigenen Aufbau ersetzt
du den Dateipfad durch deinen Speicherort:

```sh
o2i validate doc/model/illustration.archimate --view "O2I Illustration - Orientierung - Ethos" --level profile
o2i validate doc/model/illustration.archimate --view "O2I Illustration - Orientierung - Ethos" --level structure
o2i validate doc/model/illustration.archimate --view "O2I Illustration - Orientierung - Ethos" --level semantics
```

Für den **hier beschriebenen Ethos-Schritt** erwarten wir dreimal Exit-Code `0`:
gültige Profile-Metadaten, eindeutige Kontextzuordnung und erfüllten Mindestinhalt.
Ein Ethos benötigt mindestens ein eigenes Principle und keine zusätzliche
Relationsevidenz. Unser Beispiel enthält drei.

Die Befehle setzen die gespeicherte View
**O2I Illustration - Orientierung - Ethos** voraus.
Fehlt sie noch, findet die CLI diesen Prüfgegenstand nicht. Fehlendes
`o2i.commitment` scheitert an der Profile-Prüfung; fehlende Kontextualisierung
eines Principle an der Strukturprüfung.

Der Ethos ist damit als erster Baustein prüfbar. Ein vollständiger Wirkungstrace,
ein Evidenzplan und beobachtete Wirkung sind darin noch nicht enthalten.
Auch die konkrete Bedeutung unserer Prinzipien schärfen wir gemeinsam weiter.

[Zum Guide](README.md) · [Regeln zur semantischen Gültigkeit](../paper/o2i.md#semantische-gültigkeit)
