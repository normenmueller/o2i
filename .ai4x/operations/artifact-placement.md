# Scope

Load before writing or relocating artifacts. Identify purpose, owner, and
lifetime; choose one owning location and reference it elsewhere. Authorship
does not determine placement. Governance retains authority and continuity.

# Audience And Wording

Project documentation outside `.ai4x` is **human-facing**: explain purpose,
context, prerequisites, terminology, and outcomes in connected prose for its
reader. Exclude agent commands, retrieval shorthand, and internal process notes.

`.ai4x` is **agentic-first, agentic-facing, human-approvable** operational memory:
concise contracts, owner/retrieval routes, decision/evidence references, and the
applicable return point. State conditions, actions, evidence, unknowns, and stop
boundaries explicitly; order dependent steps and load detail on demand. Humans
must be able to inspect meaning, scope, and consequences. Exclude chat narratives,
duplicated owning facts, and product documentation. Apply this distinction to
wording and structure as well as location.

# Project Artifacts

| Artifact purpose | Location |
| --- | --- |
| Human documentation, illustration and publication assets | `doc/` |
| Reference metamodel and its review snapshots | `meta/` |
| Executable formalization, contracts, adapters, CLI and their tests | `spec/` |
| Active repository utilities, verification, setup and tool documentation | `utl/<domain>/` |
| Recreated local tool environments and tool-run intermediates | Ignored `utl/<domain>/.local/` |

Keep product content, scripts, dependencies and runtime environments out of
agent memory. Refer to their owning artifact instead of copying it into `.ai4x`.

# Agent Scratch

- Ignore the entire `.ai4x/work/` tree by default.
- `.ai4x/work/local/`: short-lived intermediates; never publish. `ACTIVE.md`
  follows bootstrap; remote-write drafts use `drafts/` under governance.
- `.ai4x/work/remote/`: temporary agent work artifacts that may also be published
  under current subject-bound authority. Stage only explicitly selected files;
  the directory name neither publishes them nor grants authority. Git owns
  branches and remote refs independently of this directory.
- Neither area owns required source, decisions, evidence, or continuation. Move
  required results to their durable owner before reliance or handoff. Startup
  and reproduction must work without scratch; recreate it as needed. Preserve
  unrelated work during cleanup.

Placement and ignore rules never substitute for verification or publication
authority.
