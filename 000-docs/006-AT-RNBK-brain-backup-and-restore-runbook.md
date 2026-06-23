# 006-AT-RNBK — Governed-brain backup & restore runbook

Operational companion to [`005-AT-ARCH`](005-AT-ARCH-grounded-system-map-and-backup-scope.md)
(which defines *what* the brain stores and *why* the backup scope is what it is). This doc is
*how* the backup runs and *how to restore it*. Bead `compile-then-govern-c5k.4`.

The whole live brain is one directory on the dev box: `~/.teamkb/` (~48–56 MB). The backup
captures the **source-of-truth + receipts**, not the cheaply-derived views.

## What runs

| | |
|---|---|
| Script | `~/bin/teamkb-backup.sh` (single-user box; not in a repo) |
| Schedule | systemd **user** timer `teamkb-backup.timer` — daily `04:30` (after `borg-backup.timer` at `00:00`), `Persistent=true` |
| Output | `~/.teamkb/backups/teamkb-full-<UTC>.tar.zst.age` (one self-contained encrypted archive) |
| Retain | newest 14 locally (`TEAMKB_BACKUP_RETAIN`) |
| Log | `~/.local/state/teamkb-backup/backup.log` |

borg still runs separately and gives a live whole-`$HOME` hot copy; it is **not** a substitute
for this — borg hot-copies a WAL-mode SQLite file (possibly mid-write) and is not restore-tested
per-brain. This script is the quiesced, restore-tested, brain-scoped path.

## What's in the archive

Captured (per `005-AT-ARCH` scope):

- **Tier A (must-have):** `dbs/teamkb.db` (govern DB, `VACUUM INTO` snapshot) · `dbs/ico-state.db`
  (compile DB, `VACUUM INTO` snapshot) · `brain/raw/` (corpus = source of truth) · `brain/audit/`
  (hash-chained receipts) · `brain/spool/` + `spool/` (ICO→INTKB handoff) · `tokens.json` (secret —
  protected by the archive's age encryption)
- **Tier B (expensive-derived):** `brain/wiki/` (compiled markdown) · `feedback/`
- **`MANIFEST.txt`** — timestamp, table counts, corpus/receipt file counts, component list

Deliberately **skipped** (cheaply re-derived from Tier A): `kb-export/`, `qmd-index/`,
`brain/recall/`, `brain/outputs/`, `brain/tasks/`.

## Encryption & key custody

The archive is `age`-encrypted to **two recipients**, so it restores even if the dev box is lost:

- dev-box SOPS key — `~/.config/sops/age/keys.txt` → recipient `age1me3v…`
- VPS host key — `/etc/intentsolutions/age.key` (root) → recipient `age1csyjr…`

Either private key decrypts any archive. Plaintext is never written to durable disk — the
in-script restore test decrypts only onto `/dev/shm` (tmpfs).

## Acceptance gate (runs every backup)

A backup is **kept only if it provably restores**. After encrypting, the script decrypts +
extracts onto tmpfs and asserts: both DBs `PRAGMA integrity_check = ok` **and** their
`sqlite_master` table counts match the pre-encryption snapshot; `brain/raw/` and `brain/audit/`
restore with the recorded file counts; `tokens.json` is present. Any failure → the archive is
deleted (an unrestorable backup is worse than a missing one) and the run exits non-zero.

## Restore procedure (disaster recovery)

From the encrypted artifact alone (works with either private key):

```bash
ENC=$(/usr/bin/ls -1t ~/.teamkb/backups/teamkb-full-*.tar.zst.age | head -1)   # or the off-host copy
KEY=~/.config/sops/age/keys.txt            # on the VPS: /etc/intentsolutions/age.key

# 1. decrypt + extract to a staging dir
mkdir -p /tmp/teamkb-restore
~/bin/age -d -i "$KEY" -o /tmp/teamkb-restore/b.tar.zst "$ENC"
tar --zstd -xf /tmp/teamkb-restore/b.tar.zst -C /tmp/teamkb-restore
cat /tmp/teamkb-restore/MANIFEST.txt        # sanity: table/file counts

# 2. verify before trusting
sqlite3 /tmp/teamkb-restore/dbs/teamkb.db   'PRAGMA integrity_check;'   # expect: ok
sqlite3 /tmp/teamkb-restore/dbs/ico-state.db 'PRAGMA integrity_check;'  # expect: ok

# 3. stop the live writer, swap the brain into place, restart
systemctl --user stop teamkb-brain-api
mv ~/.teamkb ~/.teamkb.bak-$(date -u +%Y%m%dT%H%M%SZ)
mkdir -p ~/.teamkb/brain/.ico
cp /tmp/teamkb-restore/dbs/teamkb.db        ~/.teamkb/teamkb.db
cp /tmp/teamkb-restore/dbs/ico-state.db     ~/.teamkb/brain/.ico/state.db
cp -a /tmp/teamkb-restore/brain/raw         ~/.teamkb/brain/raw
cp -a /tmp/teamkb-restore/brain/audit       ~/.teamkb/brain/audit
cp -a /tmp/teamkb-restore/brain/spool       ~/.teamkb/brain/spool   2>/dev/null || true
cp -a /tmp/teamkb-restore/spool             ~/.teamkb/spool         2>/dev/null || true
cp -a /tmp/teamkb-restore/brain/wiki        ~/.teamkb/brain/wiki    2>/dev/null || true
cp /tmp/teamkb-restore/tokens.json          ~/.teamkb/tokens.json && chmod 600 ~/.teamkb/tokens.json
systemctl --user start teamkb-brain-api

# 4. prove the receipts chain survived (the whole point of the brand)
#    in qmd-team-intent-kb: curator-cli verify-audit-chain --db ~/.teamkb/teamkb.db
```

The derived dirs (`kb-export/`, `qmd-index/`) are intentionally absent after a restore — rebuild
them from the restored corpus + DBs (re-index / re-export); they were never the source of truth.

## Off-host status (the one remaining piece of c5k.4)

The archive is small (~13 MB) and **encrypted to the VPS key**, so the durable off-host unit is
just that file. Two push targets are wired in the script:

- **Cloudflare R2** via `rclone` — set `TEAMKB_R2_REMOTE` (e.g. `r2:teamkb-backups`) once the
  bucket + credentials exist. **Pending Jeremy's bucket/credential provisioning** — until then the
  run logs `off-host push SKIPPED` and retains the local encrypted copy.
- (alternative, no new creds) push the `.age` to the VPS over the tailnet — the VPS already holds a
  decrypting key.

Until an off-host target is enabled, the backup is restore-tested and encrypted but lives only on
the dev box; that residual single-host risk is the open tail of `c5k.4`.
