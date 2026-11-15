# Replace a Hetzner recovery snapshot

Read [ownership](../ownership-matrix.md) and [security](../../SECURITY.md) first.
This procedure creates a recovery backup without stopping applications or
changing their configuration. It is a file/data backup, not a bootable disk image.

## Existing backup contract

The original Hetzner job is `/usr/local/bin/vps-backup.sh`, installed from
`30-backup.yml`. It uses root-only `/etc/restic/env`, restic and Backblaze B2.
The deployed legacy job runs daily at 02:00 UTC with tag `vps-prod`, backing up
`/opt/maxtg-bridge/data`, `/opt/openclaw/workspace` and
`/opt/obsidian-vault/wiki`. Its retention is seven daily, four weekly and
three monthly snapshots. This legacy scope does not cover all current apps.

The manual refresh is separate from that timer. It includes the active Hetzner
projects (`maxtg-bridge`, `fluentloop-bot`, `ghostroute-console`, `stealth`),
their container mounts, retained workspace/wiki, host `/etc`, local management
scripts, monitor state and the SSH user's access/configuration directories.
Credentials and application configuration belong only in the encrypted backup.
Container inspection, package inventory and image references support recovery;
Docker image layers, the OS disk and provider settings are not included.
Hermes and its pending backup-scope deployment are outside this procedure.

## Create and verify before deleting

1. Query snapshots read-only through the SSH helper, loading `/etc/restic/env`
   inside a root shell. Save raw metadata only in ignored private reports.
   Record the full ID of the exact snapshot being replaced. Never infer that
   "old" means every historical snapshot or every repository in the bucket.
2. Review the source paths, mounted volumes, available disk space and
   `restic backup --dry-run`. Confirm that no backup/prune is already running.
3. Create a private staging tree under `/var/backups/vps-management/refresh-<UTC>`.
   Copy selected inputs into `root/` preserving their original hierarchy and
   metadata. Exclude live SQLite WAL/SHM files. Modify only this staging tree.
4. Replace staged copies of the five live SQLite databases using the SQLite
   backup API from read-only source connections: bridge, MAX session,
   Fluentloop, Console and routing Xray database. Run `PRAGMA integrity_check`
   on each closed copy. Fail the refresh if any active database fails.
   Historical application rollback DBs remain byte-for-byte archives; do not
   claim they passed the live database tests. An unreadable historical MAX
   session backup was found during the November refresh and retained as-is.
5. Write a manifest of relative paths, sizes and SHA-256 hashes, plus the live
   database check list. Backup the staged tree with explicit host alias and
   tags `vps-hetzner-prod` and `manual-refresh-<date>`. Do not invoke the legacy
   job here: it also performs retention before the Mac restore test.
6. Run cloud `restic check --read-data`. Create an independent encrypted restic
   repository on the Mac, outside Git and sync folders, under
   `~/vps-backups/hetzner/<date>/restic`. Use credentials from Vault in process
   memory/environment; keep passwords out of command arguments and files.
   Initialize with `--copy-chunker-params`, then `restic copy` the exact new
   snapshot using the cloud repository as `RESTIC_FROM_REPOSITORY`.
7. Run local `restic check --read-data`, restore the copied snapshot into a
   private temporary directory with `--verify`, compare every manifest entry
   by size and SHA-256, and repeat live SQLite integrity checks. Keep a local
   verification receipt alongside the encrypted repository.
8. Only after all checks pass, review `restic forget <old-full-id> --dry-run`,
   verify that it selects precisely the recorded old snapshot, then forget
   that ID and prune unreferenced data. Never delete B2 pack objects directly.
   Re-list snapshots and confirm the new one remains and other old IDs survive.
9. Compare persistent container image/start/restart values before and after;
   run the host verification gate. Delete only this task's remote staging tree
   and decrypted Mac restore-test tree. Keep the encrypted Mac repository and
   verification receipt, and record IDs/check results in the operations journal.

Check B2 account Caps & Alerts before large read tests: the full cloud check
and Mac copy consume cloud reads. During the November refresh, the full cloud
and local checks passed, but B2 returned HTTP 403 `download_cap_exceeded` on
the additional post-prune check. The post-prune snapshot listing had already
confirmed the new snapshot, removal of the selected old ID and preservation of
the other 21. Re-run cloud `restic check` after the cap resets or the operator
changes it; do not claim that blocked check passed. Account caps were not changed.
See [Backblaze's download error codes](https://www.backblaze.com/apidocs/b2-download-file-by-name).

## Restore contract and limits

The snapshot contains a staging prefix. Restore to an isolated directory first;
the application/host paths are under `<staging-root>/root/`. Use the manifest
to map them to their original locations. Application owners decide the order
and service lifecycle for production recovery; never restore over running apps.

The copy combines a file-level capture with individually consistent SQLite
snapshots. It is not a transaction spanning all five databases or a full
application recovery drill. The restore test verifies stored bytes and database
integrity; it does not prove external credentials, connectivity or business flows.
Archive files can contain older invalid databases, retained for forensic history.

The restic password remains in Vault and must also have an independent operator
recovery copy. An encrypted Mac repository does not solve loss of that password.
The daily legacy job is unchanged by a manual refresh; restore by the explicit
verified snapshot ID/tag rather than an unqualified `latest` after later timer runs.

For the verified November Mac copy, an isolated restore can be started with:

```bash
restic -r ~/vps-backups/hetzner/2026-11-15/restic restore db645122 \
  --target <isolated-directory> --verify
```

Restic prompts for the repository password held in Vault. Never place that
password in shell history or restore directly over the Mac's system directories.
