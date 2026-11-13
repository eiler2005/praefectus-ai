# Container registry

Fleet container registry, reconciled against read-only Docker inspection on
2026-11-13. Update when adding or removing services.

The intended app inventory lives in `ansible/inventory/production.yml`: five
containers on Hetzner and 25 on Hermes. Hermes additionally runs the separate
`buildx_buildkit_benka-migration0` builder (4 GiB memory limit). Short-lived MOEX
jobs and the periodic Reddit collector are not permanent service expectations.
Examples and per-container documentation templates below are not live services.

---

## Criticality and resource limits

| Container | Criticality | Resource limit | Notes |
|---|---|---|---|
| `deploy-bridge-1` | CRITICAL | 512m | `maxtg_bridge` production bridge; MAX egress uses reverse Channel M through VPS docker bridge listener guarded by router_configuration firewall/watchdog units |
| `fluentloop-bot` | HIGH | No explicit Docker memory/CPU/PID cap | Hetzner; `fluentloop_bot`; Docker health healthy |
| `ghostroute-console` | HIGH | No explicit Docker memory/CPU/PID cap; read-only rootfs | Hetzner; `router_configuration`; Docker health healthy |
| `xray`, `xray-xhttp` | CRITICAL | No explicit Docker memory/CPU/PID cap | Hetzner routing owner; no Docker healthcheck configured |
| `caddy`, `xray` on Hermes | CRITICAL | No explicit Docker memory/CPU/PID cap | `router_configuration`; no Docker healthcheck configured |
| `maxtg-watchdog` | HIGH | 128m / 128 pids / logs `10m x3` | External watchdog on Hermes observing the production bridge host; read-only SSH probe, push receiver on 18151, Telegram alerts. Owned by `maxtg_bridge`, deployed from that repo |
| `ci-digest` | HIGH | 256m / 0.50 CPU / 128 pids | Digest subscription API on Hermes; app-owned limits and persistent subscriber volume |
| `ci-digest-postgres` | HIGH | 384m / 0.50 CPU / 128 pids | Private PostgreSQL source of truth for encrypted contacts, consent evidence and delivery queue |
| `ci-caddy-inner` | HIGH | 128m / 0.25 CPU / 64 pids | Inner TLS terminator for the digest exact-SNI route; loopback-only host bind |
| `moex-futoi-bot-1` | HIGH | 1536m / 2048m memswap / 256 pids | `moex_futoi` FX/Radar bot on Hermes; app-owned compose limit raised after a `fx_compass_full` cgroup OOM; host has a managed 2 GiB swap buffer |
| `rc-api` | HIGH | 512 MiB / 0.5 CPU / 128 PIDs | Hermes; `reddit_compass`; private API at `127.0.0.1:8901` |
| `rc-caddy` | HIGH | 128 MiB | Hermes; authenticated HTTPS `8450`, private UI `127.0.0.1:8900` |
| `ladder` | MEDIUM | 256 MiB | Hermes; Reddit collector proxy, Docker-internal only |

Criticality scale:

- **CRITICAL** — service unavailability is a user-facing outage
- **HIGH** — degraded mode acceptable for minutes; backup-recoverable
- **MEDIUM** — internal automation; can be restarted at leisure
- **LOW** — best-effort; failure does not affect users
- **DISABLED** — intentionally stopped by the operator; excluded from outage alerts

---

## My AI Office on Hermes

`my-ai-office` owns the `benka-hermes` Compose project under
`/opt/benka-hermes`. The inventory below was reconciled by a read-only Docker
inspection on 2026-11-13. Limits are application-owned Compose policy; they are
recorded here so host monitoring can identify resource pressure, not so this
repository can rewrite the application's Compose files.

| Container | Service role | Criticality | Applied resource envelope |
|---|---|---|---|
| `benka-hermes-caddy-1` | Dashboard edge: TLS, mTLS and reverse proxy | CRITICAL | 128 MiB; read-only root filesystem |
| `benka-hermes-gateway-1` | Hermes Gateway: sole Telegram poller, profile routing, tools and cron | CRITICAL | 2 GiB / 2 CPU / 256 PIDs; read-only root filesystem |
| `benka-hermes-dashboard-1` | Browser dashboard process sharing the Gateway runtime boundary | HIGH | 2 GiB / 2 CPU / 256 PIDs; read-only root filesystem |
| `benka-hermes-redis-1` | Integration bus: Streams, consumer groups, dedupe, receipts and reconciliation | CRITICAL | 768 MiB |
| `benka-hermes-wiki-1` | Source-backed Markdown wiki ingest and query | HIGH | 2 GiB / 2 CPU / 256 PIDs; read-only root filesystem |
| `benka-hermes-lightrag-1` | Graph and vector retrieval over approved knowledge roots | HIGH | 4 GiB / 2 CPU |
| `benka-hermes-omniroute-1` | Provider routing for explicitly assigned workloads | MEDIUM | 1 GiB / 1 CPU |
| `benka-hermes-worker-email-personal-1` | Personal mailbox polling, dedupe and delivery | HIGH | 2 GiB / 2 CPU / 256 PIDs; read-only root filesystem |
| `benka-hermes-worker-email-work-1` | Work mailbox triage, digesting and delivery | HIGH | 2 GiB / 2 CPU / 256 PIDs; read-only root filesystem |
| `benka-hermes-worker-telegram-1` | Telethon reading, digest rendering and confirmed delivery | HIGH | 2 GiB / 2 CPU / 256 PIDs; read-only root filesystem |
| `benka-hermes-worker-signals-1` | Rule-based mail and Telegram signal monitoring | HIGH | 2 GiB / 2 CPU / 256 PIDs; read-only root filesystem |
| `benka-hermes-worker-last30days-1` | Personal Feed and Platform Pulse research | MEDIUM | 2 GiB / 2 CPU / 256 PIDs; read-only root filesystem |
| `benka-hermes-worker-maintenance-1` | Wiki lifecycle and LightRAG maintenance | MEDIUM | 2 GiB / 2 CPU / 256 PIDs; read-only root filesystem |

