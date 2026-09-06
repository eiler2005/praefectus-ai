# Container registry

Inventory of every Docker container running on the VPS. Update when adding or removing services.

> **This file is meant to be customised for your deployment.** The structure below is the template; fill in the rows with your own containers. A complete sanitised reference inventory from the maintainer's deployment lives at [`examples/sample-containers.md`](../examples/sample-containers.md).

---

## Criticality and resource limits

| Container | Criticality | Resource limit | Notes |
|---|---|---|---|
| `deploy-bridge-1` | CRITICAL | 512m | `maxtg_bridge` production bridge; MAX egress uses reverse Channel M through VPS docker bridge listener guarded by router_configuration firewall/watchdog units |
| `openclaw-openclaw-gateway-1` | DISABLED | 1224m / 0.90 CPU / 256 pids / restart `on-failure:5` / logs `10m x3` | Intentionally disabled on `vps-hetzner-prod` by operator on 2026-09-06 after repeated resource pressure; data is retained and the monitor excludes it |
| `omniroute` | CRITICAL | 512m / 0.25 CPU / 128 pids | LLM route proxy; limits from `70-docker-limits-critical.yml` |
| `lightrag-lightrag-1` | CRITICAL | 2304m / 2816m swap / 0.45 CPU / 128 pids | Knowledge graph service; 2304m is intentional because lower caps caused cold-start OOM on the current graph |
| `ci-digest` | HIGH | 256m / 0.50 CPU / 128 pids | Digest subscription API on Hermes; app-owned limits and persistent subscriber volume |
| `ci-digest-postgres` | HIGH | 384m / 0.50 CPU / 128 pids | Private PostgreSQL source of truth for encrypted contacts, consent evidence and delivery queue |
| `ci-caddy-inner` | HIGH | 128m / 0.25 CPU / 64 pids | Inner TLS terminator for the digest exact-SNI route; loopback-only host bind |
| `moex-futoi-bot-1` | HIGH | 1536m / 2048m memswap / 256 pids | `moex_futoi` FX/Radar bot on Hermes; app-owned compose limit raised after a `fx_compass_full` cgroup OOM; host has a managed 2 GiB swap buffer |
| `<container-1>` | CRITICAL | `<NN>m` | Source of limit (e.g. `70-docker-limits-critical.yml`) |
| `<container-2>` | HIGH | `<NN>m` | |
| `<container-3>` | MEDIUM | `<NN>m` | |
| `<container-4>` | LOW | `<NN>m` | |

Criticality scale:

- **CRITICAL** — service unavailability is a user-facing outage
- **HIGH** — degraded mode acceptable for minutes; backup-recoverable
- **MEDIUM** — internal automation; can be restarted at leisure
- **LOW** — best-effort; failure does not affect users
- **DISABLED** — intentionally stopped by the operator; excluded from outage alerts

---

## Known OpenClaw Runtime Limits

These entries are host policy owned by PraefectusAI and persisted through
`docker-compose.override.local.yml`; the base compose files remain
`openclaw_firststeps` owned.

### Intentional disablement

`openclaw-openclaw-gateway-1` is intentionally stopped on `vps-hetzner-prod` as
of 2026-09-06. The host keeps `/opt/openclaw/config` and its Docker resources
for a possible owner-led recovery, but PraefectusAI must not restart the
gateway automatically or treat its absence as a new incident. Remove the
`disabled_containers` inventory marker only after `openclaw_firststeps` has
approved a re-enable plan.

| Container | Owner | Ports | Data | Limit source |
|---|---|---|---|---|
| `openclaw-openclaw-gateway-1` | `openclaw_firststeps` | `127.0.0.1:18789-18790` | `/opt/openclaw/config`, `/opt/openclaw/workspace` | `70-docker-limits-critical.yml`: 1224m, 0.90 CPU, 256 pids, restart `on-failure:5`, logs `10m x3` |
| `omniroute` | `openclaw_firststeps` | `127.0.0.1:20128-20129` | `omniroute-data` Docker volume | `70-docker-limits-critical.yml`: 512m, 0.25 CPU, 128 pids |
| `lightrag-lightrag-1` | `openclaw_firststeps` | `127.0.0.1:8020` | `/opt/lightrag/data` | `70-docker-limits-critical.yml`: 2304m, 2816m swap, 0.45 CPU, 128 pids |

Do not reduce LightRAG below `2304m` without coordinating with
`openclaw_firststeps`; the current graph has previously OOMed at lower caps.

## Cheap Intelligence digest on Hermes

These containers are owned by `AiNativeBook_Draft_26/services/digest-service` and
deployed from its `deploy/hermes-stack/` source. PraefectusAI monitors and backs
up the stack but does not edit its base Compose file.

