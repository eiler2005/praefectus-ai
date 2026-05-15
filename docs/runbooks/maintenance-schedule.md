# Maintenance schedule

Preventive procedures, cadence, and ownership.

---

## Weekly — automatic (systemd timer)

**Timer:** `vps-cleanup.timer` (Sun 03:00 UTC)
**Script:** `/usr/local/bin/vps-periodic-cleanup.sh`
**Log:** `/var/log/vps-periodic-cleanup.log`
**Install / update:** `ansible-playbook playbooks/11-periodic-cleanup-setup.yml`

The legacy `vps-weekly-cleanup.timer` must be disabled / removed. Never run two weekly cleanup timers at once.

| Operation | Command | Safety |
|---|---|---|
| apt clean | `apt-get clean` | OS-level, data untouched |
| apt autoremove | `apt-get autoremove --purge` | OS-level |
| journal vacuum | `journalctl --vacuum-time=14d --vacuum-size=500M` | logs ≤ 14 d and ≤ 500 MB |
| docker container prune | `--filter "until=72h"` | only stopped > 3 d |
| docker image prune | `--filter "until=168h"` | only unused > 7 d |
| docker builder prune | `--filter "until=168h"` | build cache |

**Never automatically:** `docker volume prune` — volumes hold state.

### Pull the cleanup log to the control machine

```bash
# Current month
./modules/maintenance-journal/bin/cleanup-fetch

# All months
./modules/maintenance-journal/bin/cleanup-fetch --all

# stdout only (no file written)
./modules/maintenance-journal/bin/cleanup-fetch --stdout
```

The result is saved to `reports/maintenance/YYYY-MM.md`.

### Timer health check and repair

If `systemctl --failed` shows `vps-cleanup.service`, read the service log and the script log first:

```bash
ssh deploy@<vps> 'sudo systemctl status vps-cleanup.service --no-pager'
ssh deploy@<vps> 'sudo journalctl -u vps-cleanup.service -n 80 --no-pager'
ssh deploy@<vps> 'sudo tail -80 /var/log/vps-periodic-cleanup.log'
```

The script `/usr/local/bin/vps-periodic-cleanup.sh` is managed by Ansible — don't edit it on the VPS. Make fixes in `ansible/playbooks/11-periodic-cleanup-setup.yml`, then:

```bash
cd ansible
ansible-playbook -i inventory/production.yml playbooks/11-periodic-cleanup-setup.yml --check --diff
ansible-playbook -i inventory/production.yml playbooks/11-periodic-cleanup-setup.yml
ssh deploy@<vps> 'sudo systemctl reset-failed vps-cleanup.service && sudo systemctl start vps-cleanup.service'
ssh deploy@<vps> 'sudo systemctl is-active vps-cleanup.timer && sudo systemctl is-failed vps-cleanup.service'
```

Expected: timer `active`; service after the oneshot-run is `inactive`, not `failed`.

---

## Weekly — manual (on demand)

Run after `verify.sh` reports something, or as needed.

```bash
# Manual cleanup (writes reports/cleanup-*.md)
ansible-playbook playbooks/10-disk-cleanup.yml --check
ansible-playbook playbooks/10-disk-cleanup.yml

# Sanity check
./verify.sh
```

---

## Monthly — manual

In the first week of the month. Budget ~ 30 min.

| Task | Command | Note |
|---|---|---|
| Dangling volumes review | `ssh deploy@<vps> 'docker volume ls -f dangling=true'` | Inspect each; remove only orphans |
| `/opt/*` sizes | `ssh deploy@<vps> 'sudo du -xhd1 /opt \| sort -hr'` | Anomalous growth → escalate to owner |
| Application data growth audit | per-app `du -sh` | Coordinate with owner if > expected |
| Syncthing conflicts | `ssh deploy@<vps> 'find /opt/<sync-vault> -name "*.sync-conflict-*" \| head -20'` | Resolve manually |
| `authorized_keys` audit | `ssh deploy@<vps> 'cat ~/.ssh/authorized_keys'` | Confirm no extraneous keys |
| Pending security updates | `ssh deploy@<vps> 'apt list --upgradable 2>/dev/null'` | Note any pending patches |
| Journal entry | `docs/journal/YYYY-MM.md` | Any non-trivial change |

---

## Quarterly — manual

| Task | How | Note |
|---|---|---|
| Secret rotation review | Inspect vault + authorized_keys | When were they last rotated? |
| Image vulnerability scan | `trivy image <name>` for every running image | Critical CVE → rebuild |
| DR drill (optional) | Restore test on a fresh VPS | Validates backup + bootstrap |
| Memory budget review | `docker stats --no-stream` vs limits in `docs/containers.md` | Adjust limits on drift |

---

## Red lines (NEVER automatically)

- `docker volume prune` — volumes hold application state.
- `docker system prune -a` without `--filter "until=Nh"`.
- `docker compose down -v` anywhere under `/opt/`.
- `apt full-upgrade` or `do-release-upgrade`.
- VPS reboot without explicit approval.
- Removing contents of any application data dir.

---

## Files and artefacts

| Artefact | Where |
|---|---|
| Manual cleanup reports | `reports/cleanup-<ts>.md` (gitignored) |
| Aggregated weekly logs | `reports/maintenance/YYYY-MM.md` (gitignored) |
| Manual change journal | `docs/journal/YYYY-MM.md` (in git) |
| Weekly cleanup log on VPS | `/var/log/vps-periodic-cleanup.log` |
