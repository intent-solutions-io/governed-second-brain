# 005-AT-ARCH — Grounded system map + backup/DR scope

**What this is:** a code-verified map of the Governed Second Brain's live state and data flow, plus the correct backup/DR scope. Derived 2026-06-21 by reading the real engine repos (ICO `intentional-cognition-os`, INTKB `qmd-team-intent-kb`), the plugin, and the live `~/.teamkb` directory — so future sessions don't re-explore from scratch. Every claim cites a real file.

> **One-line orientation:** the entire live brain is **one directory on the dev box (itself a VPS): `~/.teamkb/` (~48–56 MB)**. There are **two** SQLite databases — ICO's `state.db` (compile side) and INTKB's `teamkb.db` (govern side). The production VPS `intentsolutions` holds **no brain** (verified empty).

---

## 1. Storage map — what lives where

| Path | Size | What it is | Schema / code |
|---|---|---|---|
| `~/.teamkb/teamkb.db` | 8.7 MB | **INTKB govern store** (the receipts + the governed memories) | INTKB `packages/store/src/schema.ts` |
| `~/.teamkb/brain/.ico/state.db` | ~2 MB | **ICO kernel** (compile journal: sources, compilations, traces) | ICO `packages/kernel/migrations/` |
| `~/.teamkb/brain/raw/` | ~8 MB (726 f) | **Raw corpus — source of truth** (papers/notes/articles/repos) | ICO `packages/compiler/src/ingest-pipeline.ts` |
| `~/.teamkb/brain/wiki/` | ~15 MB (770 f) | Compiled Markdown (sources/concepts/topics/entities/contradictions/open-questions) | ICO `packages/compiler/src/passes/` |
| `~/.teamkb/brain/audit/` | ~7 MB | ICO append-only hash-chained `traces/` + `provenance/` | ICO kernel audit writer |
| `~/.teamkb/brain/spool/` | ~250 KB | ICO→INTKB handoff (JSONL `MemoryCandidate` + `.manifest.json` SHA-256) | ICO `packages/types/src/spool.ts` |
| `~/.teamkb/kb-export/` | ~8 MB | Curated Markdown tree (derived) | INTKB `apps/git-exporter/src/exporter.ts` |
| `~/.teamkb/qmd-index/` | ~300 KB | BM25/FTS search index (derived) | qmd (upstream) + INTKB `packages/qmd-adapter` |
| `~/.teamkb/tokens.json` | 213 B | **SECRET** — plaintext bearer tokens (jeremy=admin, ope=member) | INTKB auth |
| `~/.teamkb/feedback/` | <1 KB | Policy-eval audit (rejections) | INTKB policy engine |
| `~/.teamkb/backups/` | ~8.5 MB | our own `.age` backups (output of `~/bin/teamkb-backup.sh`) | — |

### teamkb.db tables (INTKB)
- `candidates` (680) — raw pre-governance inbox; insert-only; the immutable record of what was proposed.
- `curated_memories` (680) — **the canonical governed brain**: promoted memories, lifecycle-managed (active/deprecated/superseded/archived), with `policy_evaluations_json` proof.
- `audit_events` (872) — **tamper-evident SHA-256 hash-chain** (`entry_hash` + `prev_entry_hash`, `hash_version` 1/2 per bead 8da.6). The receipts. Non-reproducible.
- `governance_policies` (0), `memory_links` (192, derived), `export_state`/`schema_migrations` (derived), `curated_memories_fts*` (derived FTS, trigger-synced).

### state.db tables (ICO)
- `sources` (raw file registry, dedupe by `(path, hash)`), `compilations` (wiki page audit log + token cost), `compilation_sources`, `mounts`, `promotions`, `tasks`, `recall_results`, `traces` (index into `audit/*.jsonl`).

---

## 2. Data flow (compile → govern → retrieve → attest)

```
raw corpus (brain/raw/)
  → ICO compile: 6 passes (summarize→extract→synthesize→link→contradict→gap)
      writes brain/wiki/*.md + records in .ico/state.db + brain/audit/ hash-chain
  → spool emit: brain/spool/spool-*.jsonl (MemoryCandidate, deterministic UUID-v5, + manifest SHA-256)
  → INTKB ingest: spool → candidates (teamkb.db)
  → INTKB govern: dedupe(content_hash) → PolicyPipeline (secret/length/trust/tenant/relevance/dedup)
      → promote → curated_memories + append audit_events (hash-chained)
  → git-exporter: curated_memories(active) → kb-export/<category>/*.md
  → qmd index: kb-export/ → BM25 index (qmd-index/)
  → brain_search → qmd:// citations (resolve to kb-export/*.md, frontmatter carries contentHash)
  → brain_audit_verify → walk audit_events chain + cross-check git-anchored audit/anchors.jsonl
```

