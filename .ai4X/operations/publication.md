# Scope

Load for `o2i.md`, README, WTF, acknowledgements, figures, rendering, or release
text.

# Prose

- Write target-state first-publication prose. State what O2I defines.
- Exclude migration, retrospective process, workaround, compatibility, and
  defensive prose unless a conceptual boundary requires explicit contrast.
- Keep the White Paper concise and non-textbook-like. Preserve flow between
  paragraphs, figures, and listings.
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
- `spc/README.md` is technical and never a competing fachliche source.
- TikZ sources live in `acc/`; generated PNGs live in `img/`.
- ArchiMate exports and model documentation remain synchronized with the
  article and formalization.
- The White Paper concrete-syntax section explains every normative mapping
  class projected from `spc/ctr/archimate/profile.json`: carriers,
  metadata, relationship representations, context-sensitive signatures, and
  structured patterns. The generated fragment remains readable publication
  prose; it never exposes raw JSON structure.
- `O2I Syntax` visualizes that contract. It is not an independent normative
  source.

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
