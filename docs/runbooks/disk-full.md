# Runbook: disk full

What to do when the VPS root filesystem fills. From mild (≥ 80 %) to critical (≥ 95 %).

## Trigger

- `verify.sh` returns `disk: WARN` (≥ 80 %) or `FAIL` (≥ 90 %).
- A container fails to start with `no space left on device`.
- Telegram alert from `vps-monitor.py`.

## Step 0 — diagnose

Never clean blindly. Find out what grew.

### Scope first

This repository can manage more than one VPS. For any disk question, report one
line per host in the `vps` inventory group unless the operator explicitly names a
single target.

- Default scope for Ansible checks/cleanup: all hosts in `vps`.
- Single-host scope: only with an explicit `--limit <inventory-host>` or
  `./ansible/scripts/ssh-vps.sh --host <inventory-host> ...`.
- If the operator says "the VPS" and the inventory has multiple hosts, ask which
  host they mean or run the read-only audit across all hosts and say so.
- Final answers must name the inventory host(s) covered, not just "the VPS".

Inventory aliases are public labels; real SSH endpoints remain in the vault.

```bash
./verify.sh

# Optional deep single-host audit after the all-host verify:
./modules/disk-observatory/bin/disk-report --host <inventory-host>
```

Read the report. Pay attention to:

- `sudo du -xhd1 / /var /opt /home /root` — real sizes including protected dirs.
- `/var/lib/docker` and `/var/lib/containerd` — many images / build cache?
- Application data dirs in `/opt/<app>/data` — anomalous growth?
- Top large files — anything weird?
- Dangling volumes — orphaned state?

## Step 1 — standard cleanup

```bash
cd ansible
ansible-playbook playbooks/10-disk-cleanup.yml --check --diff
# Review what will be deleted (especially docker prune)
ansible-playbook playbooks/10-disk-cleanup.yml
./verify.sh
```

These commands target all hosts in the `vps` group. To clean exactly one host,
add `--limit <inventory-host>` to both playbook commands and to `./verify.sh`.

This typically frees 1–5 GB on a working server (apt cache + journal vacuum + docker image prune older than 7 days).

If `verify.sh` is green and disk is < 80 % afterwards — done.
If `verify.sh` is green but disk is still ≥ 80 % — no longer an emergency, but the application owner should review their data dir.

## Step 2 — if little was freed (< 500 MB)

Possible causes:

1. **Application data** in `/opt/<app>/{data,workspace}` — not your zone, escalate to the owner ([`ownership-matrix.md`](../ownership-matrix.md)).
2. **Recent docker images** that the `until=168h` filter did not catch. Check active image IDs and recent rollback tags:

   ```bash
   ./ansible/scripts/ssh-vps.sh --host <inventory-host> 'docker ps -q | xargs -r docker inspect --format "{{.Name}} {{.Config.Image}} {{.Image}}"'
   ./ansible/scripts/ssh-vps.sh --host <inventory-host> 'docker images --format "{{.ID}} {{.CreatedAt}} {{.Size}} {{.Repository}}:{{.Tag}}" | sort -k2r'
   ```

   When pruning rollbacks: keep the image ID used by the running container, the `latest` tag, and at least one most-recent unused rollback. Remove the rest.

3. **Dangling volumes** — manual review only. For each volume in `disk-report`:

   ```bash
   ./ansible/scripts/ssh-vps.sh --host <inventory-host> 'docker volume inspect <name>'
   ```

   - If the `Mountpoint` is empty or contains only tmp data → `docker volume rm <name>`.
   - If it holds state → escalate to the application owner.

4. **Build cache that did not prune** — the `until=` filter sometimes behaves oddly on older docker. Check:

   ```bash
   ./ansible/scripts/ssh-vps.sh --host <inventory-host> 'docker buildx du'
   ```

   When desperately needed: `docker buildx prune -af` (no filter — but this is **only** build cache, not runtime images).

## Application-owned cleanup candidates

