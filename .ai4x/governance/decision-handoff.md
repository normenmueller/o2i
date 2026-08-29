# Product Owner Decision Handoff

This contract owns Product Owner-facing event rendering and live approval binding. `policy.json` alone defines the closed event schemas, grant lifecycle, and executable guards. Render labels and prose in the Product Owner's language while preserving schema IDs, `/delete`, `resume`, `Hi Gertrud, weiter geht’s!`, and `Freigegeben.` literally.

<!-- BEGIN GENERATED: ai4x-event-schemas -->
- `authority_request` required fields: `requestId`, `payloadFingerprint`, `subject`, `scope`, `targetState`, `requestedAuthority`, `exclusions`, `reason`, `alternatives`, `coldStart`.
- `product_owner_action` required fields: `eventId`, `subject`, `scope`, `targetState`, `requestedAgentAuthority`, `exclusions`, `reason`, `alternatives`, `coldStart`, `productOwnerAction`.
- `cold_start` required fields: `eventId`, `subject`, `scope`, `targetState`, `requestedAgentAuthority`, `exclusions`, `reason`, `alternatives`, `coldStart`.
<!-- END GENERATED: ai4x-event-schemas -->

Use one event only when a primary Gertrud completes an authorized work unit or hands control back for a Product Owner decision, direct action, or eligible cold start. Interim updates and ordinary answers create no event. Lead with one concise outcome sentence and only useful `Status`, `Evidence`, or `Open` bullets; do not duplicate the recommendation.

## Authority Request

Use `authority_request` only for one bounded agent grant. Generate a unique request ID and the SHA-256 fingerprint of the exact canonical request payload. The recommendation contains one action. Keep every value concise, preserve the field order, and render no extra authority option.

```text
## Decision

Event: `authority_request` — `<request-id>`

Payload: `<sha256>`

Recommendation: **[one concrete next action].**

- Subject: [repository and exact Issue or bounded Routine subject]
- Scope: [allowed action and resource boundary]
- Target state: [observable result]
- Requested agent authority: [exact grant]
- Exclusions: [mandatory boundary]
- Reason: [one evidence-based sentence]

Alternatives: [material alternative or none]

Cold start: not recommended — [safety gate or higher-priority reason]

Approval response: `Freigegeben.`
```

For German, translate `Decision`, `Recommendation`, the six labels, `Alternatives`, `Cold start`, and `Approval response`; use `Antwort zur Freigabe:` for the last label. The exact reply is always the standalone message `Freigegeben.`.

## Direct Product Owner Action

Use `product_owner_action` only when the Product Owner must perform one exact action. It requests no agent authority, contains no approval field or token, and cannot activate a grant.

```text
## Decision

Event: `product_owner_action` — `<event-id>`

Recommendation: **[one exact Product Owner action].**

- Subject: [unambiguous object]
- Scope: [bounded action]
- Target state: [observable result]
- Requested agent authority: none
- Exclusions: [mandatory boundary]
- Reason: [one evidence-based sentence]

Alternatives: [material alternative or none]

Cold start: not recommended — [safety gate or higher-priority reason]

Product Owner action: [self-contained action with subject, scope, target, and authority boundary]
```

## Cold Start

Use `cold_start` only after `continuity.md` establishes every eligibility gate and cold start is the single recommendation. Its metadata is non-imperative, requests no agent authority, and contains neither an approval field nor a Product Owner action. After the metadata, render exactly the three translated numbered actions and end immediately after step 3.

```text
## Decision

Event: `cold_start` — `<event-id>`

Recommendation: **[cold-start transition].**

- Subject: [completed current session]
- Scope: [this repository session only]
- Target state: [fresh repository session]
- Requested agent authority: none
- Exclusions: [transcript retention need, unfinished or delegated work, and every other repository]
- Reason: [one evidence-based eligibility sentence]

Alternatives: none

Cold start: recommended — [all eligibility gates hold]

1. Enter `/delete` and confirm.
2. Start a fresh Codex CLI session without `resume` in this repository root.
3. Say `Hi Gertrud, weiter geht’s!`.
```

## Live Approval Binding

Only `authority_request` accepts approval. Before binding, revalidate that exactly one request immediately precedes the reply, remains open and current, has unchanged facts and matching canonical fingerprint, belongs to this live exchange, and has never been consumed. Reject a wrong, non-adjacent, delayed, superseded, invalidated, reconstructed, already consumed, or wrong-event reply. Chat and session identifiers are never recorded.

On valid approval, emit this non-authorizing receipt before execution:

```text
Approval bound: `<request-id>` — consumed

- Subject: [exact repeated subject]
- Scope: [exact repeated scope]
- Target state: [exact repeated target]
- Exclusions: [exact repeated exclusions]
- Grant: `<grant-id>` — active
```

Consumption applies only to the approval request. The resulting grant remains active through its target unless fulfilled, revoked, superseded, or invalidated. The first authorized remote write must create the immutable complete Issue receipt required by `policy.json`, and same-session readback must verify it before further reliance. If that durable receipt is absent or unverifiable after interruption, no transcript or handoff reconstructs authority.
