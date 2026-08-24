# Scope

Load for `o2i.md`, README, WTF, acknowledgements, figures, rendering, or release
text.

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

- `o2i.md` owns normative fachliche and metamodel prose.
- `wtf.md` is concise, informal, and non-normative.
- `README.md` owns the concise project entry, Purpose, USP, and central links.
- `spc/README.md` owns technical architecture, the validation model, build,
  installation, and CLI use; it never competes with fachliche sources.
- `CONTRIBUTING.md` owns contribution workflow, repository navigation,
  White-Paper build, and verification guidance.
- TikZ sources live in `acc/`; generated PNGs live in `img/`.
- ArchiMate exports and model documentation remain synchronized with the
  article and formalization.
- The White Paper concrete-syntax section explains every normative mapping
  class projected from `spc/ctr/archimate/profile.json`: carriers,
  metadata, relationship representations, context-sensitive signatures, and
  structured patterns. It explains these mapping classes in concise
  publication prose and checked contract visualizations; it neither exposes
  raw JSON structure nor maintains a parallel generated registry.
- `O2I Syntax - Carriers` and `O2I Syntax - Relations` visualize the carrier- and relation-mapping portions of that contract. Focused checked syntax Views visualize metadata-bearing and non-binary patterns. None is an independent normative source.

# Verification

```text
./utl/verify.sh paper
./toPDF.sh
pandoc o2i.md --filter pandoc-include -t markdown
```

Inspect rendered pages, figure legibility, listing length, references, page
breaks, and absence of unsupported Unicode before acceptance. Every local
image reference must resolve to a current nonempty asset; Pandoc replacement
with alternative text is a failed publication build.

In a Git worktree, additionally run `git diff --check`. In an archive or source
tree without Git metadata, omit only that check and record it as unavailable.