| Container | Owner | Ports | Data | Healthcheck / recovery |
|---|---|---|---|---|
| `ci-digest` | `AiNativeBook_Draft_26/services/digest-service` | `127.0.0.1:8080` | named volume `cheap-intelligence_digest_data` mounted at `/data` | Node `/healthz`; restic backs up the named-volume mountpoint |
| `ci-digest-postgres` | `AiNativeBook_Draft_26/services/digest-service` | no host port; private `cheap-intelligence_net` only | named volume `cheap-intelligence_digest_postgres` | PostgreSQL healthcheck; restic backs up the named-volume mountpoint |
| `ci-caddy-inner` | `AiNativeBook_Draft_26/services/digest-service` | `127.0.0.1:8444` | Caddy certificate/config named volumes; certificates are reissuable | internal `http://127.0.0.1:8081/healthz`; public TLS arrives through routing-owned outer Caddy `:443` |

`ci-digest-worker` is an app-owned delivery profile rather than an always-on container. It is
added to the monitor expectation only at the separately approved email-delivery launch, when
`DELIVERY_ENABLED=true`, a verified sender domain and an ESP have passed seed tests.

Resource pressure and a Docker boot-order cycle are separate incident tracks.
Use the host monitor plus [docker boot and OOM recovery](runbooks/docker-boot-and-oom.md)
to establish evidence before changing an app limit or restarting a container.

## MOEX/FUTOI on Hermes

`moex-futoi-bot-1` is owned and deployed by `pulsar-trader-lab`. Its production
compose now uses `mem_limit: 1536m` and `memswap_limit: 2048m`; the shared
Radar/ML/FX heavy-job mutex and one-thread allocator bounds remain required.
PraefectusAI owns only the host safety layer: monitoring, the bounded 2 GiB
`/swapfile`, and read-only verification. Do not edit the app compose, `.env`,
or SQLite databases from this repository.

---

## Per-container detail (template)

For every container, document:

```

### `deploy-bridge-1`

| Parameter | Value |
|---|---|
| Owner | `maxtg_bridge` |
| Image | `maxtg-bridge:prod` |
| Ports | none published; container reaches Channel M via Docker bridge gateway on `18057/tcp` |
| Volumes | `/opt/maxtg-bridge/data`, `config.yaml`, `config.local.yaml` |
| Healthcheck | Docker healthcheck from bridge runtime heartbeat |
| `mem_limit` | 512m from application compose |
| Role | MAX -> Telegram bridge; Telegram direct from VPS; MAX API/CDN through reverse Channel M; stale VPS listener recovery is owned by `router_configuration` |
| Data | SQLite DB, MAX session and runtime health files under `/opt/maxtg-bridge/data` |
| Deploy | `maxtg_bridge` repo for the app; `router_configuration` owns the Channel M reverse VPS listener/firewall/watchdog path |
### <container-name>

| Parameter | Value |
|---|---|
| Owner | <owner-project> |
| Image | <image:tag> |
| Ports | <bind-spec> (e.g. 127.0.0.1:8080) |
| Volumes | <list of mounted paths> |
| Healthcheck | <command or "none"> |
| `mem_limit` | <limit> + source playbook |
| Role | <one line: what it does for the system> |
| Data | <where state lives, recovery story> |
| Deploy | <which repo/script/playbook deploys it> |
```

---

## Memory budget

Document the running memory shape so you can plan limits:

```
OS + system daemons:           ~500 MB
<critical-1>:                  <NN> MB    (limit <NNN>m)
<critical-2>:                  <NN> MB    (limit <NNN>m)
<medium-1>:                    <NN> MB    (limit <NNN>m)
…
────────────────────────────────────
Total measured:               ~<NNNN> MB
```

**Update the measured column with:** `docker stats --no-stream`.

---

## Verification commands

```bash
# Current RAM usage per container
docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}"

# Verify a limit is applied after `docker compose up -d`
docker inspect <container> \
  --format '{{.Name}} NanoCpus={{.HostConfig.NanoCpus}} Memory={{.HostConfig.Memory}} MemorySwap={{.HostConfig.MemorySwap}} PidsLimit={{.HostConfig.PidsLimit}} Restart={{.HostConfig.RestartPolicy.Name}}:{{.HostConfig.RestartPolicy.MaximumRetryCount}} Log={{.HostConfig.LogConfig.Type}}'

# Every limit at once
docker inspect $(docker ps -q) | jq '.[] | {Name: .Name, NanoCpus: .HostConfig.NanoCpus, MemLimit: .HostConfig.Memory, PidsLimit: .HostConfig.PidsLimit}'
```
