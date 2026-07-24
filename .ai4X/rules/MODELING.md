# Scope

Load for `mdl/o2i.archimate`, semantic Views, concrete syntax, snapshots, or
instance-conformance work.

# Semantic And Syntax Discipline

- Treat ArchiMate as notation, never as the source of O2I semantics.
- Semantic Views visualize the metamodel. Syntax Views define its concrete
  ArchiMate mapping and introduce no independent fachliche semantics.
- Keep unannotated mapping Views distinct from executable Candidate conformance
  Views. Never reuse one persisted element across those levels.
- Contextualization is only
  `Context --composition[contextualizes]--> element`; visual nesting is
  presentational.
- Mapping-only Views are repository snapshot contracts, not O2I graphs.
- Executable conformance and instance Views require Haskell `o2i inspect`.

# Model Editing

- Never edit `mdl/o2i.archimate` directly.
- Guide the user through one small Archi change at a time.
- After every saved model change:
  1. read the model freshly;
  2. regenerate all snapshots;
  3. run repository View-contract and snapshot checks;
  4. run Python extractor tests;
  5. run Haskell inspection for every affected executable View;
  6. inspect affected PNG exports when available.

# Tool Responsibilities

- Python checks only named repository Views, labels, documentation, displayed
  relation signatures, and snapshots.
- AMX validates concrete O2I profile metadata and projects selected Views.
- Core/Inspection validates notation-independent O2I structure and semantics.

# Commands

```text
python3 -B utl/extract-archimate-view.py --preset all
python3 -B utl/extract-archimate-view.py --preset all --check
python3 -B -m unittest discover -s utl -p 'test_*.py'
cabal --project-dir=spc run o2i -- inspect MODEL --view "VIEW"
```
