# 003-AT-SMAP — System map: the brain, and govern-at-merge

**Companion to** [002-AT-DECR](002-AT-DECR-epic1-deterministic-merge-gate.md) (the decision) and the README's high-level stack diagram. This map adds the layer the landing diagram deliberately leaves out: what happens when **two clones of a brain reconcile**.

The single-brain pipeline (compile → govern → retrieve, on SQLite) is unchanged. The new half is the **govern-at-merge** path: a merge does not trust either clone — it re-derives the *union* of their promoted rows through the same governance gate, so a secret that rode in on one clone is **quarantined**, not admitted, and the merge is signed and independently verifiable.

```mermaid
%%{init: {'theme':'base','themeVariables':{
  'primaryColor':'#0ea5e9','primaryBorderColor':'#0284c7','primaryTextColor':'#ffffff',
  'lineColor':'#38bdf8','clusterBkg':'#0c192910','clusterBorder':'#0ea5e9'}}}%%
flowchart TB
    subgraph BRAIN["Single brain — store of record (today)"]
        direction LR
        SRC["Raw corpus"] --> ICO["ICO compile<br/>6 passes · derive"]
        ICO -->|spool| GOV["INTKB govern<br/>dedupe → policy → promote"]
        GOV --> STORE[("SQLite store<br/>SHA-256 hash-chained audit")]
        STORE --> QMD["qmd retrieve<br/>cited qmd://"]
    end

    subgraph MERGE["Govern-at-merge — two clones reconcile"]
        direction TB
        CA[("Clone A")] --> UNION{{"Union of promoted rows"}}
        CB[("Clone B<br/>may carry a secret")] --> UNION
        UNION --> GATE["Govern-at-merge gate<br/>re-derive union as UNTRUSTED<br/>dedupe by content-id → disclosure scan → policy"]
        GATE -->|fails gate| QUAR["Quarantined<br/>secret never admitted"]
        GATE -->|survivors| MSTORE[("Merged governed state<br/>commutative A∪B = B∪A")]
        MSTORE --> ANCHOR["Ed25519 signed DAG anchor<br/>parents = clone heads · per-actor"]
        ANCHOR --> VERIFY["Merge-aware verifier<br/>per-clone + merged + signature"]
    end

    STORE -. "content-derived ids + deterministic v2 hash" .-> CA

    subgraph SUB["Substrate"]
        direction LR
        S1["SQLite<br/>store of record today"] -. "swap when justified" .-> S2["Dolt<br/>distributed substrate<br/>direction; migration DEMAND-GATED"]
    end
```

## How to read it

- **Single brain (top).** The pipeline from the README, on the **SQLite** store of record. Two new invariants from EPIC 1 feed the merge path (the dashed link): every row carries a **content-derived id** (same memory → same id in any clone) and the audit hash is **wallclock-deterministic** (same event → same hash anywhere).
- **Govern-at-merge (middle).** Reconciling two clones is *not* a database 3-way merge — it is a re-derivation of the **union** as **untrusted**: dedupe by content-id, then the same fail-closed disclosure scan and policy pipeline the front door uses. Failures are **quarantined**; survivors form a **commutative** merged state (`A∪B = B∪A`, byte-identical). The merged head is **Ed25519-signed** (DAG parents = the two clone heads) and checked by a **merge-aware verifier**.
- **Substrate (bottom).** Everything above runs on **SQLite today** and is substrate-agnostic. **Dolt** is the adopted *direction* for a distributed substrate, but the migration is **demand-gated** — not built until a real multiplayer need is logged. There is no distributed Dolt control-plane in production.

## Trust boundary

Cross-actor **attributable** for the merge case (a keyless forger cannot mint an accepted anchor), but still **tamper-evident, not tamper-proof** — the legitimate key-holder can re-sign. Mitigated by key custody (age/SOPS) + an external append-only anchor. See the trust-model box in [002-AT-DECR](002-AT-DECR-epic1-deterministic-merge-gate.md) and the README.
