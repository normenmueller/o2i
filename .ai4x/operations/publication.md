# Scope

Load for White Paper, README, WTF, acknowledgements, figures, rendering, or
release text. `../CONTEXT.md` owns product sources; `artifact-placement.md`
owns audience and location.

# Prose

- Write target-state first-publication prose. State what O2I defines.
- Exclude migration, retrospective process, workaround, compatibility, and
  defensive prose unless a conceptual boundary requires explicit contrast.
- Keep the White Paper concise and non-textbook-like. Preserve flow between
  paragraphs, figures, and listings.
- Keep Terminology self-contained and fachlich readable. It defines what a
  term means and where its conceptual boundary lies without requiring prior
  knowledge of metamodel Claims, syntax metadata, Haskell types, or validation
  stages. Metamodel and specification sharpen these definitions; never push
  their implementation vocabulary back into the terminology level.
- Use code listings only for focused explanatory excerpts. Prefer at most half
  a page and enforce a hard maximum of one page per listing; split or replace
  longer code with a precise repository reference.
- Every fachlich material term has a source anchor or explicit authors'
  derivation at the correct semantic level.
- Use established definition callouts and reference every figure and listing
  from the prose.
- Use German umlauts. Otherwise default to ASCII in PDF-relevant Markdown;
  use ASCII `->` or LaTeX `$\to$`, not Unicode arrows.

# Artifact Boundaries

- Keep `doc/misc/wtf.md` concise, informal, and non-normative; keep `README.md`
  a concise project entry with central links.
- `spec/README.md` owns technical architecture, the validation model, build,
  installation, and CLI use; it never competes with fachliche sources.
- `CONTRIBUTING.md` owns contribution workflow, repository navigation,
  White-Paper build, and verification guidance.
- TikZ sources live in `doc/resources/`; generated PNGs live in `doc/images/`.
- ArchiMate exports and model documentation remain synchronized with the
  article and formalization.
- Explain every normative Profile mapping class in the White Paper Syntax
  section: carriers, metadata, relationships, context-sensitive signatures,
  structured patterns. Use concise publication prose and the checked contract
  visualizations required by `modeling.md`; expose neither raw JSON structure
  nor a parallel registry. Views introduce no independent normative source.

# Verification

Apply `local-verification.md` before local execution.

```text
./utl/verification/local.sh paper
./utl/paper/render-paper.sh
(cd doc/paper && pandoc o2i.md --filter pandoc-include -t markdown)
```

Inspect rendered pages, figure legibility, listing length, references, page
breaks, and absence of unsupported Unicode before acceptance. Every local
image reference must resolve to a current nonempty asset; Pandoc replacement
with alternative text is a failed publication build.

In a Git worktree, additionally run `git diff --check`. In an archive or source
tree without Git metadata, omit only that check and record it as unavailable.
