# VPS Runtime Map

This document is the operator-facing map of what PraefectusAI records and
protects across the current VPS fleet: the GhostRoute/channel setup and the
Hermes workload host that runs My AI Office. It keeps the ownership boundary
explicit: PraefectusAI owns the host layer, while routing and application
projects own their reverse proxy, tunnels, Compose configuration, state, and
runtime.

This is a sanitized expected-runtime view plus a read-only software baseline.
Real public IPs, SSH users, SSH ports, provider firewall values, tokens and app
secrets stay in Ansible Vault, application-owned secrets, or gitignored
reports.

## Reconciliation — 2026-11-13

The active contract is five app/routing containers on `vps-hetzner-prod` and
25 on `vps-hostkey-hermes`. Hermes also runs a separate migration BuildKit
builder; MOEX jobs and the Reddit collector can run temporarily and are not
permanent service expectations. All persistent containers were running during
the read-only snapshot. Post-cleanup host gates passed at 62% disk on Hetzner
and 61% on Hermes; see [the operations journal](journal/2026-11.md).

Repository configuration and installed scripts are not yet identical:

- Inventory now records all five Hetzner containers and excludes the retired
  OpenClaw-era services. The installed Hetzner poller still expects the old
  services; the Hermes poller expects only five of the 25 app containers.
- Infrastructure Telegram delivery is not configured on either host. The
  Hermes monitor also retains a current-boot Docker ordering-cycle warning.
- The installed Hermes backup script covers the two digest volumes and Career
  Copilot workspace. Inventory now selects the actual office state root and
  the Career Copilot durable request/check volume too; these additions require
  a reviewed backup deployment and restore verification before claiming coverage.
- `99-verify.yml` checks host guardrails but currently does not assert the
  full expected-container set or Docker health. A green gate is not proof of
  application business behavior or complete backup coverage.

The approved cleanup removed archived legacy Hetzner agent/memory/LightRAG
data and the inactive OmniRoute volume, and archived obsolete Hermes candidate
builds and workspace refresh copies. Active office state, current app releases,
current workspace and `workspace-prev` were retained. Local archives are not
cloud backup snapshots. Legacy resource playbooks `60` and `70` require explicit
`legacy_workloads_enabled=true` after an owner-approved restore and audit.

For machine-readable guardrails, see
[`ansible/inventory/production.yml`](/ansible/inventory/production.yml),
[`docs/ports.md`](/docs/ports.md) and
[`docs/ownership-matrix.md`](/docs/ownership-matrix.md). For live verification,
run `./verify.sh --limit vps-hetzner-prod` and
`./modules/port-audit/bin/port-audit --host vps-hetzner-prod`.

## At A Glance

```mermaid
flowchart LR
  subgraph internet[Public internet and selected clients]
    clients[Remote clients]
    consoleUser[Console operator]
    syncthingPeer[Syncthing peer]
  end

  subgraph vps[VPS host]
    sshd[OpenSSH + allowlisted access]
    ufw[UFW public firewall]
    docker[Docker Engine + Compose]
    proxy[Host reverse proxy<br/>Caddy or nginx, app-owned config]
    xray[Xray / routing backends<br/>routing project-owned]
    console[GhostRoute Console<br/>read-only app surface]
    maxtg[maxtg_bridge container]
    chanM[Channel M reverse listener<br/>Docker bridge scoped]
    watchdogs[Channel M firewall and stale-listener watchdog timers]
    syncthing[Syncthing host service]
    monitors[PraefectusAI monitor, backup, cleanup, verify]
  end

  subgraph router[Home router]
    routerM[Channel M SSH remote-forward]
    routerD[Channel D router-native NaiveProxy]
    routerSplit[Router managed split]
  end

  clients -->|HTTPS / routing channels| proxy --> xray
  consoleUser -->|443 by host/SNI or 2087 dedicated| proxy --> console
  syncthingPeer --> syncthing
  maxtg --> chanM --> routerM --> routerSplit
  watchdogs -. guards .-> chanM
  monitors -. audits .-> sshd
  monitors -. audits .-> ufw
  monitors -. audits .-> docker
  routerD -. no VPS listener .-> routerSplit
```

