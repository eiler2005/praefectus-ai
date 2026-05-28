# Verify report — vps-hetzner-prod — 20260506T085532

**Overall:** WARN

## System metrics

| Check | Value | Status |
|---|---|---|
| Disk / | 80% used | WARN |
| Memory | 1897M available | OK |
| Swap | 91% used | WARN |
| Load 5min | 2.02 | WARN |
| Docker | active | OK |
| UFW | Status: active | OK |

## Running containers

```
<critical-gateway>
<bridge-service>
<email-bridge-1>
<email-bridge-2>
<signals-bridge>
<cron-bridge>
<wiki-import>
<routing-transport-1>
<routing-transport-2>
<knowledge-graph>
<router-service>
<integration-bus>
```

## App directories

```
OK /opt/<app-1>
OK /opt/<app-2>
OK /opt/<app-3>
```

## Journal disk

Archived and active journals take up 196.2M in the file system.

## Container restart counts

```
<critical-gateway>: RestartCount=27
```

## Notes

- WARN is not CRIT — services are running, but disk and load are trending toward the next threshold. See [`docs/runbooks/health-rules.md`](../docs/runbooks/health-rules.md) for the rules.
- High RestartCount on `<critical-gateway>` is a known issue in another owner's zone (escalation logged in [`docs/journal/2026-05.md`](../docs/journal/2026-05.md)).
- Swap > 80 % triggers a CRIT alert in `vps-monitor.py`. Mitigated by the `mem_limit` work in `60-docker-limits.yml` + `70-docker-limits-critical.yml`.

## Output JSON (companion file)

`reports/health/20260506T085532.json` is written in parallel — same data in machine-readable form for `health-trend`. Schema documented in [`docs/runbooks/health-rules.md`](../docs/runbooks/health-rules.md).
