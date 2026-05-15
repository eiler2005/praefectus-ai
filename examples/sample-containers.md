# Sample container registry

A populated `docs/containers.md` from a real production deployment, sanitised. Use this as a reference for what the template at [`docs/containers.md`](../docs/containers.md) looks like once filled in.

**Server:** Hetzner CX23 · 4 GB RAM · 2 vCPU · Ubuntu 24.04
**Last audit:** 2026-05-09
**Total containers:** 13

---

## Criticality and memory limits

| Container | Criticality | `mem_limit` | Notes |
|---|---|---|---|
| `<bridge-service>` | CRITICAL | 256m ✅ | Set in app's prod compose |
| `<routing-transport-1>` | CRITICAL | none | Routing-side, owned externally |
| `<routing-transport-2>` | CRITICAL | none | Routing-side, owned externally |
| `<critical-gateway>` | CRITICAL | 1224m ✅ | `70-docker-limits-critical.yml` |
| `<knowledge-graph>` | HIGH | 192m ✅ | `70-docker-limits-critical.yml` (measured ~117 MB) |
| `<router-service>` | HIGH | 512m ✅ | `70-docker-limits-critical.yml` |
| `<integration-bus>` | HIGH | 256m ✅ | `70-docker-limits-critical.yml` |
| `<signals-bridge>` | MEDIUM | 384m ✅ | `60-docker-limits.yml` |
| `<cron-bridge>` | MEDIUM | 256m ✅ | `60-docker-limits.yml` |
| `<admin-console>` | MEDIUM | 450m ✅ | Coordinated with routing-side owner |
| `<wiki-import>` | LOW | 256m ✅ | `60-docker-limits.yml` |
| `<email-bridge-1>` | LOW | 256m ✅ | `60-docker-limits.yml` |
| `<email-bridge-2>` | LOW | 256m ✅ | `60-docker-limits.yml` |

---

## Per-container detail (excerpt)

### `<critical-gateway>`

| Parameter | Value |
|---|---|
| Owner | `<app-2>` project |
| Image | `<image:tag>` |
| Ports | `127.0.0.1:18789` (main), `127.0.0.1:18790` (bridge) |
| Volumes | config dir, workspace dir, `/opt/<sync-vault>` |
| Healthcheck | `GET /healthz` on `127.0.0.1:18789` (10 s interval) |
| `mem_limit` | **1224 m** (`70-docker-limits-critical.yml`) |
| Role | Main AI gateway — entrypoint for AI requests |
| Deploy | `<app-2>/artifacts/<container>/` |

### `<knowledge-graph>`

| Parameter | Value |
|---|---|
| Owner | `<app-2>` project |
| Image | `<image:tag>` |
| Ports | `127.0.0.1:8020` (HTTP /health) |
| Volumes | `/opt/<app-3>/data/` (1.7 GB on disk — KG + embeddings) |
| Healthcheck | `GET /health` on `127.0.0.1:8020` |
| `mem_limit` | **192 m** ✅ (`70-docker-limits-critical.yml`; measured ~117 MB) |
| Role | Knowledge graph + vector search for the gateway |
| Data | `/opt/<app-3>/data/` — recoverable; reindex is slow |

(remaining 11 containers follow the same template)

---

## Memory budget (4 GB RAM)

```
OS + system daemons:           ~500 MB
<bridge-service>:               256 MB  ← limit 256m ✅
<routing-transport-{1,2}>:      ~51 MB  (measured, no limit)
<critical-gateway>:            ~599 MB  (measured, limit 1224m ✅)
<knowledge-graph>:             ~136 MB  (measured, limit 192m ✅)
<router-service>:              ~182 MB  (measured, limit 512m ✅)
<integration-bus>:               ~6 MB  (measured, limit 256m ✅)
<signals-bridge>:               ~54 MB  (measured, limit 384m ✅)
<cron-bridge>:                  ~32 MB  (measured, limit 256m ✅)
<admin-console>:               ~132 MB  (measured, no host limit)
<wiki-import>:                   ~6 MB  (measured, limit 256m ✅)
<email-bridge-1>:               ~23 MB  (measured, limit 256m ✅)
<email-bridge-2>:               ~34 MB  (measured, limit 256m ✅)
────────────────────────────────────────
Total measured:               ~2.0 GB
```

Worst-case sum of declared limits: ~ 4.4 GB on a 4 GB host. Acceptable overcommit because the measured working set is well below 50 % of declared.

---

## Verification

```bash
# Current RAM usage per container
docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}"

# Verify a limit is applied
docker inspect <container> | grep -i memory

# Every limit at once
docker inspect $(docker ps -q) | jq '.[] | {Name: .Name, MemLimit: .HostConfig.Memory}'
```
