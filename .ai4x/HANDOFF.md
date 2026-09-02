# Handoff

<!-- o2i-handoff-envelope-v1 -->
{"schema":"o2i.handoff/v1","workStatus":"ACTIVE","currentIssue":"#105","currentNode":"product-owner-v3-decision"}
<!-- /o2i-handoff-envelope-v1 -->

# Objective

Implement Issue #56 Batch 11 as the atomic O2I CLI and package cutover: expose the accepted command taxonomy over public Operation APIs, construct the validated static AMX adapter collection, register the complete target package graph, and remove Inspection and every legacy registration in one buildable revision.

# Authority

- Active grant: `o2i-56-expanded-workunit-v2`, superseding v1 and bound to payload SHA-256 `b3379e00beb4c9ea82d8b1b22f4a585452a20ccc325424f53980c4083958ad6c`, unchanged #56 body SHA-256 `4cb94bc8256eaa538f05f5c5c8d837e04ce45346657c11551c2297bf081695ae`, and #105 body SHA-256 `c4120cce951e07a0f7f17d5984268467051517caaa81fc7a71a8b518d9f835fb`.
- Durable receipt: Issue #56 comment `5508975383`, unique, authored by verified `gertrud-ai4x`, and byte-identical to staged SHA-256 `8467d8572df1392ea24ae05cf18c297666c6c0fdbfb86d94274993854dac41a0`.
- Pending decision, not authority: Issue #105 comment `5516448281`, authored by verified `gertrud-ai4x`, preserves request `o2i-56-complete-operation-consumer-20260902-v3`, canonical payload SHA-256 `ceeaeb24c8eb2fd984797f63913311cf416da5d315e112f27a91e50710e7f15d`, and exact comment-body SHA-256 `a3a4e8302cee4cfae87d58e3051b7fdd8da1f48a162346fde8037d3dc26f9916`. Grant v3 is not active.
- Target: accepted Operation correction commit preceding a complete accepted and remotely green #56 Pull Request; both Project items `In review`.
- Exclusions: merge, Issue closure, Project `Done`, cleanup, release, tag, protected publication, body mutation, further expansion, Batches 12–13, model, Terminology, Metamodel, Profile, Core, AMX, capability semantics, new commands, and compatibility.

# Current Facts

- Issue #56 is open, assigned to `gertrud-ai4x`, and Project `O2I` status is `In progress`.
- Issue #105 is open, exactly body-bound, assigned to `gertrud-ai4x`, Project `In review`, and verified as an open native blocker of #56.
- Published correction commit `c9a3753fe172ed600d6c929c4ba9ab9bfbed2c39` has parent `9c0a198fd82f1931892d354ebfa314ed6a40610b`, exact patch SHA-256 `4907eeaccbbbc2be11ddef37c0334251fa30d31cfe4bf18cabf315005009342f`, and verified GitHub author/committer `gertrud-ai4x`.
- Issue #105 comment `5510426239` preserves the byte-exact evidence body SHA-256 `9eddacf6c9dbf1cce06793b618c98d50b0b633a1fd1572f7c7bd9b2bf5602103`.
- Published follow-up correction commit `8333cee0f7da76959e871a18b3edbe21b0bf2614` has parent `c9a3753fe172ed600d6c929c4ba9ab9bfbed2c39`, exact patch SHA-256 `c2b84196241cd032da646f0bc13d2448752173cc6fc61dc5fb3a377b079816f9`, and verified GitHub author/committer `gertrud-ai4x`.
- Issue #105 comment `5513231736` preserves the byte-exact follow-up evidence body SHA-256 `05fea7162c80c598e6b7c4f9e795813238ac1dc0ff681fc4bbec66ef4bf3d6af`.
- The root target registration excludes Inspection; all 30 unchanged tracked Inspection files are deleted; deterministic package-graph and legacy-absence verification is added.
- The external Haskell/CLI/API Co-Author replaced `spc/cli/**` with a buildable target-taxonomy intermediate, static AMX composition, scanner, terminal rendering, and focused tests; the author remains excluded from acceptance.
- The second public Operation gap is closed without a CLI workaround: reachable `Validate`, `Qualify`, `Readiness`, and `Assess` pre-result failures now have total typed lifts into the closed command-error document, complete opaque diagnostic projections, and generated exhaustive owner-branch mappings.
- Direct Revision-46 reconciliation exposed a third public Operation consumer gap before any CLI commit: complete human diagnostics require typed Core/Profile occurrence and provenance eliminators that the CLI package may not import, while Operation exposes no complete Operation-owned human-diagnostic projection. The CLI is frozen again; no JSON reconstruction or internal import was admitted.
- The complete read-only consumer audit proves the gap covers the substantive human result as well as diagnostics for `views`, `qualification-subjects`, `validate`, `trace`, `qualify`, `readiness`, and `assess`. A proportional closed design requires shared terminal-neutral value/diagnostic projections plus seven report-specific projections, approximately 23 Operation paths; no Operation edit has begun.
- The Product Owner requires GitHub to be the single operational continuity target: after a prepared handoff, deleting the session and local working copy must still permit exact reconstruction from a fresh checkout plus current owning Issue and Project facts. No iCloud snapshot, transcript, resume, ignored local file, or model recollection may be required.