## VPS Role In The Channel Setup

| Channel / surface | VPS responsibility | Owner on VPS | Guardrail |
|---|---|---|---|
| Channel A managed egress | Provides remote Reality/Vision egress surface behind public HTTPS routing | routing project | PraefectusAI records ports and host health; it does not own routing config |
| Channel B selected-client lane | Provides local Xray/XHTTP backend and reverse-proxy exposure where configured | routing project | local-only backend ports; public exposure only through documented reverse proxy |
| Channel C home-first compatibility | VPS is not the first hop; it remains the managed egress after router split | routing project | no extra public VPS listener beyond documented HTTPS surface |
| Channel D router-native NaiveProxy | No VPS listener; first hop is home router WAN to router Caddy `forward_proxy@naive` | `router_configuration` | `4444/tcp` must not appear on the VPS or in UFW/cloud firewall |
| Channel M reverse MAX egress | Hosts the Docker-bridge-scoped SSH reverse listener consumed by `maxtg_bridge` | `router_configuration` / `maxtg_bridge` | `18057/tcp` must bind only on the Docker bridge, with watchdog timers active |
| GhostRoute Console | Read-only operator UI served by dedicated `2087/tcp` and optionally by host/SNI on `443/tcp` | routing / app owner | PraefectusAI records exposure, health and port inventory only |

## Host-Owned Runtime Objects

| Area | Runtime objects | Installed or rendered by | Verification signal |
|---|---|---|---|
| SSH access | `/etc/ssh/`, `/home/deploy/.ssh/authorized_keys` | `00-bootstrap.yml`, `40-security.yml`, Vault-backed SSH helpers | direct SSH check, MaxSessions check, scoped Channel M key preserved |
| Firewall | UFW rules, provider allowlist outside repo, Channel M non-UFW iptables exception | `40-security.yml`, `router_configuration` for Channel M exception | UFW active, public ports match `docs/ports.md`, `18057` not public |
| Docker host | Docker Engine, Compose plugin, `/var/lib/docker` | bootstrap and host maintenance playbooks | Docker active, no current-boot ordering cycle; filtered cleanup only; volumes never pruned automatically |
| Monitoring | `/usr/local/bin/vps-monitor.py`, systemd timer | `20-monitoring.yml` | 5-minute health checks and Telegram alerting |
| Cleanup | `/usr/local/bin/vps-periodic-cleanup.sh`, `vps-cleanup.timer` | `11-periodic-cleanup-setup.yml` | apt/journal/docker cleanup with retention filters; no volume prune |
| Backups | restic config/timers, app-data backup paths | `30-backup.yml` | backup timer/status checks; encrypted remote snapshots |
| Syncthing | Syncthing service and config under deploy home | PraefectusAI host layer | public sync/discovery ports documented; Web UI loopback-only |
| App resource policy | `docker-compose.override.local.yml` beside app compose files | `60-docker-limits.yml`, `70-docker-limits-critical.yml` | Docker inspect and verify reports show memory/CPU/PID limits |

## Cross-Project Runtime Objects

| Runtime object | Location | Owner | PraefectusAI stance |
|---|---|---|---|
| Host reverse proxy config | `/etc/caddy/` or `/etc/nginx/` | app/routing project | record and audit; do not overwrite |
| GhostRoute Console container/app | app-owned Docker runtime | routing/app owner | verify listener and health; do not deploy app internals |
| Xray / routing local backends | local loopback ports, routing containers | routing project | record ports; no config ownership |
| `maxtg_bridge` app | `/opt/maxtg-bridge/` | `maxtg_bridge` | host limits/backups only; app compose/env remain app-owned |
| Channel M SSH policy | `/etc/ssh/sshd_config.d/51-channel-m-reverse.conf` | `router_configuration` | preserve during SSH hardening; verify file exists |
| Channel M firewall helper | `/usr/local/sbin/channel-m-reverse-firewall.sh` | `router_configuration` | preserve; verify helper and timer |
| Channel M stale-listener watchdog | `/usr/local/sbin/channel-m-reverse-listener-watchdog.sh` | `router_configuration` | preserve; verify helper and timer |

## Host Scope

