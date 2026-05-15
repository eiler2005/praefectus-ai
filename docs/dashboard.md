# VPS dashboard

> This file is **regenerated** by `./modules/dashboard/bin/update-dashboard`. Manual edits are overwritten on the next refresh.
>
> A sanitised sample of what this looks like in production lives at [`examples/sample-dashboard.md`](../examples/sample-dashboard.md).

## Status

(no data — run `./modules/dashboard/bin/update-dashboard`)

## Quick commands

```bash
./verify.sh                                 # health check
./modules/monitoring/bin/run-check          # live check + Telegram alert
./modules/monitoring/bin/run-check --log    # view monitor log
./modules/port-audit/bin/port-audit         # port conflict scan
./modules/dashboard/bin/update-dashboard    # refresh this file
```

## Links

- [containers.md](containers.md) — container inventory and memory limits
- [ports.md](ports.md) — port map
- [firewall.md](firewall.md) — UFW rules
- [runbooks/maintenance-schedule.md](runbooks/maintenance-schedule.md) — maintenance cadence
- [runbooks/health-rules.md](runbooks/health-rules.md) — OK / WARN / CRIT rules
