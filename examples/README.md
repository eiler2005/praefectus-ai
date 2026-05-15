# Examples

Sanitised real outputs from the maintainer's production deployment, so you can see what PraefectusAI produces without provisioning a VPS.

Every value here is masked: container names follow generic patterns, IPs are RFC 5737 (`198.51.100.x`), hostnames are `example.invalid`, paths are abstract.

## What's here

| File | Source command | What it shows |
|---|---|---|
| [`sample-verify-output.md`](sample-verify-output.md) | `./verify.sh` | Full health gate — 12 checks rolled into one report |
| [`sample-dashboard.md`](sample-dashboard.md) | `./modules/dashboard/bin/update-dashboard` | One-page state snapshot |
| [`sample-health-trend.txt`](sample-health-trend.txt) | `./modules/health-trends/bin/health-trend --last 10` | Trend over the last 10 verify reports |
| [`sample-disk-report.md`](sample-disk-report.md) | `./modules/disk-observatory/bin/disk-report` | Standalone disk audit |
| [`sample-cleanup-log.md`](sample-cleanup-log.md) | `cat reports/cleanup-*.md` | Output of a single weekly cleanup run |
| [`sample-monitor-alert.md`](sample-monitor-alert.md) | `vps-monitor.py` Telegram alert | What an alert looks like |
| [`sample-secret-scan.txt`](sample-secret-scan.txt) | `./modules/secrets-management/bin/secret-scan` | Scanner catching simulated leaks |
| [`sample-containers.md`](sample-containers.md) | maintainer's `docs/containers.md` | A populated container inventory (template lives at `docs/containers.md`) |

## Want to reproduce?

After [`Quick Start`](../README.md#quick-start) on your own VPS:

```bash
./verify.sh
./modules/dashboard/bin/update-dashboard
./modules/health-trends/bin/health-trend
./modules/disk-observatory/bin/disk-report
./modules/secrets-management/bin/secret-scan
```

Output formats match these samples.
