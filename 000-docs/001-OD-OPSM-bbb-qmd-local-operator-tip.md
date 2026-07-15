# 001-OD-OPSM — Local operator tip: qmd home for Bob's Big Brain

**Status:** Active  
**Date:** 2026-07-14

Bob's Big Brain **retrieves with Tobi's qmd** ([tobi/qmd](https://github.com/tobi/qmd), npm `@tobilu/qmd`). We pin and Dependabot-track it; we do **not** fork it.

## Personal vs team index

| | Personal | Team brain |
|--|----------|------------|
| Paths | `~/.config/qmd`, `~/.cache/qmd` | `~/.teamkb/qmd-index/<tenant>/{config,cache}` |
| Typical mistake | `qmd status` shows 0 docs | Team index has thousands of files |

## Commands (from [qmd-team-intent-kb](https://github.com/jeremylongshore/qmd-team-intent-kb))

```bash
pnpm install   # pulls pinned @tobilu/qmd
./scripts/bbb-qmd --which
./scripts/bbb-qmd status
./scripts/bbb-qmd search -- SOPS
pnpm search-canary
pnpm search-canary -- --heal   # reindex from kb-export if degraded
```

Default tenant: `intent-solutions` (`TEAMKB_TENANT_ID`).

Canonical long-form runbook (after merge on INTKB main):  
`000-docs/042-OD-OPSM-bbb-qmd-operator-runbook.md` in that repo.