The integration bus is the Redis container above; **there is no separate
`integration-bus` container**. Hermes cron creates idempotent jobs in Redis,
workers consume their own streams, and the app records confirmed delivery or a
manual-reconciliation item before a job is acknowledged. `reddit-compass` is a
separate neighbour on the same host, not a My AI Office dependency.

The live state root is
`/opt/benka-hermes/production/cutover-20260906/state`, with `data/`, `runtime/`
and `private/` below it. The old top-level `state` and `private` paths do not
exist. Inventory now selects the actual root for encrypted backups, but the
installed backup script does not yet include it; deployment and restore proof
are pending. Host actions remain monitoring, port auditing, approved backups
and host-level cleanup. Do not run `docker compose` commands, use `chown -R`, prune
volumes, or inspect application secrets from PraefectusAI.

## Career Copilot dashboard on Hermes
`career-copilot` owns the deployed Compose project under `/opt/career-copilot`.
The deployment was verified on 2026-09-14 after the application owner confirmed
the container and healthcheck. The host layer monitors the service, audits its
loopback-only listener, and currently backs up `/opt/career-copilot/workspace`; it does not
edit the application's Compose, environment, or private data.

| Container | Service role | Criticality | Applied resource envelope |
|---|---|---|---|
| `career-copilot-dashboard` | Private Career Copilot dashboard | HIGH | 512 MiB / 1 CPU; application Compose confirmed |
| `career-copilot-gateway` | Authenticating HTTPS gateway (Caddy, TLS + Basic Auth) | HIGH | 128 MiB / 0.5 CPU; read-only rootfs, `cap_drop: ALL` + `NET_BIND_SERVICE` |

The dashboard also mounts the named volume `career-copilot_dashboard_state` at
`/data/state` for availability-check results and pending request files. The
owner's publish script imports pending requests, but requests awaiting import
are durable state. Inventory now includes this volume in the desired backup
scope; the installed backup script does not yet include it. The workspace
mount remains read-only. The dashboard image was refreshed on 2026-11-04;
the gateway retains its September runtime.

The expected host bindings are `127.0.0.1:8100` (dashboard) and `127.0.0.1:8445`
(gateway TLS). Dashboard health is `GET http://127.0.0.1:8100/healthz`; the
gateway uses its Docker healthcheck. Operator access remains available through an
SSH tunnel. Since 2026-09-15 browsers can also reach the dashboard over standard
HTTPS: the GhostRoute outer Caddy (`router_configuration` playbook
`13-hermes-app-web-route.yml`) forwards one exact SNI hostname, unterminated, to
`127.0.0.1:8445`. The hostname lives only in the application `.env`
(`CC_PUBLIC_HOST`); credentials are an application secret. No UFW or cloud
firewall change was needed because `443/tcp` was already public.

---

## Retired Hetzner OpenClaw-era runtime

The following limits are historical recovery references, not the active fleet.
The base Compose files remain `openclaw_firststeps` owned. Legacy playbooks
`60-docker-limits.yml` and `70-docker-limits-critical.yml` now require explicit
`legacy_workloads_enabled=true` after an owner-approved restore and audit.

### Intentional disablement

The Gateway was disabled on 2026-09-06. On 2026-11-13 no Gateway, legacy
OmniRoute or legacy LightRAG container existed. After explicit operator
approval and verified local archiving, heavy agent/memory data and LightRAG
data were removed; the inactive `omniroute-data` volume was removed. Configuration
and directory skeletons remain. Recovery requires the archive described in
[the November journal](journal/2026-11.md); it cannot use the empty data paths
as if they held the previous runtime. Do not restart these services or treat
their absence as a new incident. Remove the
`disabled_containers` inventory marker only after `openclaw_firststeps` has
approved a re-enable plan.

| Container | Owner | Ports | Data | Limit source |
|---|---|---|---|---|
| `openclaw-openclaw-gateway-1` | `openclaw_firststeps` | `127.0.0.1:18789-18790` | `/opt/openclaw/config`, `/opt/openclaw/workspace` | `70-docker-limits-critical.yml`: 1224m, 0.90 CPU, 256 pids, restart `on-failure:5`, logs `10m x3` |
| `omniroute` | `openclaw_firststeps` | `127.0.0.1:20128-20129` | `omniroute-data` Docker volume | `70-docker-limits-critical.yml`: 512m, 0.25 CPU, 128 pids |
| `lightrag-lightrag-1` | `openclaw_firststeps` | `127.0.0.1:8020` | `/opt/lightrag/data` | `70-docker-limits-critical.yml`: 2304m, 2816m swap, 0.45 CPU, 128 pids |

The historical LightRAG graph OOMed below `2304m`. This is not the live
`benka-hermes-lightrag-1` workload, which has a separate 4 GiB envelope on Hermes.

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
