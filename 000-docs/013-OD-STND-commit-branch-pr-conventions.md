# 013 · OD · STND — Commit, branch & PR conventions (context-rich, outsider-legible)

| Field | Value |
|---|---|
| **Date** | 2026-07-09 |
| **Applies to** | the Governed Second Brain stack — `intentional-cognition-os` (ICO), `qmd-team-intent-kb` (INTKB), `governed-second-brain-plugin`, and this umbrella |
| **Status** | canonical standard; referenced from each repo's `CONTRIBUTING.md` |
| **Companion** | global workflow rules in `~/.claude/CLAUDE.md` § "Workflow Orchestration" (this doc is the *how-to-write-it* layer + worked examples) |

## The one rule

> **A commit or PR note must let someone who has never seen this repo understand WHAT changed, WHY, where it sits in the architecture, how we know it works, and how to undo it.**

The audit trail is load-bearing. We ship a product whose entire wedge is *receipts* — our own change history has to hold to the same bar. A note that says only "fix bug" or "update code" fails the standard, no matter how green the CI.

---

## 1. The workflow (never merge blind)

1. **Branch from `origin/main`.** Never commit to `main`/`develop` directly. Fetch first — local `main` is often behind (squash + dependabot merges).
2. **Commit only after tests pass** locally (the repo's `test` + `typecheck` + `lint`).
3. **First push opens the PR** — that's what lets CI and the review bot see the diff. This push needs no other justification.
4. **Wait for the gate:** the required CI checks **and** the AI reviewer (see §6). Do not merge on green-CI alone if a review is pending.
5. **Address findings with a *targeted* fix-up push** — each push must answer a specific CI failure or reviewer comment. Never a speculative "made more changes" push.
6. **Merge only when checks are green and review is addressed.** Squash-merge; the squash subject/body is the durable record — write it to this standard.
7. **After merge**, realign your working tree to `main` (`git checkout main && git pull --rebase`) so your checkout matches what's deployed.

Corollary for stateful/live services (e.g. the brain API): a PR that changes runtime behavior of a live service names the deploy step and the rollback in its body (see the AAR's R6 — deploy from a tag, not the working tree).

---

## 2. Branch names

`<type>/<short-kebab-topic>` — optionally `-<bead-or-issue-handle>`.

- `feat/` new capability · `fix/` bug · `refactor/` no-behavior-change · `docs/` · `test/` · `chore/` tooling/deps.
- Good: `feat/e1-hash-on-disk-tokens`, `fix/anchor-fork-false-tamper`, `docs/commit-conventions`.
- Bad: `patch-1`, `jeremy-branch`, `wip`.

---

## 3. Commit messages

```
type(scope): imperative subject, ≤ ~72 chars, no trailing period

WHAT changed — the mechanism, in plain terms.

WHY — the problem it solves and the architectural constraint it serves.
This is the part an outsider can't reconstruct from the diff. Name the
framework rule at stake ("the model proposes; deterministic code owns
durable state") when the change touches it.

HOW verified — the tests/evidence (counts, commands, what you observed).

Refs/closes the bead + issue.
```

- **Types:** `feat`, `fix`, `refactor`, `perf`, `docs`, `test`, `chore`, `build`, `ci`.
- **Scope:** the package/area (`api`, `curator`, `plugin`, `store`, `govern`).
- **Subject** is the headline someone scanning `git log` reads — make it specific ("accept pre-hashed scrypt tokens at rest", not "update auth").
- **Body** wraps at ~72 cols and carries the *why + architecture + verification*. Bullet lists are fine.
- The commit **footer signature is automatic** (`attribution.commit` in settings) — don't hand-add it; never use "Co-Authored-By" or model strings.

### Worked example (real — E1, PR #227)

```
feat(api): accept pre-hashed scrypt tokens at rest (E1 / jfv.5.1)

The InMemoryTokenRegistry unconditionally re-hashed whatever string sat in
a token record's `token` field, so the on-disk ~/.teamkb/tokens.json had to
carry PLAINTEXT bearer secrets — any backup of ~/.teamkb leaked live tokens.

Teach the constructor to detect an already-salted `scrypt$salt$hash` value
(via parseStoredHash) and use it verbatim, so the at-rest form can be the
hash and no plaintext bearer secret ever lands on disk. Plaintext records
still work; a plaintext that merely looks like `scrypt$...` with non-hex
segments fails parseStoredHash and is safely hashed as plaintext.

32/32 registry tests, 288/288 api tests, typecheck clean. Unblocks A2.
Folds 650.6 item 1.
```

Why it passes: the subject is specific; the body explains the *pre-existing risk* (why), the *mechanism* (what), the *fail-safe* (architecture), and the *evidence* (how). A stranger understands the whole change without reading the diff.

---

## 4. PR descriptions

The PR body onboards a reviewer who knows nothing about the task. Use these headings (drop the ones that don't apply):

- **What** — one paragraph: the change in plain terms.
- **Why** — the problem + the **architectural reasoning**. This is where you carry the framework context (see §5). If the change touches the compile→spool→govern→receipts pipeline, say which side of the spool it's on and why that matters.
- **How it works** — the mechanism and the key files/seam. Point at the load-bearing lines.
- **Testing & verification** — what ran (numbers), and *how to reproduce*. For anything with a runtime surface, say what you drove and observed, not just "tests pass."
- **Risk / rollback** — blast radius; how to revert; for live services, the deploy + rollback step.
- **Refs** — `Refs OWNER/REPO#N` while sibling work remains, `Closes …#N` on the PR that retires the last piece; list the **Beads:** covered.

### Worked example (real — E1, PR #227)

> **What** — `InMemoryTokenRegistry` now accepts an already-salted `scrypt$salt$hash` and uses it verbatim, so `~/.teamkb/tokens.json` can store hashes, not plaintext bearer secrets.
> **Why** — the registry hashed *in memory* but re-hashed whatever was on disk, forcing plaintext at rest — every backup of `~/.teamkb` (borg / daily backup / R2) leaked live tokens. This closes the at-rest gap and unblocks minting hashed per-user tokens for all six leaders.
> **Tests** — +4 registry tests (pre-hashed resolves plaintext + rejects wrong/the-hash-itself; mixed pre-hashed+plaintext; tenant/expiry preserved; scrypt-lookalike fail-safe). 32/32 registry, 288/288 api, typecheck clean.
> **Paired operational step** — re-seed `tokens.json` to 6 hashed records, restart, verify (tracked in the issue).
> **Refs #226**

---

## 5. The framework context to carry (GSB-specific)

Outsiders (and future us) need the same one-paragraph map to read any change here. Keep a version of this in the PR when the change touches the pipeline:

> **Architecture in one line:** ICO **compiles** (probabilistic, model-driven) → emits a **spool** (the trust boundary; content-stable UUID-v5 + manifest SHA-256) → INTKB **governs** it with a deterministic 8-rule policy pipeline (dedupe / policy / secret-scan / promotion — *no model call below the spool*) → every promotion writes a SHA-256 **hash-chained receipt**. **The model proposes; deterministic code owns durable state, policy, promotion, and all audit writes.**

Practical consequences for notes:
- A change **above the spool** (compile) is probabilistic — say what the model now proposes and how the deterministic layer still gates it.
- A change **below the spool** (govern/store/audit) is durable-state — say what invariant it preserves (idempotent UUID, tenant isolation, append-only receipts) and how you verified it.
- **Forbidden overclaims** in notes and code: *tamper-proof, immutable, non-repudiation (for local mode), blockchain.* Local mode is integrity + ordering + rewrite-**detection** only. Say "tamper-evident," never "tamper-proof."
- If you touch `candidates`, remember it's **insert-only, source-of-truth** (005-AT-ARCH) — a note that proposes deleting from it must justify against that classification.

---

## 6. The gate: CI checks + the review bot (current reality)

**Deterministic gate = the required CI checks.** Per repo today:
- **ICO / INTKB**: full CI — `lint`, `typecheck`, `test` + coverage (INTKB), `mutation` + CodeQL (ICO), plus `security`/`docs-quality`/`gitleaks`/`semgrep`. Strong.
- **plugin**: `build` + `typecheck` + `smoke` only — **no unit-test / lint job yet** (a gap; see §7).
- **umbrella**: docs-honesty + changelog aggregation (docs repo).

**AI reviewer = Greptile** (the GitHub App; adopted 2026-06-23, replacing CodeRabbit + Gemini). Read its review when present. It is advisory; the *deterministic* gate is the required checks. A stray `gemini-code-assist[bot]`/`coderabbitai[bot]` thread on an old PR is being retired — treat it like any review (address or resolve).

**⚠️ Honest gap:** **branch protection is currently OFF on all four repos** — so "wait for the gate before merging" is a *discipline this standard enforces*, not something GitHub blocks. Until protection is enabled, the human/agent merging is the gate. Tracked in §7.

---

## 7. Known gaps in the gate (tracked)

1. **No branch protection** on any GSB repo → required checks aren't enforced at merge. Enable required-status-checks (+ up-to-date branch) on `main` for ICO/INTKB/plugin.
2. **Plugin CI is thin** — add a `test` + `lint` job so the repo that receives the review's riskiest changes (R4/R8/R9/B1) is actually gated.
3. **Reviewer cleanup** — remove the stale `.gemini` config from INTKB; confirm the Greptile App is installed + reviewing on all three code repos (bot login on the first PR).

These are filed under the remediation epic `compile-then-govern-jfv.6` (see AAR `012-AA-AACR`).

---

## 8. The outsider test (pre-merge checklist)

A note passes if a new engineer, reading only it, can answer:
- [ ] **What** changed (the mechanism)?
- [ ] **Why** — the problem and the architectural constraint it serves?
- [ ] **Where** does it sit in the compile→spool→govern→receipts pipeline?
- [ ] **How** was it verified (evidence, not "tests pass")?
- [ ] **How** do we roll it back?
- [ ] No forbidden overclaims; no bare `fix`/`update` subjects.

If any box is unchecked, the note isn't done — the code might be.
