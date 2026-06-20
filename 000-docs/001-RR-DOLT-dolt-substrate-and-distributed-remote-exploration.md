---
title: "Evaluating Dolt as a substrate for governed agentic memory — and a distributed-remote model for multiplayer brains"
status: exploration
date: 2026-06-19
scope: ecosystem-level architecture exploration (no application code)
related:
  - "034-AT-NTRP-ecosystem-thesis (in the flagship repos)"
  - "qmd-team-intent-kb/000-docs/038-AT-DECR (retrieval backend decision)"
---

# Evaluating Dolt as a substrate for governed agentic memory

**Status: exploration / research record.** This is not a committed decision. It records the
question, the fit assessment, and one architectural idea (a distributed-remote model) so the
thinking is durable and reviewable. Nothing here changes the shipped stack.

## 1. The question

The Governed Second Brain stack already *uses* Dolt — indirectly, through Beads (`bd`), whose
task store is a Dolt database synced over `refs/dolt/data`. That raises a sharper question than
"should we adopt Dolt somewhere":

1. **Is Dolt a fit for the brain's *own* durable state** (today: SQLite + an append-only JSONL
   audit log), not just for the task tracker beside it?
2. **Does Dolt solve the "multiplayer" problem** — letting a team share one governed brain —
   *without* breaking the compile-then-govern model?
3. **Is there something worth contributing upstream**, given Dolt's stated direction?

## 2. What Dolt is, and why it's adjacent to this stack

Dolt is **"Git for data"**: a version-controlled SQL database (MySQL-compatible; the
DoltgreSQL variant speaks Postgres) where every write lands in a **commit graph** you can
branch, diff, merge, and time-travel — the same primitives Git gives source, applied to table
rows. It is not a document store bolted onto Git; the versioning is the storage engine.

The relevant part for us is Dolt's current positioning: **"agents need version control."**
Their headline proof point is migrating **Beads** (an agentic-memory / task tool) onto Dolt so
it can serve as the persistence layer for large multi-agent orchestration. The stack in this
umbrella already lives inside that thesis — every `bd` operation here is a Dolt commit. So the
question isn't whether Dolt is credible for agent state; we already depend on it for exactly
that. The question is how far up the stack it should reach.

## 3. Where the brain keeps state today

Recap of the shipped architecture (see the ecosystem thesis doc for the full version):

- **Compile (ICO):** local, per-user. Derives summaries / concepts / contradictions / gaps from
  a corpus and emits a governance spool. Raw and derived stay separate, with provenance.
- **Govern (INTKB):** deterministic dedupe → policy → promotion. Durable state is a local
  SQLite store plus an **append-only JSONL audit log**, hash-chained (`prev_hash` per event).
- **Retrieve (qmd):** on-device search; every hit is a `qmd://` citation.

Two properties matter for this exploration. First, the audit is a **hand-rolled hash chain** —
it is tamper-**evident** (a later reader can detect edits or reordering) but, in local
single-writer mode, **not tamper-proof**: a writer with disk access can edit an event *and*
re-hash the chain forward, and verification passes again. (The external chain-head anchor that
closes the cross-actor gap is tracked separately.) Second, the durable store is **single-writer
and local** — there is no first-class story for two people contributing to one governed brain.

## 4. Fit assessment

**Where Dolt genuinely helps:**

- **The audit substrate.** A Dolt commit graph is a stronger version of what the JSONL
  hash-chain approximates by hand: ordered, content-addressed, diffable history with parentage.
  Much of `audit-chain` / `audit-verify` becomes "read the commit log" instead of bespoke
  hashing code we maintain and must defend.
- **Multi-writer history.** Branch/merge is exactly the shape a shared brain needs (see §5).
- **Operational familiarity.** We already run, sync, and reason about Dolt via beads. Adopting
  it deeper is less novel risk than introducing a new dependency.

**Where Dolt does *not* solve anything:**

- **Retrieval.** Dolt is not a search engine. `qmd` stays the retrieval layer; the retrieval
  backend decision (BM25-now, eval-gated semantic later) is unaffected by anything here.
- **The trust model.** Versioned storage does not, by itself, make the audit tamper-*proof*.
  A local actor with write access still controls their own history. Cross-actor
  non-repudiation still requires an external anchor / signing step. Adopting Dolt **reshapes**
  the integrity story; it does not let us upgrade the honesty wording for free.
