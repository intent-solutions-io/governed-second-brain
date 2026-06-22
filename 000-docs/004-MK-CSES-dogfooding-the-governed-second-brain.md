# Case Study (STUB) — We run the Governed Second Brain on ourselves

> **Status: STUB / scaffold.** This is the skeleton + the captured evidence from the first
> end-to-end dogfood (2026-06-20). It is not the finished public case study — the prose, the
> demo capture, and the pull quotes are still TODO (see §6). Public tier: no internal corpus
> content, no figures, no program details. Flesh out or kill.

---

## 1. The thesis (one line)

Most "AI memory" hands you an answer and asks you to trust it. The Governed Second Brain hands you
an answer **with receipts** — every claim carries a `qmd://` citation, and every write is recorded
in a tamper-evident, SHA-256 hash-chained audit trail. **And we run it on our own company**, so the
claim isn't a pitch — it's a thing we depend on.

## 2. What we proved (real run, real corpus)

We ran the full **Compile-Then-Govern** loop on our own internal operating docs (system map,
internal audits) end-to-end, through the plugin's local mode:

```text
compile (your docs → candidates)  →  govern (dedupe → policy → promote, audited)
        →  index  →  retrieve (cited answers)
```

Evidence captured (the receipts — opaque IDs, no content):

- **Audit integrity:** `audit verify` → `ok:true`, **21 events, 0 hash-chain breaks**.
- **Governed writes:** 6 memories promoted, **hash-chained** (`chainHead c1d79b9…`) and externally
  **anchored** — `audit verify` confirms the chain is consistent with the anchor.
- **Cited retrieval:** real `qmd://` citations returned through the plugin (e.g. a system-map query
  → `qmd://kb-…` at a 0.84 relevance score). Receipts, not recall.

> **TODO:** drop in an asciinema / screen capture of the loop returning a cited answer.

## 3. The part you can't fake — the dogfood caught a real bug

Govern and audit were green, but retrieval came back **empty**. Running the loop on ourselves
surfaced a defect no unit test had caught: a security-hardening change had made the retrieval layer
**fail-closed**, and the local query path wasn't passing the one field that kept it open — so every
local search silently returned nothing. The smoke test had been *printing* zero results and passing
anyway.

We fixed it in one line **and** hardened the smoke so a silent zero-results can never pass again.
That is the whole argument for governed, dogfooded memory: **the discipline that makes it auditable
is the same discipline that makes it honest about its own failures.**

## 4. The product

One plugin, two modes — same tool surface, same `/brain` and `/brain-save` skills:

- **Local** (default, installable today): your own files become cited, governed, audited memory —
  in-process, no daemon, no network, no key. Your personal brain.
- **Team:** the same plugin pointed at your team's single governed brain over a private network —
  read + propose, governed centrally.

> **TODO:** install one-liner + a link to the marketplace listing; the "your brain vs your team's
> brain" framing as the hero.

## 5. Why it matters (audience-dependent — pick one to flesh out)

- **For engineers:** retrieval with citations + a verifiable audit chain you can `audit verify`.
- **For decision-makers:** knowledge that can't silently drift — every change is governed and
  recorded; "show me the receipt" is a real command, not a promise.

## 6. To flesh out before publishing

- [ ] Tighten §1–§3 into publishable prose (kill the bullet scaffolding).
- [ ] Demo capture (asciinema/GIF) of a cited answer + an `audit verify`.
- [ ] Install one-liner + marketplace link (§4).
- [ ] One human pull-quote on the dogfood-caught-bug moment.
- [ ] Decide the venue (startaitools vs the product landing) and the single audience (§5).
- [ ] Cross-link the engine repos (ICO, INTKB) and the unified-plugin decision record.

## 7. Disclosure (what stays OUT of this public artifact)

No internal corpus content (doctrine text, internal specifics), no money/figures, no
program/cohort details. The architecture, the dogfood result, and the bug-found-and-fixed story are
public-safe; the corpus itself is not.

---

*Sources (internal): `intent-os/000-docs/015-AA-AACR-…` (the dogfood AAR), the unification decision
record `intent-os/000-docs/014-AT-DECR-…`. Public references: the engine repos (ICO, INTKB) and the
unified `governed-second-brain` plugin.*
