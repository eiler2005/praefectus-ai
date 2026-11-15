# Ownership matrix

Who owns what on the VPS. Before any mutating action in another owner's zone, coordinate with that owner.

This is the managed fleet ownership map, reconciled on 2026-11-13. Historical
runtime and archived data are labelled explicitly; directory existence alone
does not mean that an application is active.

## System paths

| Path | Owner | Purpose | Can PraefectusAI modify? |
|---|---|---|---|
| `/etc/ssh/` | PraefectusAI | sshd_config + host keys | Yes (via role with `validate: sshd -t -f %s`) |
| `/etc/ufw/` | PraefectusAI | firewall rules | Yes |
| `/etc/fail2ban/` | PraefectusAI | jails | Yes |
| `/etc/systemd/system/` | PraefectusAI | host-level units (monitoring, backup) | Yes for own units only |
| `/etc/systemd/system/docker.service` when a routing-owned resolver bridge guard is enabled | `router_configuration` | source-controlled narrow override that prevents a Docker/resolver ordering cycle | No; observe/report and coordinate with routing owner |
| `/etc/systemd/system/channel-m-reverse-firewall.*` | `router_configuration` | Channel M reverse docker bridge firewall persistence | No; verify only from this repo |
| `/etc/systemd/system/channel-m-reverse-listener-watchdog.*` | `router_configuration` | Channel M stale reverse listener recovery | No; verify only from this repo |
| `/etc/logrotate.d/vps-management` | PraefectusAI | logrotate for system services | Yes |
| `/etc/caddy/`, `/etc/nginx/` | application project (e.g. routing/proxy owner) | host reverse-proxy config | **No** (coordinate only) |
| `/etc/ssh/sshd_config.d/51-channel-m-reverse.conf` | `router_configuration` | Deploy-user scoped `GatewayPorts clientspecified` for Channel M reverse listener | No; preserve during SSH hardening |
| `/usr/local/sbin/channel-m-reverse-firewall.sh` | `router_configuration` | Reinstalls the docker bridge INPUT allow for Channel M | No; preserve during cleanup |
| `/usr/local/sbin/channel-m-reverse-listener-watchdog.sh` | `router_configuration` | Removes bound-but-not-forwarding stale Channel M SSH reverse listeners | No; preserve during cleanup |
| `/var/log/` | PraefectusAI | system + service logs | Yes (vacuum, rotate) |
| `/var/lib/docker/` | PraefectusAI (host-side) | docker storage | Yes (`prune` with `--filter` only!) |
| `/var/cache/apt/` | PraefectusAI | apt cache | Yes (clean) |
| `/home/deploy/.ssh/authorized_keys` | PraefectusAI / `router_configuration` scoped exception | Normal SSH access keys; Channel M `permitlisten` key entry | Yes for normal access keys; preserve scoped Channel M `permitlisten` entry |
| `/home/deploy/.config/syncthing/` | PraefectusAI | syncthing config | Yes |

## Application paths in `/opt/`

Each application is an owner with its own deploy pipeline.

| Path | Owner project | What's inside | Deployed via | PraefectusAI override |
|---|---|---|---|---|
| `/opt/maxtg-bridge/` | `maxtg_bridge` | MAX -> Telegram bridge, SQLite state, MAX session, compose config | `maxtg_bridge` Ansible | host-level limits only; do not edit app compose/env directly |
| `/opt/maxtg-watchdog/` | `maxtg_bridge` | External watchdog observing the production bridge host; state volume, pinned SSH key | `deploy/external-watchdog/deploy.sh` (application owner) | host-level limits only; never edit the app compose/env directly |
| `/opt/openclaw/` on `vps-hetzner-prod` | `openclaw_firststeps` | retired Gateway configuration and retained workspace; heavy agent/memory data archived off-host on 2026-11-13 | owner-approved restore only | historical resource policy; do not recreate automatically |
| `/opt/fluentloop-bot/` | `fluentloop_bot` | Telegram learning bot, SQLite state, lesson/material data, compose config | application's own deploy script | host-level monitoring only; do not edit app compose/env directly |
| `/opt/lightrag/` on `vps-hetzner-prod` | `openclaw_firststeps` | retired legacy LightRAG configuration; data archived off-host on 2026-11-13 | owner-approved restore only | historical limits; distinct from the active My AI Office LightRAG on Hermes |
| `/opt/ghostroute-console/` on `vps-hetzner-prod` | `router_configuration` | live Console, SQLite history and snapshots | routing project workflow | observe only; app data retention belongs to the owner |
| `/opt/moex-futoi/` | `moex_futoi` | MOEX/FUTOI trading signal bot, market data, signal registry, reports, compose deploy files | application's own deploy script | host-level monitoring + bounded host swap only; do not edit app compose/env directly |
| `/opt/cheap-intelligence/` on `vps-hostkey-hermes` | `AiNativeBook_Draft_26/services/digest-service` | digest API, inner Caddy, subscriber/issues volume and app secrets | app-owned `deploy/hermes-stack/` workflow | monitoring; B2 backups disabled by operator on 2026-11-15; do not edit app compose/env from this repo |
| `/opt/reddit-compass/` on `vps-hostkey-hermes` | `reddit_compass` | trend radar: FastAPI + own Caddy (public HTTPS behind Basic Auth), Ladder paywall proxy, batch collector, both SQLite databases in `reddit-compass_data` | app-owned `deploy/hostkey/deploy.sh` | monitoring only; **not** in `host_backup_paths` (see note below); do not edit app compose/env from this repo |
| `/opt/benka-hermes/` on `vps-hostkey-hermes` | `my-ai-office` | 13-service office; live data under `production/cutover-20260906/state`, including private state | app-owned `deploy/hermes/` Compose workflow | monitor and audit only; B2 backups disabled by operator on 2026-11-15 (see coverage note); never edit Compose, env files, manifests, volumes or lifecycle from this repo |
| `/opt/career-copilot/` on `vps-hostkey-hermes` | `career-copilot` | Dashboard, authenticating HTTPS gateway, read-only workspace and durable request/check volume | application-owned Compose workflow | monitor both containers and loopback `8100`/`8445`; B2 backup history retired and scheduling disabled by operator on 2026-11-15; public `443` SNI route is routing-owned; never edit app configuration, credentials or private data from this repo |
| `/opt/stealth/` on both hosts | `router_configuration` | GhostRoute owned managed egress: reverse proxy, Xray backends and restricted resolver | `router_configuration` Ansible | verify only; do not edit compose/config from this repo |
| `/opt/obsidian-vault/` on `vps-hetzner-prod` | PraefectusAI (Syncthing host) | bidirectional sync with control machine | Syncthing | Yes |