| Inventory host | Runtime role | Channel-specific guardrails |
|---|---|---|
| `vps-hetzner-prod` | `maxtg_bridge`, Fluentloop, GhostRoute Console, Xray and XHTTP; OpenClaw-era Gateway/OmniRoute/LightRAG and bridge services are retired | Channel M files/timers and restricted `18057/tcp` listener expected; `4444/tcp` absent; no legacy app listeners expected |
| `vps-hostkey-hermes` | My AI Office plus independent `reddit-compass`, `moex-futoi`, `cheap-intelligence`, Career Copilot, maxtg watchdog and GhostRoute projects | 13-service office under `/opt/benka-hermes`; panel on `8451`; Career Copilot on loopback `8100`/`8445`; no Channel M listener; `4444/tcp` absent |

## My AI Office on the Hermes host

`my-ai-office` owns the `benka-hermes` Compose project in `/opt/benka-hermes`.
It is an application workload, not a host service: PraefectusAI records its
expected containers, checks that they are running, protects its host-level
resource envelope, audits the listener, and configures the designated backup
scope; the current coverage gap is recorded below. It
does not start, stop, recreate, reconfigure, or inspect the application's
private manifests, credentials, queues, or volumes outside the approved backup
path.

```text
Telegram / Hermes CLI / authenticated browser
                 │
                 ▼
benka-hermes-caddy-1  (8451, TLS + mTLS)
                 │
                 ▼
gateway + dashboard  ──► domain profiles and native Benka tools
                 │
Hermes cron ──► Redis Streams  ──► six dedicated workers
                 │                       │
                 ├──► wiki / LightRAG / private archive
                 └──► allowlisted Telegram delivery + receipts
```

The integration bus is **`benka-hermes-redis-1`**. There is no separate
`integration-bus` container: Redis Streams holds job queues, consumer groups,
deduplication keys, delivery receipts, and reconciliation records. The six
workers serve personal mail, work mail, Telegram Digest, Signals, Last30Days,
and wiki/LightRAG maintenance. `reddit-compass` is a neighbouring Compose
project; it is not the office's Redis bus and is not the Last30Days Reddit
source adapter.

| Office area | Expected containers | VPS-management boundary |
|---|---|---|
| Panel edge | `benka-hermes-caddy-1` | One host-published listener on `8451`; Caddy's TLS/mTLS and dashboard authentication remain app-owned. |
| Agent access | `benka-hermes-gateway-1`, `benka-hermes-dashboard-1` | Gateway is the sole production Telegram polling owner; dashboard shares its agent runtime boundary. |
| Execution | `benka-hermes-redis-1` and six `benka-hermes-worker-*` containers | Record health and restart evidence. Do not replay streams or restart workers automatically. |
| Knowledge and routing | `benka-hermes-wiki-1`, `benka-hermes-lightrag-1`, `benka-hermes-omniroute-1` | Keep the application state intact; changes to embeddings, models, indexes, or provider configuration belong to `my-ai-office`. |
| Durable state | `/opt/benka-hermes/production/cutover-20260906/state` | Actual bind-mount root, including private data. Desired encrypted backup source; absent from the installed backup script. Do not read, copy to Git, recursively `chown` or prune application state. |
| Career Copilot dashboard | `career-copilot-dashboard` in `/opt/career-copilot` | Application-owned; read-only workspace from `/opt/career-copilot/workspace`, loopback `8100`. The workspace is backed up; the separate durable request/check volume is configured but awaiting backup deployment. |
| Career Copilot gateway | `career-copilot-gateway` | Application-owned Caddy TLS + Basic Auth on loopback `8445`; public through the routing-owned exact-SNI route on `443`. Docker health and current bindings were checked on 2026-11-13. |

## Installed Software Versions

Qualified host maintenance on 2026-11-15. The role-only machine-readable
[software inventory](../configs/software-inventory.json) separates observed
runtime versions, application ownership and explicit compatibility holds.

| Component | `vps-hetzner-prod` | `vps-hostkey-hermes` |
|---|---|---|
| OS family | Ubuntu 24.04 LTS | Ubuntu 22.04 LTS |
| Docker Engine | `29.9.3` | `29.9.3` |
| Docker Compose | `5.7.1` | `5.7.1` |
| containerd | `2.4.2` | `2.4.2` |
| Owned routing edge Caddy | `2.11.9` | `2.11.9` |
| Owned routing Xray | `26.11.9` | `26.6.1` compatibility hold |

