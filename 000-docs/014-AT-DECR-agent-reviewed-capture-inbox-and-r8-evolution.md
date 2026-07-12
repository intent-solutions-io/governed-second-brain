# 014-AT-DECR — Agent-reviewed capture inbox + the R8 evolution (2026-07-11)

| | |
|---|---|
| **Date** | 2026-07-11 |
| **Author / decider** | Claude (designated by Jeremy Longshore for this session) — single-author record |
| **Process** | Single-author decision record. `/exec-decision-council` was offered and **declined** for this decision (Jeremy, 2026-07-11): the reconciliation is a direct application of an already-ratified canon principle, not a fresh strategic fork. A council remains available if a later reader wants the reconciliation re-adjudicated. |
| **Status** | Ratified — build proceeds under the constraints in §7. |
| **Supersedes / evolves** | **R8** (member-capture intake override → quarantine; see `governed-second-brain#36` remediation epic `jfv.6` and the team-rollout memory). This record *evolves* R8, it does not revoke it. |
| **Input** | The Capture (`jfv.2`) plan (2026-07-11); the frontier principle (memory `frontier-scoping-principle`); the moat framing (this repo's `CLAUDE.md` §"The Architecture Thesis"); `002-AT-DECR` (deterministic merge-gate) as the precedent for "agent proposes / deterministic code owns state". |
| **Tracked by** | `compile-then-govern-jfv.8` (substrate) · `jfv.2` epic (Capture) · GH `governed-second-brain#36` (remediation) / Plane BRAIN. |

## 1. Mission of this record

A durable, for-future-readers record of *why* we let an LLM agent review teammate memory
proposals — in a product whose entire pitch is **"govern by code, not by model; the model never
writes durable state directly."** On its face, "an agent decides what becomes durable team memory"
reads as a violation of that pitch. It is not, **if and only if** it is built exactly the way §3–§7
specify. This record fixes that shape so a later reader cannot quietly soften it into
"the agent promotes memories," which *would* break the moat.

## 2. The problem being solved

The headline of the Capture epic — **auto-govern the remote `brain_capture` inbox nightly**
(`jfv.2.1`, B1) — already shipped and is live. But B1, per R8, **quarantines** every
member-authored capture instead of promoting it, and there is **no shipped surface to review or
approve the quarantined queue**:

- No MCP tool lists or promotes quarantined candidates.
- The promote endpoint (`POST /api/candidates/:id/promote`) exists and works on a quarantined row,
  but nothing surfaces the candidate UUIDs — discovery is manual `sqlite3`.
- The nightly digest lumps a single backlog count and only alerts at a large threshold.

So today a teammate's clean proposal → `inbox` → nightly sweep → **`quarantined`, dead-end, never
re-read, no exit.** It rots *in quarantine* instead of the inbox. (Moot right now — zero teammates
have captured — which is exactly why we build the exit **before** the inbox fills.)

The naive fixes are both wrong:
- **Blind auto-promote** of member captures → abandons R8's review discipline; a member can write
  straight to durable team memory.
- **Human approves each** → does not scale, and Jeremy's explicit call this session is *"the
  review/approval should be done by an agent, not by me approving each and not by a blind
  auto-promote."*

## 3. The decision

We introduce an **agent reviewer** for the quarantined member-capture queue, built on the frontier
principle already in our canon — *"Claude does the judgment; we build the courthouse."* The load-bearing
split:

> **The review agent RECOMMENDS a verdict** (promote / hold / reject + reasoning). **The deterministic
> pipeline OWNS the transition.** `brain_approve` re-runs the deterministic govern rules (dedupe ·
> policy · secret/disclosure scan) as a **hard floor the agent cannot override**, performs the
> promotion through the existing `PromotionService`, and writes a **hash-chained receipt** recording
> the review agent as the actor with its verdict + reasoning.

Concretely:

1. **Two+one admin-only MCP tools** (team mode / HTTP proxy only — the sqlite-free invariant holds):
   `brain_inbox` (list quarantined candidates), `brain_approve` (promote one, through the
   deterministic gate + receipt), and `brain_reject` (a status-flip marker to retire noise — **no
   delete**, per the no-delete design).
2. **A nightly review agent** — a headless Claude phase, modeled on `memory-distiller` — that runs
   under a **dedicated `teamkb-review-agent` admin token** (minted + scrypt-hashed like every other
   team token, so its actions are a **distinct, filterable audited actor** on the chain). It calls
   `brain_inbox`, judges each quarantined member capture, and calls `brain_approve` / `brain_reject`.
3. **The agent is conservative by construction:** it promotes only high-confidence, clearly-useful,
   non-sensitive captures; it **HOLDS** (leaves quarantined) anything ambiguous or borderline for a
   human; it **never** promotes something the deterministic rules would reject (they will not let it
   anyway — see §4).
4. **Human oversight is real, not theoretical:** the nightly govern-quality digest breaks out
   *quarantined-awaiting-review* and lists *the agent's decisions last night* (promoted N / held M /
   rejected K), so a human can spot-check and override.

## 4. Why this does NOT violate the moat

The moat is: *the model proposes; the deterministic system owns durable state and control.* The
agent reviewer keeps that intact — and is **itself the differentiator**: **governed AI judgment with
receipts.** Four properties make it so, and each is a build requirement, not an aspiration:

