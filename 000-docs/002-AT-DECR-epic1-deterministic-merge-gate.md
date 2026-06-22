# 002-AT-DECR — EPIC 1: the deterministic merge-gate (govern at merge)

**Status:** Accepted and implemented (2026-06-20). Engine code merged to `qmd-team-intent-kb` main.
**Relates to:** [001-RR-DOLT](001-RR-DOLT-dolt-substrate-and-distributed-remote-exploration.md) (the exploration this decides on); the *"compile, then govern"* thesis (`034-AT-NTRP` in the flagship repos).
**Beads:** epic `compile-then-govern-8da`; children `8da.5` / `8da.6` / `8da.9` / `8da.7` / `8da.8` (closed); decision recorded here satisfies `6yv.1` and closes `8da.3` (adopt-vs-contribute).

---

## Context

The thesis: the model proposes; the deterministic system owns durable state and control. The competitive axis is **govern + receipts**, not recall.

`001-RR-DOLT` explored Dolt as a substrate for governed memory and a distributed *clone → pull → merge* model. A throwaway spike then produced the decisive finding: **Dolt's native 3-way merge admits a secret-bearing row with zero governance.** Version control alone is not governance. A post-merge re-derivation pass quarantined exactly that row — so the missing piece is a governance layer *at the merge boundary*, and it composes on top of a version-control substrate rather than replacing it.

The single-user brain runs on **SQLite** (`teamkb.db`, `packages/store`). The question EPIC 1 answered: what does it take to make governance survive a merge — deterministically, reproducibly across clones — **without committing to a distributed substrate prematurely**?

## Decision

Build a **deterministic, substrate-agnostic merge-gate** on the existing SQLite store, in five layers. All are implemented, adversarially verified by an independent skeptic harness, and merged:

1. **Content-derived UUID v5** (`8da.5`, PRs #143/#206) — the same logical memory/event derives the same id in every clone and both engines (locked namespace, byte-identical golden vector).
2. **Deterministic audit hash** (`8da.6`, #206) — the v2 canonical body excludes the wallclock timestamp; v1 rows stay frozen (their hashes are the tamper-evidence); a non-destructive migration lets v1/v2 coexist and verify in one pass.
3. **Govern-at-merge gate** (`8da.9`, #207) — `mergeGovern()` re-derives the **union** of two clones as **untrusted** through the same fail-closed disclosure choke point and full policy pipeline, dedups by content id, and is **commutative** (`A∪B === B∪A`, byte-identical governed state *and* audit chain). A secret that rode in on a clone is **quarantined**, where Dolt-native merge would admit it.
4. **Per-actor Ed25519 signed DAG anchor** (`8da.7`, #208) — records `parents[]` (the two clone heads as an order-independent set), a Lamport clock, the signer's public key, and a detached signature over the merged head.
5. **Merge-aware verifier** (`8da.8`, #208) — validates each clone chain + the re-derived merged chain + the signed anchor, and owns canonical (content-id) ordering as a first-class contract.

## The substrate decision (stated honestly)

- **SQLite is the store of record today.** The merge-gate operates on the store's types, so it is substrate-agnostic — when a substrate move is justified, it is a swap, not a rewrite.
- **Dolt is the adopted *direction*, not a built migration.** The spike proved the governance layer composes on top of Dolt. The `8da.3` decision: **adopt Dolt as the eventual distributed substrate AND keep / contribute upstream the governance-at-merge layer Dolt structurally lacks.**
- **Migrating the brain onto Dolt (`8da.1`) is DEMAND-GATED** — not built until a real multiplayer need is logged (≥2 people blocked on a shared brain, or a real cross-person recall miss). Provisioning a host or a distributed control-plane before that signal is the premature optimization the de-risked plan exists to prevent.
- *"DoltLite"* is a framing term for a **different** artifact (the `freshie` CMDB, in partner-outreach material), **not** the brain's committed substrate. This record does not claim the brain "went with DoltLite" or any built distributed Dolt control-plane.

## Trust boundary (keep it honest in all copy)

The merged chain is now **cross-actor attributable / non-repudiable for the merge case**: a forger without the actor's Ed25519 private key cannot mint an accepted anchor (verified: 20,000 keyless brute-force signatures, 0 accepted; a tamper-then-rehash trips `HISTORY_REWRITTEN` / `DAG_HEAD_MISMATCH`).

It remains **tamper-EVIDENT, not tamper-PROOF**: the legitimate key-holder (or an exfiltrated key) can still edit a row and re-sign a self-consistent anchor. This is mitigated, not eliminated, by key custody (age/SOPS, mode 600, never plaintext) plus an external append-only anchor commit (git push / OpenTimestamps). **Forbidden words:** tamper-proof, immutable, non-repudiation (local mode), blockchain.

## Key custody

Per-actor Ed25519 keypair; the private key is never committed (gitignored / SOPS), the public key is embedded inline in the anchor record. Single-actor merge verification needs no registry; a multi-actor public-key registry is demand-gated alongside `8da.1`.

## Consequences

- **Positive:** governance survives a merge; deterministic and commutative; merges are attributable; the gate reuses every existing governance primitive (no new attack surface) with one new discipline (sort-by-id before the accreting dedup pass); substrate-agnostic.
- **Costs / accepted residuals:** UUID v5 uses SHA-1 per RFC 4122 §4.3 (deterministic namespacing, not a security primitive; the CodeQL `js/weak-cryptographic-algorithm` alert is a dismissed false positive — audit integrity uses SHA-256); disclosure detection inherits its regex/pattern recall ceiling (the gate re-runs the same detectors, so pattern-set expansion is the only lever); `mergeGovern` is 2-arg (N-way via fold, associativity not yet exercised); the locked namespace is vendored in two repos and needs a drift guard. Tracked as open `8da` residual beads.

## Alternatives considered and rejected

- **Rely on Dolt-native merge** — rejected; it admits ungoverned secrets (the spike's decisive finding).
- **Migrate the brain to Dolt now** — rejected; demand-gated, premature before a logged multiplayer need.
- **Make per-event hashes order-independent** — rejected; it breaks the hash chain's purpose. Cross-clone ordering reconciliation belongs in the merge-aware verifier (`8da.8`), not the hash function.

## References

`001-RR-DOLT`; the thesis (`034-AT-NTRP`, flagship repos); PRs `qmd-team-intent-kb#205–#208`, `intentional-cognition-os#143`; epic bead `compile-then-govern-8da`.
