# Scope

Load before writing or relocating artifacts. Classify by purpose and owner,
never by whether a human or agent produced them.

# Agent Memory

`.ai4x` is optimized operational memory for AI agents: **agentic-first,
agentic-facing, human-approvable**. Retain concise operating contracts, owner and
retrieval routes, decision/evidence references, and the applicable return point.
Keep conditions, actions, boundaries and unknowns explicit; use the smallest
sufficient representation. A human must be able to inspect what applies and why.
Load detail on demand. Do not retain chat narratives, duplicate owning facts or
turn a handoff into project documentation. Existing governance owns authority,
decisions and continuity; this contract changes none of those owners.

# Audience And Wording

Documentation outside `.ai4x` is **human-facing**. Address the intended human
reader; explain purpose, context, prerequisites and expected outcomes in clear,
connected prose. Explain necessary terminology. Do not write project
documentation as agent commands, retrieval shorthand or internal process notes.

Content inside `.ai4x` is **agentic-first, agentic-facing, human-approvable**.
Use concise, explicit conditions, actions, owning paths, stop boundaries and
evidence requirements. Order instructions when execution order matters; omit
conversational framing and redundant explanation. Human approvability requires
inspectable meaning, scope and consequences, not a second human-facing narrative.
Apply this distinction to wording and structure, not only storage location.

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
- `.ai4x/work/local/`: very short-lived local agent intermediates; never publish.
  The optional `ACTIVE.md` locator follows the bootstrap contract; unpublished
  remote-write drafts use `drafts/` under governance. Neither is a durable owner.
- `.ai4x/work/remote/`: temporary agent work artifacts that may also be published
  under current subject-bound authority. Stage only explicitly selected files;
  the directory name neither publishes them nor grants authority. Git owns
  branches and remote refs independently of this directory.
- Neither area owns required source, decisions, evidence or continuation. Move
  required results to their durable owner before relying on them. Startup and
  reproduction must work with all agent scratch absent; fresh scratch may be
  created as needed. Preserve unrelated work during any cleanup.

# Placement Check

Before writing, identify the artifact's purpose, owner and lifetime. Select one
owning location and reference it elsewhere. Before handoff, ensure no required
information exists only in scratch. Apply existing verification and publication
rules; a path, ignore rule or tool approval never substitutes for authority.
