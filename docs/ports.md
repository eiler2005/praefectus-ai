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
| 443 | TCP | HTTPS | system (caddy / nginx) | application owner | TLS handshake |
| 22000 | TCP | Syncthing sync | system (syncthing) | PraefectusAI | TCP connect |
| 22000 | UDP | Syncthing sync (QUIC) | system (syncthing) | PraefectusAI | UDP connect |
| 21027 | UDP | Syncthing discovery | system (syncthing) | PraefectusAI | UDP connect |

## Restricted ports (specific source networks only)

Ports that must be reachable only from a defined source network (Docker bridge, VPN, etc.).

| Port | Protocol | Service | Source | Owner | Note |
|---|---|---|---|---|---|
| 15353 | TCP+UDP | Internal DNS resolver (Unbound) | 172.22.0.0/16 (Docker bridge) | application owner | Optional; UFW rule remains for diagnostics |

## Private ports (`127.0.0.1` — internal only)

Ports bound to the loopback interface only. Reachable from the VPS itself or via SSH tunnel.

| Port | Protocol | Service | Container | Owner | Healthcheck |
|---|---|---|---|---|---|
| 8384 | TCP | Syncthing Web UI | system (syncthing) | PraefectusAI | `curl /rest/system/ping` |
| `<app port>` | TCP | application API | `<application container>` | application owner | `GET /health` |

Replace `<app port>` rows with your own services.

## Internal Docker networks (not reachable from host)

| Service | Network | Internal port | Note |
|---|---|---|---|
| redis (example) | application_default | 6379 | available only inside the network |

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