# Material Risk

- The cutover must be atomic: no temporary package, forwarding facade, compatibility alias, partial package graph, internal import, JSON reconstruction, or knowingly non-building shared revision.
- CLI grammar, output-intent scanning, stdin cardinality, streams, exits, schema-valid JSON, and terminal-safe literals must match accepted revision 46 exactly.
- CLI consumption must use only the published public Operation and AMX boundary now proven across the real capability `ResultDocument` `Left` branches; any internal import, reconstructed JSON, or provenance flattening remains blocking.
- Any expanded correction must preserve all typed result and diagnostic evidence in closed Operation-owned, total, terminal-neutral consumer algebras; it must not introduce a universal value/detail bag or move human policy, verbosity, streams, or terminal escaping into Operation.
- Authors and implementers cannot independently accept the candidate; Haskell/software-architecture and CLI/API/agentic-UX risks require independent read-only review.

# Verification

- The published `8333cee` follow-up is Foundation-green with exit 0: Operation 192/192, contract compiler 51/51, external Operation+AMX consumer and API contracts passed with `-Werror`, and all public Operation modules have 100% Haddock coverage.
- Independent Haskell/type/API/package-architecture and machine-contract/Schema/CLI-consumer re-reviews both accepted exact patch SHA-256 `c2b84196241cd032da646f0bc13d2448752173cc6fc61dc5fb3a377b079816f9` with no blocking finding or advisory follow-up.
- The atomic-cutover verifier passes its 6 focused tests and the current full checkpoint: Inspection and legacy registration are absent, while CLI production dependencies use only Operation and AMX.
- At the full checkpoint, the CLI builds with `-Werror`; API 1/1, CLI 54/54, `cabal check`, atomic cutover, and `git diff --check` pass. Revision-46 reconciliation found the human-result gap outside that matrix; Unicode 16.0 literal coverage and typed command-error routing are corrected locally but remain unaccepted Co-Author changes.
- Full CLI process/golden/schema, complete Haskell, exact freeze, independent review, commit, publication, and remote checks remain pending.

# Next Action

A fresh session re-fetches Issue #105 comment `5516448281`, verifies its author and hashes, renders that exact v3 authority request as the immediately adjacent Product Owner decision, and waits. If the Product Owner replies exactly `Freigegeben.`, v3 replaces v2 and authorizes the complete audited Operation human-consumer layer before CLI work resumes.

# Local Return Point

- Branch: `feat/56-cli-cutover`.
- Fixed handoff path: `.ai4x/HANDOFF.md`, referenced only through the applicable `STATE.md` envelope.
- The branch HEAD containing this handoff is the complete resumable implementation checkpoint, including the deliberately unaccepted CLI intermediate and Inspection removal. A fresh checkout must reproduce a clean tree at that exact revision.
- GitHub branch, Issue, Project, Pull Request, and CI facts are the only required continuity sources. Ignored `.ai4x/local/`, iCloud snapshots, and conversation state are explicitly dispensable.
