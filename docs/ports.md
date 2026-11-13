# Port map

Canonical active port map across both VPS hosts, reconciled on 2026-11-13.
Update when adding or removing services. SSH access coordinates remain in Vault;
any additional Vault-defined SSH listener is not published in this table.

> This file is the source of truth for [`port-audit`](../modules/port-audit/bin/port-audit). When the audit reports a discrepancy, either update the live state or update this file — whichever is correct.

**Tool:** `./modules/port-audit/bin/port-audit`

The tables are a fleet-wide union, not a promise that every listener exists on
both hosts. `port-audit` currently does not scope missing-port checks by host;
interpret those lines against the host scope below. It also cannot establish
provider/firewall source restrictions from bind addresses alone.

- Hetzner: public `80`, `443`, `2087`, Syncthing; private Console `3000`/`3001`,
  Xray `8443`/`18081`/`54321`, proxy admin `2019`, Syncthing UI `8384`, bridge
  status `18140`; restricted Channel M `18057` and resolver `15353`.
- Hermes: public `80`, `443`, Reddit `8450`, office `8451`; private digest
  `8080`/`8444`, Career Copilot `8100`/`8445`, Reddit `8900`/`8901`, Xray
  `8443`/`54321`, resolver control `8953`; resolver `15353` and restricted
  watchdog receiver `18151`.
- Hetzner resolver `15353` also binds a host interface, not only Docker/loopback.
  Hermes watchdog `18151` binds all IPv4 interfaces. Source restriction remains
  a firewall/provider verification item; these observations do not establish
  safe public reachability. Do not broaden their intended source contracts.

---

## Public ports (`0.0.0.0` / `::`)

Ports intentionally exposed to the public internet.

| Port | Protocol | Service | Process / container | Owner | Healthcheck |
|---|---|---|---|---|---|
| 22 | TCP | sshd | system (sshd) | PraefectusAI | `nc -z <host> 22` |
| 80 | TCP | HTTP → HTTPS redirect, ACME challenge | system (caddy / nginx) | application owner | `curl -I http://<host>/` |
| 443 | TCP | HTTPS + SNI-routed routing surfaces; Hermes owned egress uses Caddy layer4 with exact-SNI app routes (Cheap Intelligence digest → `8444`, Career Copilot → `8445`) | system or container Caddy | application owner / routing project | TLS handshake |
| 2087 | TCP | Admin console dedicated HTTPS listener | system reverse proxy | application owner / routing project | TLS handshake |
| 22000 | TCP | Syncthing sync | system (syncthing) | PraefectusAI | TCP connect |
| 22000 | UDP | Syncthing sync (QUIC) | system (syncthing) | PraefectusAI | UDP connect |
| 21027 | UDP | Syncthing discovery | system (syncthing) | PraefectusAI | UDP connect |
| 8450 | TCP | Reddit Compass authenticated web surface | `rc-caddy` | `reddit_compass` | HTTPS response through the app-owned Caddy |
| 8451 | TCP | My AI Office Hermes dashboard | `benka-hermes-caddy-1` | `my-ai-office` | TLS handshake; access additionally requires a trusted client certificate and dashboard authentication |

## Restricted ports (specific source networks only)

Ports that must be reachable only from a defined source network (Docker bridge, VPN, etc.).

| Port | Protocol | Service | Source | Owner | Note |
|---|---|---|---|---|---|
| 15353 | TCP+UDP | Internal DNS resolver (Unbound) | 172.22.0.0/16 (Docker bridge) | application owner | Optional; UFW rule remains for diagnostics |
| 18057 | TCP | Channel M reverse MAX egress listener | compose Docker bridge only | router_configuration / maxtg_bridge | Internal SSH remote-forward endpoint; guarded by firewall + stale-listener watchdog; not public UFW/cloud-firewall exposure |
| 18151 | TCP | maxtg-bridge external watchdog push receiver | production host `/32` only | `maxtg_bridge` | HMAC-signed status snapshots; UFW on the observer host plus a matching outbound rule in the production host's cloud firewall |

## Private ports (`127.0.0.1` — internal only)

Ports bound to the loopback interface only. Reachable from the VPS itself or via SSH tunnel.