Both hosts completed the approved reboot; no reboot-required marker remained
at verification. Host maintenance preserved the routing-owned Docker service
guard. The sensitive role retained its earlier panel/core after newer REALITY
failed authenticated application HTTPS with existing clients; its routing owner
pins the exact qualified image digest. Configuration syntax alone is not a
compatibility gate. Other application Caddy images and persistent BuildKit
workers remain under their application owners and were not upgraded here.

### Historical package baseline — 2026-06-13

The table below is the older `vps-hetzner-prod` package snapshot, not current
fleet assertions. Individual package versions were not re-audited in November.
This table records only software identity and version data. It intentionally
excludes public IPs, SSH values, provider firewall state, app tokens and live
endpoint URLs.

| Component | Observed version | Source |
|---|---|---|
| OS | Ubuntu `24.04.4 LTS` | `/etc/os-release` |
| Linux kernel | `6.8.0-117-generic` | `uname -r` |
| systemd | `255` (`255.4-1ubuntu8.16`) | `systemctl --version` |
| Docker Engine | `29.3.1`, build `c2be9cc` | `docker --version` |
| Docker Compose plugin | `v5.1.1` | `docker compose version` |
| OpenSSH client/server | `9.6p1 Ubuntu-3ubuntu13.16`, OpenSSL `3.0.13` | `ssh -V`, `sshd -V` |
| UFW | `0.36.2` | `ufw version` |
| Fail2Ban | `1.0.2` | `fail2ban-client --version` |
| Caddy | `v2.11.1` | `caddy version`; checksum omitted from docs |
| nginx | `1.24.0` (Ubuntu) | `nginx -v` |
| Syncthing | `1.30.0` | `syncthing --version` |
| restic | `0.16.4` | `restic version` |
| Python | `3.12.3` | `python3 --version` |
| iptables | `1.8.10` (`nf_tables`) | `iptables --version` |
| nftables | `1.0.9` | `nft --version` |

Treat this as a baseline for the referenced host, not a fleet-wide assertion.
Record a new snapshot after OS, Docker, reverse-proxy or Syncthing upgrades.

## Channel M Reverse MAX Egress

```mermaid
sequenceDiagram
  participant Bridge as maxtg_bridge container
  participant Host as VPS Docker bridge gateway
  participant Listener as OpenSSH reverse listener
  participant Router as Home router loopback proxy
  participant WAN as Home WAN
  participant MAX as MAX API/CDN

  Bridge->>Host: HTTP CONNECT to proxy host mapped by extra_hosts
  Host->>Listener: bridge-scoped TCP listener on restricted port
  Listener->>Router: SSH remote-forward opened by router
  Router->>WAN: sing-box Channel M reverse inbound -> direct-out
  WAN->>MAX: request exits from home WAN
```

The VPS must not expose Channel M publicly. `99-verify.yml` checks that the
listener is present only as a restricted Docker-bridge listener, that the
firewall helper/timer are active, and that the listener watchdog timer is active.

## Exposure Model

```mermaid
flowchart TB
  public[Public internet]
  restricted[Specific source networks / Docker bridge]
  loopback[127.0.0.1 only]
  absent[Must be absent on VPS]

  public --> p22[22/tcp SSH allowlisted]
  public --> p80[80/tcp HTTP redirect / ACME]
  public --> p443[443/tcp HTTPS and host/SNI Console fallback]
  public --> p2087[2087/tcp dedicated Console listener]
  public --> psync[21027/udp and 22000/tcp+udp Syncthing]

  restricted --> p18057[18057/tcp Channel M reverse listener]
  restricted --> p15353[15353/tcp+udp optional internal DNS]

  loopback --> localApps[app APIs, reverse-proxy admin, Xray backends]
  loopback --> careerCopilot[Career Copilot dashboard<br/>127.0.0.1:8100 via SSH tunnel]
  p443 -->|exact SNI| careerGateway[Career Copilot gateway<br/>127.0.0.1:8445 TLS + Basic Auth]
  careerGateway --> careerCopilot
  absent --> p4444[4444/tcp Channel D router-owned listener]
```

