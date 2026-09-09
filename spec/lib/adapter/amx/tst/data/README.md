# AMX Native Fixture Contract

The fixture corpus is bound exclusively to the native `amx-native-xml/5.0.0-v1` decoder contract. It provides producer-origin models and purpose-built native positives and negatives; it owns no O2I Profile or Core semantics.

`manifest.json` is the single fixture inventory. It assigns every case a stable ID and binds its bytes by SHA-256 and expected native classification. Positive fixtures additionally bind the complete observation-relevant Profile Draft through a canonical test-only snapshot digest. Focused tests load their inputs by manifest case ID.

Every file records its origin in the manifest. Producer-origin fixtures name the exact producer; hand-minimized fixtures make no producer claim.
