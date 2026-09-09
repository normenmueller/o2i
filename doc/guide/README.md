# O2I modellieren

Dieser Guide übersetzt fachliche Aussagen in ein prüfbares ArchiMate-Modell.
Wir entwickeln Geschichte und Modell gemeinsam: ein kleiner Schritt, speichern,
prüfen, weiterdenken. Frühere Entscheidungen können wir dabei begründet ändern.

Jeder Abschnitt beantwortet vier Fragen:

1. Welche fachliche Aussage wollen wir ausdrücken?
2. Welche O2I-Begriffe und ArchiMate-Elemente benötigen wir dafür?
3. Welche Properties und Beziehungen setzen wir in Archi?
4. Was prüft die CLI jetzt, und was fehlt im Zwischenstand noch?

## Vorbereitung

Du benötigst Archi und die [O2I CLI](../../spec/README.md#cli-setup).
Die Befehle im Guide setzen `o2i` im Suchpfad voraus und werden aus dem
Repository-Stamm ausgeführt.

Das [Beispielmodell](../model/illustration.archimate) ist eine gemeinsame Quelle
für Anleitung und Prüfungen. Öffne es in Archi zum Nachlesen. Zum eigenen Aufbau
beginne mit einem leeren Archi-Modell und ersetze in den Befehlen den Modellpfad
durch deinen Speicherort.

Jeder Lernschritt erhält eine eigene View mit den jeweils benötigten Elementen
und Beziehungen. Die Anleitung zeigt, wie du sie anlegst und vorhandene
Modellobjekte wiederverwendest. Anschließend prüfst du genau diese View mit der CLI.
Leseskizzen erklären den Zusammenhang; Archi-Exporte zeigen die gespeicherte Darstellung.

Die Views der Orientierung heißen:

- `O2I Illustration - Orientierung`
- `O2I Illustration - Orientierung - Ethos`
- `O2I Illustration - Orientierung - Mission`

PNG-Exporte liegen unter `doc/images/` und heißen exakt wie die jeweilige View,
ergänzt um `.png`. In CLI-Befehlen stehen View-Namen mit Leerzeichen in Anführungszeichen.

## Reihenfolge

Wir beginnen mit [einem Ethos](ethos.md): Respekt, Unabhängigkeit und Disziplin.
Darauf bauen wir die Mission `#hgtt` (*honest good time together*) auf:
„Durch ein aufrichtiges Miteinander eine gute gemeinsame Zeit ermöglichen.“
Die weiteren Schritte wachsen mit dem Beispiel.

Das Szenario ist fiktiv. Seine Aussagen können im Modell verbindlich sein;
Prüfergebnisse belegen dabei keine reale organisatorische Wirkung.

[Zur Dokumentationsübersicht](../README.md)