- **Compile.** Derivation stays a local, probabilistic step. Dolt changes where results land,
  not how they're produced.

## 5. The distributed-remote reframe (the idea worth recording)

The naive version of "let a team share a brain" is *host one brain behind a server and give
everyone a login*. That breaks the model: compile-then-govern assumes derivation is local and
governance is deterministic at the point of write. A shared mutable server reintroduces exactly
the central-authority, who-wrote-what ambiguity the stack exists to avoid.

The reframe: **don't host the brain — distribute it, the way Git distributes a repo, the way
beads already distributes its task DB.**

- **The brain is a Dolt database, cloned per user.** Everyone has a full local copy.
- **Compile stays local-per-user.** You derive over *your* corpus on *your* machine. No shared
  compute, no egress of raw documents to a server.
- **Govern becomes a merge-gate.** Instead of running dedupe → policy → promotion only at
  capture, the deterministic pipeline runs **at merge time**, when one clone's promoted
  memories are pulled into another. Policy decides what crosses the boundary. This is the
  natural home for tenant isolation and trust levels — they become merge rules, not just
  row attributes.
- **Audit = the Dolt commit graph.** "Who promoted what, in what order, derived from which
  source" is the commit history, shared and verifiable by every clone — a stronger basis for
  cross-actor claims than a single machine's local JSONL chain.
- **Retrieve stays per-clone.** Each user indexes their own copy; every hit is still a
  `qmd://` citation into content they hold.

This mirrors how beads already works (local Dolt, `refs/dolt/data` sync) — so it's not a
hypothetical pattern, it's the pattern the task tracker beside the brain already proves in
production. The "multiplayer brain" becomes *a brain you clone, pull, and merge* — local-first
by construction, with sharing as an explicit pull, never a default exposure.

## 6. What this would replace or strengthen

| Concern today | Under a Dolt substrate |
|---|---|
| Hand-rolled JSONL hash-chain audit | Dolt commit graph (ordered, diffable, parented) |
| External chain-head anchor (open gap) | Commit hashes shared across clones; anchor still signs the head, but the chain is no longer bespoke |
| Single-writer local store | Multi-writer via clone + merge |
| "Shared brain" had no honest design | Merge-gate governance = sharing without a central authority |
| Tenant isolation as a row attribute | Tenant isolation as a merge rule |

It does **not** touch retrieval, does **not** weaken the "tamper-evident, not tamper-proof"
honesty box, and does **not** change the compile step. Forbidden-word discipline from the
README still applies verbatim — this exploration uses *tamper-evident* / *append-only* /
*commit graph*, never *tamper-proof*, *immutable*, *blockchain*, or *non-repudiation* for local
mode.

## 7. Open questions before any adoption

- **Merge semantics.** What is a conflict between two promoted memories, and does the policy
  pipeline resolve it deterministically? This is the crux — get it wrong and merges become a
  manual chore or a silent-overwrite hazard.
- **Performance / footprint.** Dolt's storage and memory profile vs. SQLite for a
  single-user brain that may never need multiplayer. Local-only users shouldn't pay for a
  feature they don't use.
- **Adopt vs. contribute.** Two distinct moves: (a) use Dolt as the brain's store internally;
  (b) contribute the *governance-at-merge* pattern upstream, since it's the layer Dolt's
  "agents need version control" story doesn't itself provide (version control gives history;
  it doesn't give dedupe / policy / promotion / receipts). These can be decided independently.
- **Scope discipline.** None of this is justified until the single-user product is proven and a
  real multiplayer need is logged. Building the distributed substrate before that demand is the
  same premature-optimization trap the retrieval ADR already named.

## 8. Recommendation

Treat this as a **spike, not a migration.** Concretely:

1. Model the brain's durable state on a Dolt database in a throwaway branch; port
   `audit-verify` to read the commit graph; confirm `ico audit verify` semantics still hold.
2. Prototype the **merge-gate**: two clones, a promote on each, a pull that runs the policy
   pipeline at the boundary. Decide whether conflict resolution is deterministic.
3. Only then decide **adopt-internally** and/or **contribute-upstream**, with evidence.

The single-user product ships and stays on its current store until the spike earns the change.
This document exists so the idea — *a governed brain you clone, pull, and merge, with the audit
as the commit graph* — is captured and ready when the multiplayer need is real.