### Current state and backup coverage

Hetzner received a verified one-off B2 recovery snapshot and an independent
encrypted Mac copy on 2026-11-15, covering active application directories,
container mounts and host configuration. This does not change the deployed
daily legacy job's narrower scope. The additional cloud check after pruning
was blocked by the B2 read cap; full cloud and Mac restore checks passed before
replacement. See [backup refresh](runbooks/backup-refresh.md) and
[the journal](journal/2026-11.md) for exact snapshot IDs and remaining checks.
The follow-up bucket consolidation keeps only `vps-hetzner-prod/`, uploaded
from the independent Mac copy; both previous repository prefixes and all their
versions were explicitly retired. Hetzner's daily job now targets that prefix.

My AI Office's actual mounted state root is
`/opt/benka-hermes/production/cutover-20260906/state` (including its private
subtree). The old top-level `/opt/benka-hermes/state` and `private` paths do not
exist. Inventory retains the actual state root and the
`career-copilot_dashboard_state` volume as candidate scope alongside digest
volumes and the workspace. The operator subsequently retired the entire Hermes
B2 repository on 2026-11-15 and disabled its schedule (`backup_enabled: false`).
There is no current Hermes recovery history in this bucket. Do not re-enable
or recreate it through routine maintenance without a new operator decision.

The old office candidate builds and two failed/pre-refresh Career Copilot
workspace copies were archived locally and removed on 2026-11-13. Active
releases, production state, current workspace and `workspace-prev` remain.
The Hetzner legacy `omniroute-data` volume was separately archived and removed;
it is not the live Hermes OmniRoute data. See [the journal](journal/2026-11.md).

### Note: `reddit-compass` data is not backed up

The `reddit-compass_data` volume holds the accumulated release history (~13 GiB and
growing every collection cycle). It is deliberately **absent** from
`host_backup_paths`: backups go to a paid B2 repository, and the owner has not
signed off on that recurring cost. Losing the volume loses the accumulated
history — collection cannot be replayed for past days. Adding it is an operator
decision, not a default.

## What "owner" means

- **Deploy and configuration** — every change in this directory is made by the owner via their own repo.
- **Application secrets** — `.env.secrets`, `config.local.yaml`, etc. — owner's zone.
- **Docker images** — which versions, which tags — owner.
- **Healthcheck endpoints** — what paths respond and what they return — owner.

## What "PraefectusAI override" means

PraefectusAI may (and should) impose host policy via `docker-compose.override.local.yml` next to the owner's main compose file. This file:

- Is written by ansible (`60-docker-limits.yml`, `70-docker-limits-critical.yml`).
- Is **not** managed by the application owner.
- Contains **only** host-level constraints: `mem_limit`, `memswap_limit`, `cpus`, `pids_limit`, `restart`, `logging.driver`.
- Does not change services, ports, env, or volumes.
- Must be selected explicitly with `-f docker-compose.override.local.yml` in the
  owner's Compose invocation or equivalent `COMPOSE_FILE`; the `.local` name
  is not a default Compose override filename.

Example:

```yaml
# /opt/<app-name>/docker-compose.override.local.yml — managed by PraefectusAI
services:
  <service-name>:
    mem_limit: 512m
    memswap_limit: 512m
    cpus: 0.5
    pids_limit: 128
    restart: unless-stopped
    logging:
      driver: json-file
      options: { max-size: 10m, max-file: "3" }
```

## Incident escalation

1. **PraefectusAI alert shows a container down in another owner's zone** → PraefectusAI records the fact + uptime + last logs in Telegram, but **does not** restart it.
2. The application owner is notified (via Telegram channel or directly).
3. The owner goes to their own repo, diagnoses, and restarts.
4. After recovery, `./verify.sh` from PraefectusAI must show OK.

**Exception:** if a container is crash-looping and consuming disk via logs, PraefectusAI may stop the container (`docker stop <container>`) with a notification, to prevent the host from going down. Never run `docker rm` or remove data.