| Port | Protocol | Service | Container | Owner | Healthcheck |
|---|---|---|---|---|---|
| 8100 | TCP | Career Copilot private dashboard | `career-copilot-dashboard` | `career-copilot` | `GET http://127.0.0.1:8100/healthz`; SSH tunnel via local port 18100 |
| 8445 | TCP | Career Copilot HTTPS gateway (TLS + Basic Auth) | `career-copilot-gateway` | `career-copilot` | exact-SNI upstream from GhostRoute outer Caddy on `:443`; Docker healthcheck on internal `:8081` |
| 53 | TCP | systemd-resolved local DNS stub | system | PraefectusAI | local resolver check |
| 2019 | TCP | reverse proxy admin endpoint | system reverse proxy | application owner | local admin only |
| 3000 | TCP | GhostRoute Console | `ghostroute-console` | application owner | app health/API |
| 3001 | TCP | companion local app endpoint | application container | application owner | app health/API |
| 8384 | TCP | Syncthing Web UI | system (syncthing) | PraefectusAI | `curl /rest/system/ping` |
| 8080 | TCP | Cheap Intelligence digest API | `ci-digest` | `AiNativeBook_Draft_26/services/digest-service` | `/healthz`; admin only over SSH/loopback |
| 8443 | TCP | Xray local backend | `xray` | routing project | local reverse-proxy/backend check |
| 8444 | TCP | Cheap Intelligence inner TLS | `ci-caddy-inner` | `AiNativeBook_Draft_26/services/digest-service` | exact-SNI upstream from outer Caddy; container health on internal `:8081` |
| 18140 | TCP | maxtg-bridge read-only status API | `deploy-bridge-1` | `maxtg_bridge` | `GET /healthz`; `GET /status` needs a bearer token. Reached from outside only through the watchdog's SSH channel |
| 18081 | TCP | Channel B/XHTTP local backend | `xray-xhttp` | routing project | local backend check |
| 8900 | TCP | Reddit Compass local UI | `rc-caddy` | `reddit_compass` | Hermes; loopback only, monitored by inventory guardrail |
| 8901 | TCP | Reddit Compass direct API | `rc-api` | `reddit_compass` | Hermes; loopback only, monitored by inventory guardrail |
| 8953 | TCP | Unbound control | host `unbound` | `router_configuration` | Hermes; loopback only |
| 54321 | TCP | Xray API/local control endpoint | `xray` | routing project | local control only |

## Internal Docker networks (not reachable from host)

| Service | Network | Internal port | Note |
|---|---|---|---|
| maxtg bridge | deploy_default | bridge container reaches host gateway on 18057 | reverse Channel M maps proxy host to the Docker bridge gateway with `extra_hosts` |
| My AI Office | benka-hermes internal network | Redis `6379`, LightRAG `9621`, OmniRoute `20128`, Gateway dashboard `9119` | Docker-only service ports. Caddy on `8451` is the sole host-published listener for this Compose project. |

## Retired Hetzner listeners — historical reference

These are absent from the active listener expectations. Legacy OpenClaw-era
services require owner-approved recovery from the recorded archives before reuse.

| Ports | Former workload | Status |
|---|---|---|
| 8020 | Legacy LightRAG | Retired; data archived off-host |
| 8092–8095 | Legacy email, signals and wiki bridges | Retired standalone containers |
| 18789–18790 | OpenClaw Gateway | Disabled since September; heavy state archived in November |
| 20128–20129 | Legacy OmniRoute | Retired Hetzner runtime; volume archived and removed. Hermes office `20128` remains Docker-internal |

## External router-owned ports (not VPS listeners)

These ports belong to other network devices/projects and must not be added to the VPS expected listener set.

| Port | Protocol | Service | Location | Owner | VPS rule |
|---|---|---|---|---|---|
| 4444 | TCP | Channel D router-native NaiveProxy lane | home router WAN -> router Caddy `forward_proxy@naive` -> router-local SOCKS | router_configuration | Do not open on VPS UFW/cloud firewall; `port-audit` should not expect it |

---

## Port range conventions

A simple range allocation makes new services predictable.

| Range | Use |
|---|---|
| 8100–8199 | application services (group A) |
| 9100–9199 | monitoring (`node_exporter`, future) |
| 18000–18999 | application internal APIs |
| 20000–20999 | AI routing / dashboards |

---

## Unsafe bindings — what should never appear

The following ports must be bound to `127.0.0.1` only, never to `0.0.0.0`:

- All application API ports (any port from a container that doesn't need public exposure)
- 8384 (Syncthing Web UI)
- 18057 must stay on a Docker bridge address only; a public bind is an incident.
- 4444 must not appear on the VPS at all; it is a home-router Channel D listener.

If `ss -tlnp` shows `0.0.0.0` for any of these, that is an immediate incident.

**Public-by-design exceptions:** 22, 80, 443, 21027, 22000.

---

## How to verify

```bash
# Standalone audit (compares live state with this file)
./modules/port-audit/bin/port-audit

# Show live listeners only
./modules/port-audit/bin/port-audit --live-only

# Save snapshot
./modules/port-audit/bin/port-audit --save
```

```bash
# Manual check on the VPS
ssh deploy@<vps> 'ss -tlnp'                                          # TCP listeners
ssh deploy@<vps> 'ss -ulnp'                                          # UDP listeners
ssh deploy@<vps> 'docker ps --format "table {{.Names}}\t{{.Ports}}"' # container ports
```
