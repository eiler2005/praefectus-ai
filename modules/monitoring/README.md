# monitoring

Manual control surface for `vps-monitor.py` (deployed by `20-monitoring.yml`).

## Usage

```bash
./bin/run-check                # run vps-monitor.py --once on the VPS
./bin/run-check --test-alert   # send a test Telegram alert
./bin/run-check --log          # tail /var/log/vps-monitor.log
./bin/run-check --status       # systemd timer status
```

## What `vps-monitor.py` does

A small Python poller deployed to `/usr/local/bin/vps-monitor.py`, run by a systemd timer every 5 min. It:

- Reads disk, memory, load, swap.
- Compares against thresholds in [`docs/runbooks/health-rules.md`](../../docs/runbooks/health-rules.md).
- Sends Telegram alerts on `WARN` / `CRIT` (when `vault_tg_*` are set).

## When to use

- Verify a monitoring change without waiting 5 min for the timer.
- Send a test alert after configuring Telegram tokens.
- Inspect the log when alerts are missing.

## Output sample

See [`examples/sample-monitor-alert.md`](../../examples/sample-monitor-alert.md).
