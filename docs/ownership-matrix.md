# Ownership matrix

Who owns what on the VPS. Before any mutating action in another owner's zone, coordinate with that owner.

This document is meant to be **forked and customised** for your deployment. The tables below show the maintainer's reference deployment as a template — replace the application rows with your own services.

## System paths

| Path | Owner | Purpose | Can PraefectusAI modify? |
|---|---|---|---|
| `/etc/ssh/` | PraefectusAI | sshd_config + host keys | Yes (via role with `validate: sshd -t -f %s`) |
| `/etc/ufw/` | PraefectusAI | firewall rules | Yes |
| `/etc/fail2ban/` | PraefectusAI | jails | Yes |
| `/etc/systemd/system/` | PraefectusAI | host-level units (monitoring, backup) | Yes for own units only |
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

Each application running on the VPS is an "owner" with its own deploy pipeline. Replace the rows below with your own apps.

| Path | Owner project | What's inside | Deployed via | PraefectusAI override |
|---|---|---|---|---|
| `/opt/<app-1>/` | `<app-1-repo>` | bridge service, sqlite, sessions | application's own ansible | `docker-compose.override.local.yml` for `mem_limit` |
| `/opt/maxtg-bridge/` | `maxtg_bridge` | MAX -> Telegram bridge, SQLite state, MAX session, compose config | `maxtg_bridge` Ansible | host-level limits only; do not edit app compose/env directly |
| `/opt/<app-2>/` | `<app-2-repo>` | gateway, workspace, config | application's own deploy script | `mem_limit` |
| `/opt/fluentloop-bot/` | `fluentloop_bot` | Telegram learning bot, SQLite state, lesson/material data, compose config | application's own deploy script | host-level monitoring only; do not edit app compose/env directly |
| `/opt/<app-3>/` | `<app-3-repo>` | KG + vector store (high OOM risk) | application's own deploy script | `mem_limit` (critical) |
| `/opt/lightrag/` | `openclaw_firststeps` | LightRAG service, RAG storage, inputs, config, compose overrides | application's own deploy script | `docker-compose.override.local.yml` for host-level limits |
| `/opt/<app-4>/` | `<app-4-repo>` | router service | application's own deploy script | `mem_limit` |
| `/opt/moex-futoi/` | `moex_futoi` | MOEX/FUTOI trading signal bot, market data, signal registry, reports, compose deploy files | application's own deploy script | host-level monitoring only; do not edit app compose/env directly |
| `/opt/<routing-app>/` | `<routing-repo>` | stealth-routing config | routing project ansible | **No** |
| `/opt/stealth/` on `vps-hostkey-hermes` | `router_configuration` | GhostRoute owned managed egress: Caddy layer4 + Xray/Reality + restricted resolver | `router_configuration` Ansible | verify only; do not edit compose/config from this repo |
| `/opt/<obsidian-vault>/` | PraefectusAI (Syncthing host) | bidirectional sync with control machine | Syncthing | Yes |

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
- Is picked up automatically: `docker compose up` reads `docker-compose.yml + docker-compose.override.yml + docker-compose.override.local.yml`.

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
