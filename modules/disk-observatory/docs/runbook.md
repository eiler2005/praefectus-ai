# Runbook: disk-observatory

Standalone disk-state report for the VPS. Used for quick ad-hoc audits without invoking Ansible.

## When to run

- Before every `10-disk-cleanup.yml` — see what is about to grow or shrink.
- When a disk alert fires (once monitoring is wired up).
- Once a week as a plain audit; the result is saved to `reports/disk-report-*.md`.

## Usage

```bash
# Full report, saved to reports/
./modules/disk-observatory/bin/disk-report

# stdout only (no file)
./modules/disk-observatory/bin/disk-report --no-save
```

## What it collects

Over a single SSH session:

- `df -h /` — overall usage
- `df -ih /` — inode usage
- `free -h` — memory
- `/proc/loadavg` — load
- `sudo du -xhd1` for `/`, `/var`, `/opt`, `/home`, `/root` (top 50)
- `docker system df` — detailed Docker breakdown
- Active Docker image IDs and recent rollback / git-tag images
- `journalctl --disk-usage` — journal footprint
- apt cache size
- Top-50 files larger than 100 MB
- App-owned review candidates (e.g. backup directories under `/opt/<app>/`)
- Dangling Docker volumes (for manual review)

## Dependencies

- Control machine: `ansible` (for `ansible-vault view`)
- VPS: standard coreutils + Docker
- Vault password in `~/.vault_pass.txt`
