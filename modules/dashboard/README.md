# dashboard

Generates [`docs/dashboard.md`](../../docs/dashboard.md) from the latest reports.

## Usage

```bash
./bin/update-dashboard
```

## What it does

- Reads the most recent `reports/health/*.json` (from `99-verify.yml`).
- Reads the most recent `reports/cleanup-*.md` (from `10-disk-cleanup.yml`).
- Reads the most recent `reports/syncthing-audit-*.md` (from `50-syncthing-audit.yml`).
- Writes a one-page snapshot to `docs/dashboard.md` (status, key metrics, recent events, trend hint).

## When to run

- After a `verify.sh` to refresh the rendered snapshot.
- Before linking someone to the dashboard ("here's what the box looks like right now").

## Output sample

See [`examples/sample-dashboard.md`](../../examples/sample-dashboard.md).
