# monitoring

Manual control surface for `vps-monitor.py` (deployed by `20-monitoring.yml`).

## Usage

```bash
./bin/run-check                # run vps-monitor.py --once on the VPS
./bin/run-check --test-alert   # send a test Telegram alert
./bin/run-check --watchdog     # run external cross-host reachability watchdog once
./bin/run-check --watchdog-test
./bin/run-check --log          # tail /var/log/vps-monitor.log
./bin/run-check --watchdog-log
./bin/run-check --status       # systemd timer status
./bin/run-check --watchdog-status
```

## What `vps-monitor.py` does

A small Python poller deployed to `/usr/local/bin/vps-monitor.py`, run by a systemd timer every 5 min. It:

- Reads disk, memory, load, swap.
- Checks recent kernel/cgroup OOM evidence.
- Checks Docker container memory pressure and restart counts.
- Warns when the current boot systemd journal shows a Docker ordering cycle;
  it reports the condition without copying raw journal text into alerts.
- Compares against thresholds in [`docs/runbooks/health-rules.md`](../../docs/runbooks/health-rules.md).
- Sends Telegram alerts on `WARN` / `CRIT` (when `vault_tg_*` are set).

`20-monitoring.yml` also deploys `/usr/local/bin/vps-external-watchdog.py`, run every 1 min by
`vps-external-watchdog.timer`. Each managed VPS checks the other managed VPS hosts over TCP/443 by
default and sends an external alert if a target is unreachable. The probe mode/port can be overridden
from vault when a different mutually reachable endpoint is preferred.

## When to use

- Verify a monitoring change without waiting 5 min for the timer.
- Send a test alert after configuring Telegram tokens.
- Inspect the log when alerts are missing.
- Prove that one VPS can alert when another VPS stops answering SSH.

## Output sample

See [`examples/sample-monitor-alert.md`](../../examples/sample-monitor-alert.md).
For the safe triage and ownership boundary, see
[`docs/runbooks/docker-boot-and-oom.md`](../../docs/runbooks/docker-boot-and-oom.md).
