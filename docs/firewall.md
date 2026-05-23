# Firewall rules — UFW

Current state of the UFW firewall. Update when rules change.

> Real IPs live in `vault.yml`. This document uses placeholders.

---

## Current rules (template / example)

```
# sudo ufw status numbered
Status: active

     To                         Action      From
     --                         ------      ----
[ 1] 22/tcp                     ALLOW IN    <operator-home-ip>         # SSH from operator home
[ 2] 22/tcp                     ALLOW IN    <work-ip>                  # SSH from work
[ 3] 80/tcp                     ALLOW IN    Anywhere                   # HTTP for ACME
[ 4] 443/tcp                    ALLOW IN    Anywhere                   # HTTPS
[ 5] 22000/tcp                  ALLOW IN    Anywhere                   # Syncthing data TCP
[ 6] 22000/udp                  ALLOW IN    Anywhere                   # Syncthing data QUIC
[ 7] 21027/udp                  ALLOW IN    Anywhere                   # Syncthing discovery
[ 8] 22/tcp                     ALLOW IN    <operator-home-ip-2>       # SSH from operator (alt)
[ 9] 22/tcp                     ALLOW IN    <trusted-ip-1>             # additional trusted SSH
[10] 22/tcp                     ALLOW IN    <trusted-ip-2>
[11] 53/tcp                     DENY IN     Anywhere                   # block public DNS
[12] 53/udp                     DENY IN     Anywhere
[13] 22/tcp                     ALLOW IN    <bastion-ip>               # bastion SSH
[14] 15353/tcp                  ALLOW IN    172.22.0.0/16              # internal resolver from Docker bridge
[15] 15353/udp                  ALLOW IN    172.22.0.0/16
[16] 2087/tcp                   ALLOW IN    Anywhere                   # admin console HTTPS (Caddy front)
[17] 443/tcp                    ALLOW OUT   Anywhere                   (out)
[18] 53                         ALLOW OUT   Anywhere                   (out)
[19] 80/tcp (v6)                ALLOW IN    Anywhere (v6)              # HTTP for ACME
[20] 443/tcp (v6)               ALLOW IN    Anywhere (v6)
[21] 22000/tcp (v6)             ALLOW IN    Anywhere (v6)              # Syncthing data TCP
[22] 22000/udp (v6)             ALLOW IN    Anywhere (v6)              # Syncthing data QUIC
[23] 21027/udp (v6)             ALLOW IN    Anywhere (v6)              # Syncthing discovery
[24] 53/tcp (v6)                DENY IN     Anywhere (v6)
[25] 53/udp (v6)                DENY IN     Anywhere (v6)
[26] 2087/tcp (v6)              ALLOW IN    Anywhere (v6)              # admin console HTTPS
[27] 443/tcp                    ALLOW OUT   Anywhere (v6)              (out)
[28] 53 (v6)                    ALLOW OUT   Anywhere (v6)              (out)
```

---

## Rationale

| Port | Protocol | Why open | Owner |
|---|---|---|---|
| 22 | TCP | SSH from allowlisted IPs (multiple rules) | PraefectusAI |
| 80 | TCP | HTTP → HTTPS redirect, ACME challenge | application owner (reverse proxy) |
| 443 | TCP | HTTPS + multiplexed protocols on 443 | application owner |
| 2087 | TCP | Admin console HTTPS (front-ended by reverse proxy) | application owner |
| 21027 | UDP | Syncthing discovery protocol | PraefectusAI |
| 22000 | TCP+UDP | Syncthing peer sync (control machine ↔ VPS) | PraefectusAI |
| 53 | TCP+UDP | **DENY IN** — VPS must never serve as a public DNS resolver | PraefectusAI |
| 15353 | TCP+UDP | Internal DNS resolver — only reachable from a defined Docker bridge | application owner |
| 18057 | TCP | Channel M reverse MAX egress listener — reachable only from the compose Docker bridge; not a UFW public allow | router_configuration / maxtg_bridge |
| 443, 53 | OUT | Outbound HTTPS and DNS — needed for apt, restic backups, ACME | PraefectusAI |

**Everything else — DROP** (UFW default deny incoming).

### Non-UFW host rules

Channel M reverse MAX egress installs a narrow host-level `iptables` INPUT allow
for the compose Docker bridge subnet to reach the Docker bridge gateway on
`18057/tcp`. This rule is managed by `router_configuration` through:

- `/usr/local/sbin/channel-m-reverse-firewall.sh`
- `channel-m-reverse-firewall.service`
- `channel-m-reverse-firewall.timer`

It must stay bridge-scoped. Do not add `18057/tcp` to public UFW rules or cloud
firewall rules.

---

## What's intentionally **not** open via UFW

| Port | Service | Why closed |
|---|---|---|
| 8384 | Syncthing Web UI | `127.0.0.1` only; access via SSH tunnel |
| 9100 | `node_exporter` (future) | `127.0.0.1` only |
| Application APIs | each application's HTTP/RPC | `127.0.0.1` only; routed via reverse proxy if exposed |

---

## Managing UFW

```bash
# View rules
ssh deploy@<vps> 'sudo ufw status numbered'

# Verify UFW is active
ssh deploy@<vps> 'sudo ufw status | head -1'

# DANGER: ufw disable closes SSH if you have no rescue path!
# Never run without a working rescue (provider console, bastion).
```

### SSH allowlist and VPN changes

SSH is allowlisted by source IP. If the operator switches to a third-party VPN, mobile hotspot, office network, or any other route with a new egress IP, direct SSH may fail even when the VPS is healthy. Before depending on a new route:

1. Add the new source IP to the VPS SSH allowlist and any provider firewall allowlist.
2. Verify direct SSH from that network: `./ansible/scripts/ssh-vps.sh 'echo OK'`.
3. Keep a rescue path available before changing rules — bastion, provider console (e.g. Hetzner Cloud Console / AWS EC2 Console / DigitalOcean web terminal).

Never replace the SSH allowlist with `Anywhere` as a convenience shortcut.

---

## Emergency access

If UFW has locked you out of SSH:

1. Open the provider's web console (e.g. Hetzner Cloud Console, AWS EC2 Console, DigitalOcean web terminal).
2. `sudo ufw disable` → SSH access is restored.
3. Re-add the rule that was missing, then re-enable: `sudo ufw allow 22/tcp && sudo ufw enable`.
