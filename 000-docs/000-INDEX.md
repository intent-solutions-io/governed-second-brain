# 000-docs index — Governed Second Brain (umbrella)

Ecosystem-level documentation for the umbrella / landing repo. Application code, ADRs, and
engine-specific docs live in the flagship repos (ICO, INTKB) and the plugin repo — see the
root `CLAUDE.md` repo map.

| Doc | What it is |
|---|---|
| [001-RR-DOLT-dolt-substrate-and-distributed-remote-exploration.md](001-RR-DOLT-dolt-substrate-and-distributed-remote-exploration.md) | Exploration: Dolt as a substrate for governed agentic memory, and a distributed-remote ("clone, pull, merge") model for a multiplayer brain. Architecture only; not a committed decision. |
| [002-AT-DECR-epic1-deterministic-merge-gate.md](002-AT-DECR-epic1-deterministic-merge-gate.md) | Decision record: EPIC 1's deterministic merge-gate (content-derived ids, deterministic audit hash, govern-at-merge gate, Ed25519 signed DAG anchor, merge-aware verifier). Built and merged on SQLite; Dolt-as-substrate adopted as direction but migration demand-gated. |
| [003-AT-SMAP-merge-gate-system-map.md](003-AT-SMAP-merge-gate-system-map.md) | System map (Mermaid): the single-brain pipeline plus the govern-at-merge path — two clones reconciled by re-deriving the union as untrusted, then signed + verified. SQLite today; Dolt substrate demand-gated. Companion to 002-AT-DECR. |
| [004-MK-CSES-dogfooding-the-governed-second-brain.md](004-MK-CSES-dogfooding-the-governed-second-brain.md) | Case study (**STUB**): we run Compile-Then-Govern on our own corpus — `audit verify` ok (21 events, 0 breaks), governed + hash-chained memories, `qmd://` cited retrieval — and the dogfood caught a real retrieval bug. Public-tier scaffold; prose + demo TODO. |
| [005-AT-ARCH-grounded-system-map-and-backup-scope.md](005-AT-ARCH-grounded-system-map-and-backup-scope.md) | Code-grounded system map: the `~/.teamkb` storage layout, the two-DB model (ICO `state.db` + INTKB `teamkb.db`), the compile→govern→retrieve→attest data flow, source-of-truth-vs-derived classification, the distribution model (public plugin vs private team marketplace), and the correct backup/DR scope. Saved so the repos don't have to be re-explored. |
