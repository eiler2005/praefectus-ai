# health-trends

Trend analysis over the last N `reports/health/*.json` reports. Highlights direction, not point-in-time state.

## Usage

```bash
./bin/health-trend                   # last 10 checks
./bin/health-trend --last 30         # last 30
./bin/health-trend --trend disk      # disk only
./bin/health-trend --trend mem       # memory only
```

## What it shows

- Disk: growing / stable / shrinking over the window
- Memory available trend
- Swap usage trend
- Containers with `RestartCount > 0`
- Containers consistently near `mem_limit` (OOM candidates)

## When to run

- Before raising a `mem_limit` — confirm the candidate has sustained pressure, not a one-off spike.
- Weekly review — quick "where is this host trending" check.

## Output sample

See [`examples/sample-health-trend.txt`](../../examples/sample-health-trend.txt).
