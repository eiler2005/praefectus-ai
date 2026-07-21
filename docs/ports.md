# Port map

Canonical table of every network port on the VPS. Update when adding or removing services.

> This file is the source of truth for [`port-audit`](../modules/port-audit/bin/port-audit). When the audit reports a discrepancy, either update the live state or update this file — whichever is correct.

**Tool:** `./modules/port-audit/bin/port-audit`

---

## Public ports (`0.0.0.0` / `::`)

Ports intentionally exposed to the public internet.

| Port | Protocol | Service | Process / container | Owner | Healthcheck |
|---|---|---|---|---|---|
| 22 | TCP | sshd | system (sshd) | PraefectusAI | `nc -z <host> 22` |
| 80 | TCP | HTTP → HTTPS redirect, ACME challenge | system (caddy / nginx) | application owner | `curl -I http://<host>/` |
| 443 | TCP | HTTPS + SNI-routed routing surfaces; Hermes owned egress uses Caddy layer4 | system or container Caddy | application owner / routing project | TLS handshake |
| 2087 | TCP | Admin console dedicated HTTPS listener | system reverse proxy | application owner / routing project | TLS handshake |
| 22000 | TCP | Syncthing sync | system (syncthing) | PraefectusAI | TCP connect |
| 22000 | UDP | Syncthing sync (QUIC) | system (syncthing) | PraefectusAI | UDP connect |
| 21027 | UDP | Syncthing discovery | system (syncthing) | PraefectusAI | UDP connect |

## Restricted ports (specific source networks only)

Ports that must be reachable only from a defined source network (Docker bridge, VPN, etc.).

| Port | Protocol | Service | Source | Owner | Note |
|---|---|---|---|---|---|
| 15353 | TCP+UDP | Internal DNS resolver (Unbound) | 172.22.0.0/16 (Docker bridge) | application owner | Optional; UFW rule remains for diagnostics |
| 18057 | TCP | Channel M reverse MAX egress listener | compose Docker bridge only | router_configuration / maxtg_bridge | Internal SSH remote-forward endpoint; guarded by firewall + stale-listener watchdog; not public UFW/cloud-firewall exposure |

## Private ports (`127.0.0.1` — internal only)

Ports bound to the loopback interface only. Reachable from the VPS itself or via SSH tunnel.

| Port | Protocol | Service | Container | Owner | Healthcheck |
|---|---|---|---|---|---|
| 53 | TCP | systemd-resolved local DNS stub | system | PraefectusAI | local resolver check |
| 2019 | TCP | reverse proxy admin endpoint | system reverse proxy | application owner | local admin only |
| 3000 | TCP | GhostRoute Console | `ghostroute-console` | application owner | app health/API |
| 3001 | TCP | companion local app endpoint | application container | application owner | app health/API |
| 8384 | TCP | Syncthing Web UI | system (syncthing) | PraefectusAI | `curl /rest/system/ping` |
| 8020 | TCP | LightRAG app | `lightrag-lightrag-1` | application owner | app health/API |
| 8080 | TCP | Cheap Intelligence digest API | `ci-digest` | `AiNativeBook_Draft_26/services/digest-service` | `/healthz`; admin only over SSH/loopback |
| 8092 | TCP | AgentMail email bridge | `agentmail-email-bridge` | application owner | app health/API |
| 8093 | TCP | Signals bridge | `signals-bridge` | application owner | app health/API |
| 8094 | TCP | AgentMail work email bridge | `agentmail-work-email-bridge` | application owner | app health/API |
| 8095 | TCP | Wiki import app | `wiki-import` | application owner | app health/API |
| 8443 | TCP | Xray local backend | `xray` | routing project | local reverse-proxy/backend check |
| 8444 | TCP | Cheap Intelligence inner TLS | `ci-caddy-inner` | `AiNativeBook_Draft_26/services/digest-service` | exact-SNI upstream from outer Caddy; container health on internal `:8081` |
| 18081 | TCP | Channel B/XHTTP local backend | `xray-xhttp` | routing project | local backend check |
| 18789 | TCP | OpenClaw gateway | `openclaw-openclaw-gateway-1` | application owner | app health/API |
| 18790 | TCP | OpenClaw gateway companion port | `openclaw-openclaw-gateway-1` | application owner | app health/API |
| 20128 | TCP | OmniRoute app endpoint | `omniroute` | application owner | app health/API |
| 20129 | TCP | OmniRoute companion endpoint | `omniroute` | application owner | app health/API |
| 54321 | TCP | Xray API/local control endpoint | `xray` | routing project | local control only |

Replace `<app port>` rows with your own services.

## Internal Docker networks (not reachable from host)

| Service | Network | Internal port | Note |
|---|---|---|---|
| redis (example) | application_default | 6379 | available only inside the network |
| maxtg bridge | deploy_default | bridge container reaches host gateway on 18057 | reverse Channel M maps proxy host to the Docker bridge gateway with `extra_hosts` |

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
