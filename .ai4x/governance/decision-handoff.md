# Product Owner Decision Handoff

This contract owns concise Product Owner communication. `policy.json` owns canonical decision records, approval binding, grants and guards. Write in the Product Owner's language; preserve policy IDs and the cold-start literals below.

<!-- BEGIN GENERATED: ai4x-event-schemas -->
- `ordinary-result` → `none`.
- `new-agent-authority-needed` → `authority_request`.
- `direct-product-owner-action-needed` → `product_owner_action`.
- `eligible-cold-start-recommended` → `cold_start`.
<!-- END GENERATED: ai4x-event-schemas -->

## Results And Continuation

Lead with the achieved outcome and practical benefit; add only useful evidence, limitations or open points. Ordinary results, completed work, interim updates and answers require no decision event. Continue authorized unfinished work without requesting permission merely to continue.

End final replies with a plain next-action explanation. Use `Dein nächster Schritt:` in German. Say `Aktuell nichts zu tun.` only when the requested scope is complete or an observed continuation mechanism needs no PO input. When returning control with work remaining, state the stop reason and next bounded action. Never imply background execution without an observed active mechanism.

## Decisions

Select one policy event only for its actual purpose: `authority_request` for a new bounded agent grant, `product_owner_action` for one action the PO must perform, or `cold_start` after eligibility is established. Current explicit PO/runtime authority takes precedence under `BEHAVIOR.md`; do not ask for it again or misrepresent it as a reconstructed durable grant.

Present one reasoned recommendation. Make the subject, allowed action and resource scope, target, material exclusions and any material alternative understandable. The visible recommendation must faithfully express the complete authority requested by its canonical record; include no hidden actions or broader scope. An authority request ends with `Freigabe / Veto?`; do not add a competing response instruction or require the PO to copy a task. A direct PO action requests no agent authority and accepts no grant approval.

Keep canonical payloads, IDs, fingerprints and binding receipts in their policy-owned records, inspectable by the PO without duplicating them in chat. The concise presentation does not replace canonical validation. After valid binding, briefly state that execution begins; do not dump the receipt.

## Approval And Durable Authority

Only `authority_request` binds approval. Apply the policy's closed, case-sensitive reply set and all adjacency, freshness, subject, canonical-payload and single-use checks. Reject ambiguous, stale, reconstructed or reused approvals; neither a status nor a GitHub review grants merge authority. Never record chat or session identifiers.

Approval consumption does not consume its resulting work-unit grant. Before further remote execution, its first authorized remote write must create the complete immutable owning-Issue receipt and pass same-session readback under policy. After interruption, missing or unverifiable durable evidence cannot be repaired with a transcript or handoff. See `continuity.md` for reconstruction.

## Established Cold Start

Use `cold_start` only after every `continuity.md` gate passes and the transition is the single recommendation. It requests no agent authority. Briefly explain the established transition and its verified boundary, without host paths, payloads, digests or snapshot locators. Render these three actions in the PO's language, preserving the literals, and end immediately after step 3:

1. Enter `/delete` and confirm.
2. Start a fresh Codex CLI session without `resume` in this repository root.
3. Say `Hi Gertrud, weiter geht’s!`.