- **"The brain" a teammate queries** = `curated_memories` (via the BM25 index over `kb-export/`). The compiled knowledge = `brain/wiki/`. The raw inputs = `brain/raw/`. The receipts = `audit_events` (INTKB) + `brain/audit/` (ICO).
- **Thesis split:** the model *proposes* (ICO compile passes; opt-in egress) — the deterministic kernel *owns* durable state, governance, and the audit chain. Everything downstream of the spool is replaceable without changing ICO.
- **The plugin** bundles the INTKB packages and runs the govern→retrieve loop as a local **stdio MCP server** (`src/local-server.ts`), tools `brain_search`/`brain_status`/`brain_audit_verify` (read) + `brain_capture`/`brain_govern`/`brain_transition` (write). Daemon-free, zero network.

### Distribution — two channels (don't conflate them)
- **Public plugin** → `jeremylongshore/governed-second-brain-plugin` (personal). The installable artifact for **outsiders**; shipped as npm `governed-second-brain` (SLSA-provenanced), a self-hosted `marketplace.json`, and a listing in the public `claude-code-plugins-plus-skills` catalog.
- **Private team marketplace** → `intent-solutions-io/claude-plugins` (private catalog). The internal **`intent-brain`** plugin (v0.4.0, built from `qmd-team-intent-kb/.claude-plugin/`) is published here; this is how **Jeremy's team** (e.g. Ope) installs and uses the brain. (The recent fix `claude-plugins#1` corrected the `intent-brain` marketplace `source` to object form so it installs on stable Claude Code.)
- Both are local stdio MCP plugins bundling INTKB and talking to a local `~/.teamkb`. The internal brain + team functions stay untouched as a hard constraint; the public plugin is a separate, fresh-built artifact.

---

## 3. Source-of-truth vs derived (the classification that drives backup)

| Bucket | Items |
|---|---|
| **A — MUST back up** (non-reproducible source of truth, ~27 MB) | `teamkb.db` (+`-wal`/`-shm`), `brain/.ico/state.db`, `brain/raw/`, `brain/audit/`, `brain/spool/` |
| **B — SHOULD back up** (expensive to regenerate, ~15 MB) | `brain/wiki/` (re-running Claude compile ≈ $50–200 + hours), `feedback/` |
| **C — SKIP** (cheaply derived/rebuildable) | `kb-export/` (re-run git-exporter), `qmd-index/` (re-run qmd index), `curated_memories_fts*` (trigger-rebuilt), empty `brain/{outputs,recall,tasks}/`, `backups/` (don't back up the backup) |
| **SECRET — handle separately** | `tokens.json` → SOPS/age-encrypt, **exclude from the plaintext set**, rotate if exposed |

Within `teamkb.db`, `candidates` + `curated_memories` + `audit_events` (+ `governance_policies` if populated) are source-of-truth; `memory_links`, `export_state`, `schema_migrations`, FTS are derived (but backing up the whole DB file is simplest and correct).

---

## 4. Backup/DR posture (bead `c5k.4`)

**Current state (incomplete):** `~/bin/teamkb-backup.sh` does a quiesced `VACUUM INTO` of **only `teamkb.db`**, age-encrypts to 2 recipients (dev-box SOPS key + VPS host key), restore-tests on tmpfs, daily systemd user timer (`teamkb-backup.timer`). That captures the governed store + receipts but **misses the entire `brain/` tree** (corpus, wiki, ICO kernel, ICO audit) and `feedback/`. So `c5k.4` is **NOT done**.

**Correct backup:** quiesced `VACUUM INTO` of `teamkb.db` **plus** a tar of the Tier-A/B tree (exclude Tier C + `tokens.json`), then age-encrypt + restore-test + off-host (object storage — R2/B2 — not the production VPS, not the dev box). `tokens.json` goes to SOPS separately.

**Recovery playbook:**
1. Restore Tier A+B (and SOPS-decrypt `tokens.json`).
2. Open `teamkb.db` → `createDatabase()` replays migrations idempotently.
3. Re-run git-exporter → rebuild `kb-export/`; `qmd index rebuild` → rebuild `qmd-index/`.
4. If `brain/wiki/` was lost but `brain/raw/` survived: `ico compile all` (costs API $ + time).
5. Verify: `brain_audit_verify` (INTKB chain + anchors) and `ico audit verify` (ICO chain).

---

## 5. Key references

- INTKB store schema + audit verify: `qmd-team-intent-kb/packages/store/src/{schema.ts,audit-verify.ts}`
- INTKB govern pipeline: `qmd-team-intent-kb/apps/curator/src/{curator.ts,promotion/promoter.ts}`
- INTKB export: `qmd-team-intent-kb/apps/git-exporter/src/exporter.ts`
- ICO kernel migrations + compiler passes + spool: `intentional-cognition-os/packages/{kernel/migrations,compiler/src/passes,types/src/spool.ts}`
- Spool boundary threat model: `qmd-team-intent-kb/000-docs/036-AT-THRT-spool-boundary-threat-model.md`
- Ecosystem thesis: `034-AT-NTRP-ecosystem-thesis.md` (in both flagships)
- Plugin MCP server: `governed-second-brain-plugin/src/local-server.ts`
- Backup script + timer: `~/bin/teamkb-backup.sh`, `~/.config/systemd/user/teamkb-backup.{service,timer}`
