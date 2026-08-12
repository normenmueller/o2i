# AMX Native Fixture Contract

The fixture corpus is bound exclusively to the native `amx-native-xml/5.0.0-v1` decoder contract. It provides producer-origin positive models and purpose-built native negatives; it owns no O2I Profile or Core semantics.

`manifest.json` binds every tracked fixture by SHA-256 and expected native classification. Positive fixtures additionally bind the complete observation-relevant Profile Draft through a canonical test-only snapshot digest. Focused tests exercise individual Draft rules independently.

Files below `valid/` retain their recorded Archi producer provenance. Files below `invalid/` are deliberately minimized negative inputs and claim no producer provenance.
