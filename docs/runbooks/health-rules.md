# Health rules

Formal criteria for VPS state. Used by `99-verify.yml`, `health-trend`, and the monitoring poller.
Architecture and rationale: [`architecture.md`](../architecture.md#monitoring-architecture),
[`ADR-0007`](../adr/0007-external-watchdog-and-resource-alerts.md).

---

## Statuses

| Status | Colour | Meaning |
|---|---|---|
| **OK** | green | Healthy, no action required |
| **WARN** | yellow | Suspicious; observe; no action yet |
| **CRIT** | red | Immediate attention required |

---

## Per-metric rules

### Disk (`/`)

| Metric | OK | WARN | CRIT |
|---|---|---|---|
| `disk_used_pct` | < 80 % | 80–89 % | ≥ 90 % |

**Actions:**
- WARN → log; check `./modules/disk-observatory/bin/disk-report`.
- CRIT → log + Telegram alert + run `10-disk-cleanup.yml`.

### Memory (RAM)

| Metric | OK | WARN | CRIT |
|---|---|---|---|
| `mem_available_mb` | > 500 MB | 200–500 MB | < 200 MB |
| `swap_used_pct` | < 60 % | 60–79 % | ≥ 80 % |
| Docker container memory | < 80 % of limit | 80–94 % | ≥ 95 % |

**Actions:**
- WARN → log; check `docker stats --no-stream` for OOM candidates.
- CRIT → log + Telegram alert + include top-5 processes by RSS in the alert.
- `openclaw-openclaw-gateway-1` above 80% of its Docker memory limit is an early WARN because it has
  previously OOMed without `maxtg_bridge` being the failing process.

### Load average (5 min)

| Metric | OK | WARN | CRIT |
|---|---|---|---|
| `load_5min` | < 2.0 | 2.0–3.9 | ≥ 4.0 |

**Actions:**
- WARN → log.
- CRIT → log + Telegram alert.

### Docker daemon

| Metric | OK | WARN | CRIT |
|---|---|---|---|
| `systemctl is-active docker` | active | — | inactive |

**Actions:**
- CRIT → Telegram alert with the last 20 lines of `journalctl -u docker`.

### Docker boot ordering

| Metric | OK | WARN | CRIT |
|---|---|---|---|
| current-boot Docker `ordering cycle` / `dependency cycle` | absent | present | — |

**Actions:**
- WARN → inspect the unit graph; do not restart Docker automatically.
- Confirm the owner of each unit before any change. A routing resolver may be
  application-owned even when its dependency affects the host Docker daemon.
- Follow [docker-boot-and-oom.md](docker-boot-and-oom.md); Docker activity,
  SSH and a public listener alone do not prove the affected data-plane.

### Containers (from `vault_expected_containers`)

| Metric | OK | WARN | CRIT |
|---|---|---|---|
| All expected containers running | all | — | at least one down |
| Healthcheck (http / tcp / docker) | ok | — | fail |
| RestartCount over 24 h | 0–2 | 3–9 | ≥ 10 |
| High-risk container RestartCount increase | no increase | any increase | repeated increase plus OOM |

**Actions:**
- Container not running → CRIT + Telegram with name + last 20 lines of `docker logs`.
- RestartCount ≥ 3 → WARN in log; check `docker logs <name>`.
- If `openclaw-openclaw-gateway-1` is stopped after exhausting `restart=on-failure:5`, treat that as
  host protection rather than an ordinary down container. Check OOM/restart evidence, then apply
  `70-docker-limits-critical.yml` and recreate only the Gateway after the resource cause is understood.

### UFW

| Metric | OK | WARN | CRIT |
|---|---|---|---|
| UFW status | active | not installed | inactive |

### OOM events

| Metric | OK | WARN | CRIT |
|---|---|---|---|
| kernel/cgroup OOM over monitor lookback window | 0 | — | > 0 |

**Actions:**
- CRIT → Telegram alert with process name; check limits in `docs/containers.md`.
- Repeated OpenClaw Gateway OOMs must not be masked by switching it back to `restart=unless-stopped`;
  keep the bounded restart policy so the VPS remains available for `maxtg_bridge` and SSH.
- OOM and a Docker boot ordering cycle are independent signals. Establish the
  unit-graph root cause before attributing a public data-plane incident to
  resource pressure.

### External watchdog

| Metric | OK | WARN | CRIT |
|---|---|---|---|
| Cross-host TCP/443 reachability | reachable | first failed probe | two consecutive failed probes |

**Actions:**
- WARN → wait for the next probe; transient SSH/network blips can happen.
- CRIT → Telegram alert from the checking VPS; inspect provider console, host power state, and
  out-of-band graphs before assuming an application-level outage.

---

## JSON report format

`99-verify.yml` writes two reports in parallel:

- `reports/verify-<ts>.md` — readable Markdown.
- `reports/health/<ts>.json` — machine-readable JSON for trend analysis.

```json
{
  "timestamp": "2026-05-03T09:00:00Z",
  "host": "vps-hetzner-prod",
  "overall_status": "ok",
  "metrics": {
    "disk_pct": 78,
    "mem_available_mb": 980,
    "load_5min": 0.42,
    "swap_used_pct": 12
  },
  "checks": [
    {"check": "ssh",           "status": "ok",   "detail": "connected"},
    {"check": "disk",          "status": "ok",   "detail": "78%"},
    {"check": "memory",        "status": "ok",   "detail": "980M available"},
    {"check": "load_5min",     "status": "ok",   "detail": "0.42"},
    {"check": "docker_daemon", "status": "ok",   "detail": "active"},
    {"check": "container_running:<container-name>", "status": "ok", "detail": "owner=<owner-project> running"}
  ]
}
```

`overall_status` rules:

- `fail` if at least one check is `fail`.
- `warn` if at least one check is `warn` (and none are `fail`).
- `ok` otherwise.

---

## Trend analysis

```bash
./modules/health-trends/bin/health-trend                # last 10 checks
./modules/health-trends/bin/health-trend --last 30      # last 30
./modules/health-trends/bin/health-trend --trend disk   # disk only
```

Detects:

- Disk: growing / stable / shrinking (trend over 7 / 30 points).
- Containers with RestartCount > 0.
- Containers consistently near memory limit (> 80 % of `mem_limit`) → OOM candidates.

---

## Report rotation

| Type | Keep | How |
|---|---|---|
| `reports/verify-*.md` | last 100 | `ls -t reports/verify-*.md \| tail -n +101 \| xargs rm -f` |
| `reports/health/*.json` | last 100 | same pattern |
| `reports/cleanup-*.md` | last 30 | same pattern |

Run rotation manually, or add it as a post-step in `10-disk-cleanup.yml`.
