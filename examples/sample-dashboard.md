# VPS dashboard — vps-prod

> Updated: 2026-05-04 11:19 UTC

## Status

✅ **OK** — last check: `20260504T111847`

| Metric | Value |
|---|---|
| Disk / | 73% |
| RAM available | 2060 MB |
| Load 5min | 0.54 |
| Swap | 35% |

## Recent events

| Event | When | Detail |
|---|---|---|
| Last verify | 20260504T111847 | status=ok |
| Last cleanup | 20260504T111811 | freed=5284M |
| Last syncthing | (not run) | conflicts=? |

## Trend (last 5 checks)

`last 5: [W O O O O]  disk: ↓ shrinking`

## Quick commands

```bash
./verify.sh                                 # health check
./modules/monitoring/bin/run-check          # live check + Telegram alert
./modules/monitoring/bin/run-check --log    # view monitor log
./modules/port-audit/bin/port-audit         # port conflict scan
./modules/dashboard/bin/update-dashboard    # refresh this file
```

## Links

- [containers.md](../docs/containers.md) — container inventory and memory limits
- [ports.md](../docs/ports.md) — port map
- [firewall.md](../docs/firewall.md) — UFW rules
- [runbooks/maintenance-schedule.md](../docs/runbooks/maintenance-schedule.md) — maintenance cadence
- [runbooks/health-rules.md](../docs/runbooks/health-rules.md) — OK / WARN / CRIT rules
