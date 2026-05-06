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

`last 5: [W O]  disk: ↓ shrinking`

## Quick commands

```bash
./verify.sh                                 # health check
./modules/monitoring/bin/run-check          # live check + Telegram alert
./modules/monitoring/bin/run-check --log    # view monitor log
./modules/port-audit/bin/port-audit         # port conflict scan
./modules/dashboard/bin/update-dashboard    # refresh this file
```

## Links

- [containers.md](containers.md) — все Docker контейнеры + mem limits
- [ports.md](ports.md) — карта портов
- [firewall.md](firewall.md) — UFW правила
- [runbooks/maintenance-schedule.md](runbooks/maintenance-schedule.md) — расписание профилактики
- [runbooks/health-rules.md](runbooks/health-rules.md) — правила OK/WARN/CRIT