| Property | What it means | How it is enforced |
|---|---|---|
| **Constrained** | The agent can only promote what the deterministic rules *already pass*. It cannot launder a secret, a policy violation, or a duplicate through its verdict. | `brain_approve` → `POST /api/candidates/:id/promote` → the deterministic promote path **re-runs dedupe · policy · secret/disclosure scan as a hard gate**. The agent's "promote" is a *request*; the pipeline is the *authority*. If the rules reject, the promotion does not happen — the agent's verdict is overridden by code, never the reverse. |
| **Audited** | Every agent decision is a receipt on the hash-chain, filterable by the review-agent actor id. | Promotion writes a hash-chained audit event whose `actor` is `teamkb-review-agent` and whose reason carries the agent's verdict + reasoning. `brain_reject` writes its own marker record. |
| **Reversible** | A bad promotion is retractable. | Jeremy retires any agent promotion via `brain_transition` (active→archived/deprecated) — itself a receipted, deterministic transition. |
| **Human-overseen** | The human sees, in aggregate, every decision the agent made and can intervene. | The nightly digest lists the agent's decisions + the awaiting-review count; the agent HOLDS anything ambiguous rather than promoting it. |

**The key invariant, stated once so it cannot be softened:** *the agent never writes durable state.*
It emits a *recommendation*; the deterministic pipeline performs (or refuses) the write. This is the
same shape as `002-AT-DECR`'s merge-gate ("govern-at-merge is deterministic; the model never owns the
merge") — we are extending an established pattern, not inventing a risky new one.

## 5. The R8 evolution (precisely what changes)

R8 established: member-authored captures land **untrusted → reviewed**, and **promotion of a member
capture requires a human admin's sign-off** (member proposes, admin disposes). This record **does not
revoke R8's intake override** — member captures still land quarantined, still never auto-promote, the
deterministic gate is unchanged. What changes is *who performs the first-pass review*:

> **Before:** the admin (human) personally reviews and signs off each quarantined member capture.
> **After:** the admin **delegates the first-pass review to *their own* agent**, running under a
> distinct audited token, and **oversees it in aggregate** (the daily digest of every agent decision,
> with per-item override via `brain_transition`).

This is a delegation *by the admin, of the admin's own review labor, to the admin's own agent* — not
a new actor class with independent authority. The agent's authority is exactly the admin's *and no
more*, minus the ability to override the deterministic gate (which no actor has). The trust boundary
is unchanged: **code owns the durable write; the human owns the code and the oversight.**

## 6. Alternatives considered and rejected

| Alternative | Why rejected |
|---|---|
| **Blind auto-promote member captures** | Abandons R8 entirely; a member (or a compromised member token) writes straight to durable team memory. The whole govern layer becomes decorative. |
| **Human approves each** | Does not scale past a handful of captures; Jeremy explicitly declined it this session. The inbox rots the moment attention lapses. |
| **Agent writes durable memory directly** (agent owns the transition) | *This* is the moat violation. Rejected outright — the agent recommends, the deterministic pipeline owns the write. Non-negotiable. |
| **Give the agent a bypass for "obviously fine" items** | A bypass is exactly the laundering vector the deterministic gate exists to close. No bypass — every promotion re-runs the full gate, agent-initiated or not. |
| **Approve-surface in local mode (direct sqlite)** | Violates the team-mode sqlite-free invariant and splits the promote path. The admin surface is HTTP-proxy-only against the governed API, which owns the gate + receipt. |

## 7. Binding constraints on the build (carry these forward)

1. **`brain_approve` MUST re-run the deterministic govern rules as a hard floor.** The promotion path
   is the authority; the agent's verdict never bypasses dedupe/policy/secret-scan. If the current
   promote path does not already re-gate secrets/policy on promotion, adding that gating is a
   **prerequisite** of shipping `brain_approve` — not a follow-up.
2. **Every agent decision is a receipt.** Promote and reject both write an on-chain record naming
   `teamkb-review-agent` as actor, carrying the verdict + reasoning. A silent promotion is a bug.
3. **The review agent runs under a dedicated `teamkb-review-agent` admin token** — minted + hashed
   like the others — so its actions are distinct and filterable, never indistinguishable from a human
   admin's.
4. **The agent HOLDS on doubt.** Ambiguous, borderline, or possibly-sensitive → leave quarantined for
   a human. Promotion is reserved for high-confidence, clearly-useful, non-sensitive captures.
5. **No delete.** `brain_reject` is a status-flip marker (per the no-delete design); rejected noise is
   retained, not destroyed.
6. **Human oversight ships with it.** The digest surfaces the awaiting-review count *and* the agent's
   last-night decisions. The oversight surface lands in the same pass as the agent — not "later."
7. **Never silently re-hash the audit chain** (carried from `009-AT-DECR` D5 / memory
   `gsb-audit-chain-never-rehash-155-breaks`). Nothing in this feature edits or re-hashes existing
   audit events.

**Forbidden framings** (would misdescribe the design and break the moat if they leaked into public
copy): "the agent promotes memories," "AI-approved memory," "the agent decides what's remembered."
The honest framing is: **"an agent reviews proposals and recommends; deterministic code governs the
promotion and receipts every decision."**

## 8. Verification (how a reader confirms this was built as decided)

- `brain_approve` on a quarantined row carrying a secret → **rejected by the deterministic gate**, not
  promoted (the agent cannot launder it).
- A clean promotion → a hash-chained audit receipt whose actor is `teamkb-review-agent` and whose
  reason carries the agent's verdict; `brain_audit_verify` stays green.
- The review agent, on a seeded set {clean, borderline, secret-bearing}, produces
  {promoted, held-in-quarantine, rejected-by-the-rules} respectively.
- The nightly digest shows last-night agent decisions + the quarantined-awaiting-review count.
- Any agent promotion is retractable by a human via `brain_transition`.

*This record is the gate for the Capture (`jfv.2`) build: no durable-state code lands until it is
ratified. Ratified 2026-07-11.*

---
- Jeremy Longshore
intentsolutions.io