Some paths in `/opt/<app>/` have known reclaim candidates documented by the application owner. Delete only after explicit owner approval.

Typical candidates (verify with the owner's docs):

- `/opt/<app>/backups/` — daily safety backups; usually retention is bounded by env vars.
- `/opt/<app>/data-backups/` — one-off pre-migration snapshots.
- Old rollback Docker images for the application (keep the active image, `latest`, and one most-recent rollback).

Never delete:

- Live SQLite / database files inside the application data dir.
- Active workspaces.
- Auth / SSH / repo runtime assets used by the application.

## Step 3 — if ≥ 90 % and urgent

Don't panic. Apply in order:

1. **Snapshot:**

   ```bash
   ./ansible/scripts/ssh-vps.sh --host <inventory-host> 'df -h /; df -ih /; sudo du -xhd1 / /var /opt /home /root 2>/dev/null | sort -hr | head -50'
   ```

2. **Vacuum journals manually:**

   ```bash
   ./ansible/scripts/ssh-vps.sh --host <inventory-host> 'sudo journalctl --vacuum-size=100M'
   ```

3. **Old kernel packages:**

   ```bash
   ./ansible/scripts/ssh-vps.sh --host <inventory-host> 'sudo apt-get autoremove --purge -y'
   ```

4. **Large log files of specific services:**

   ```bash
   ./ansible/scripts/ssh-vps.sh --host <inventory-host> 'sudo find /var/log -type f -size +100M -exec ls -lh {} \;'
   # For each one (only if you know what you're doing): sudo truncate -s 0 <path>
   ```

5. **Safe host-side docker prune:**

   ```bash
   ./ansible/scripts/ssh-vps.sh --host <inventory-host> 'docker container prune -f --filter "until=72h"'
   ./ansible/scripts/ssh-vps.sh --host <inventory-host> 'docker image prune -af --filter "until=168h"'
   ./ansible/scripts/ssh-vps.sh --host <inventory-host> 'docker builder prune -af --filter "until=168h"'
   ```

   Volumes are never pruned automatically.

After the manual emergency pass, return to the standard procedure:

```bash
cd ansible
ansible-playbook playbooks/10-disk-cleanup.yml --check --diff
ansible-playbook playbooks/10-disk-cleanup.yml
./verify.sh
```

## Step 4 — if ≥ 95 % and services failing

Critical situation. Block automatic cleanup:

- `10-disk-cleanup.yml` has a safety check and **stops** if `disk_used_pct >= disk_crit_pct` (95 % default).
- This is intentional — on a critical disk any `apt-get` may leave the system half-broken.

Actions:

1. Free at least 1–2 GB manually (see Step 3).
2. Then run the normal `10-disk-cleanup.yml`.
3. Then `./verify.sh` must be OK.

If there is literally no room even for `apt clean`:

1. `truncate` large logs (carefully — data loss).
2. `docker stop` non-critical containers manually to free tmpfs / overlay.
3. Escalate: upgrade the VPS plan or attach a volume.

## Step 5 — root cause analysis

After recovery, find the cause:

- Why did `/opt/<app>/data` grow? — owner: application project. Pruning issue or data reindexed?
- Why so many docker images? — rebuilds without `--rm` or CI without cleanup.
- Why did the journal balloon? — some service is spamming errors.

Record the finding in `reports/post-mortem-YYYY-MM-DD.md` and discuss with the application owner.

## Prevention

- Canonical weekly cleanup timer: `vps-cleanup.timer`, managed by `ansible/playbooks/11-periodic-cleanup-setup.yml`.
- Legacy `vps-weekly-cleanup.timer` must be disabled / removed; never run two cleanup timers concurrently.
- Run `10-disk-cleanup.yml` manually on `WARN` / `CRIT` after `--check --diff`.
- `verify.sh` hourly (warning at 80 % gives a week to react).
- With `30-backup.yml` enabled, watch the local restic cache on the VPS — it should stay small (restic writes directly to the remote repo).