Public-by-design exceptions are documented in `docs/ports.md`. Everything else
should be loopback-only, bridge-scoped, source-restricted or absent.

## Test Schemes

```mermaid
flowchart LR
  static[Static checks<br/>syntax, docs, secret-scan]
  verify[Read-only verify<br/>99-verify.yml / verify.sh]
  ports[Port audit<br/>live ss vs docs/ports.md]
  channelM[Channel M proof<br/>bridge listener + timers + proxy validation]
  exposure[Exposure review<br/>public/restricted/private/absent]

  static --> verify --> ports --> channelM --> exposure

  verify -->|pass| ok[Host guardrails match expected inventory]
  verify -->|fail| drift[Read failing assertion and owner]
  ports -->|new public bind| drift
  channelM -->|public 18057 or stale listener| incident[Channel M exposure incident]
  drift --> owner[Coordinate with PraefectusAI, app owner or router_configuration]
```

```mermaid
flowchart TB
  subgraph channelProof[Channel-supporting VPS proof matrix]
    a[Channels A/B/C managed egress]
    d[Channel D absence on VPS]
    m[Channel M reverse service egress]
    console[GhostRoute Console exposure]
  end

  subgraph expected[Expected evidence]
    https[443 answers expected reverse-proxy/TLS surface]
    localBackends[Routing backends stay local/private]
    no4444[No 4444 VPS listener or firewall allow]
    bridge18057[18057 is Docker-bridge scoped only]
    timers[Channel M firewall/watchdog timers active]
    consolePorts[Console reachable on configured 2087 and optional 443 host/SNI path]
  end

  a --> https
  a --> localBackends
  d --> no4444
  m --> bridge18057
  m --> timers
  console --> consolePorts
```

Interpretation:

- A/B/C proof on the VPS is about the remote egress/reverse-proxy surface and
  local backend exposure. The router remains the first-hop policy owner for
  home-first channels.
- Channel D proof on the VPS is negative: no `4444/tcp`, no UFW/cloud allow, no
  expected VPS listener.
- Channel M proof is positive but restricted: `18057/tcp` exists only on the
  compose Docker bridge path, with router-owned firewall and stale-listener
  recovery active.
- Console proof is read-only operator access: standard HTTPS can host/SNI route
  to the Console, while `2087/tcp` remains the documented dedicated listener.

## Read-Only Verification Checklist

```bash
./verify.sh --limit vps-hetzner-prod
./modules/port-audit/bin/port-audit --host vps-hetzner-prod
cd ansible
ansible-playbook --syntax-check playbooks/99-verify.yml
```

Expected healthy signals:

- Disk, memory, Docker daemon and UFW checks are OK or explained by the health
  report.
- Expected Channel M host files exist and are owned by the routing project.
- `channel-m-reverse-firewall.timer` and
  `channel-m-reverse-listener-watchdog.timer` are enabled and active.
- `18057/tcp` is restricted to the Docker bridge and never public.
- `4444/tcp` is absent from the VPS listener set.
- App API ports remain loopback/private unless intentionally documented as
  public in `docs/ports.md`.

If a live check disagrees with this map, treat it as drift evidence. Identify
the owner first, then choose the right repo/playbook; do not edit app-owned
compose files or routing-owned reverse-proxy config from PraefectusAI.

## Related Docs

- [`architecture.md`](/docs/architecture.md) - host-vs-app model and channel runtime schemes.
- [`ports.md`](/docs/ports.md) - canonical port map and `port-audit` source of truth.
- [`firewall.md`](/docs/firewall.md) - UFW and non-UFW Channel M exception model.
- [`containers.md`](/docs/containers.md) - container inventory and resource limits.
- [`ownership-matrix.md`](/docs/ownership-matrix.md) - path ownership and modification boundaries.
- [`runbooks/ssh-breakglass-bastion.md`](/docs/runbooks/ssh-breakglass-bastion.md) - SSH route recovery.
- [`runbooks/disk-full.md`](/docs/runbooks/disk-full.md) - safe cleanup flow.
