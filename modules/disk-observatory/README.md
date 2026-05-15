# disk-observatory

Standalone (no Ansible) disk audit. SSHs into the VPS, collects `df` / `du` / `docker df`, prints + saves a Markdown report.

## Usage

```bash
./bin/disk-report               # print + save to reports/disk-<ts>.md
./bin/disk-report --no-save     # print only
```

## What it does

- `df -h /` — overall disk usage
- `du -xhd1` on `/`, `/var`, `/opt`, `/home`, `/root` — top-level sizes
- `docker system df` — Docker layer breakdown
- Top largest files / dangling volumes

## When to run

- When `verify.sh` reports `disk: WARN` and you need a quick, rich audit without invoking a playbook.
- During root-cause analysis (see [`docs/runbooks/disk-full.md`](../../docs/runbooks/disk-full.md)).

## Detailed runbook

[`docs/runbook.md`](docs/runbook.md).

## Output sample

See [`examples/sample-disk-report.md`](../../examples/sample-disk-report.md).
