# Architecture

## Principle: host vs application ownership

PraefectusAI manages the **host**. Application owners manage **their applications**.

This split lets you:

- Migrate gradually — no need to rewrite every project's deploy at once.
- Answer "who deployed this?" deterministically — see [`ownership-matrix.md`](ownership-matrix.md).
- Automate host maintenance (disk, monitoring, security) without risking application data.

## Layers

```
┌──────────────────────────────────────────────────────────────┐
│  L4: Application data                                         │
│  /opt/<app>/{data,workspace,config}                           │
│  Owner: application project. PraefectusAI handles backup only.│
├──────────────────────────────────────────────────────────────┤
│  L3: Application runtime                                      │
│  /opt/<app>/docker-compose.yml + images                       │
│  Owner: application project. PraefectusAI does not touch.     │
│  Override files (override.local.yml for limits) — our zone.   │
├──────────────────────────────────────────────────────────────┤
│  L2: Container runtime + system services                      │
│  Docker daemon, sshd, ufw, fail2ban, systemd                  │
│  Owner: PraefectusAI.                                         │
├──────────────────────────────────────────────────────────────┤
│  L1: Host OS                                                  │
│  Linux distro packages, /var/log, /var/lib, sysctl            │
│  Owner: PraefectusAI.                                         │
├──────────────────────────────────────────────────────────────┤
│  L0: Hardware / cloud provider                                │
│  Hetzner / AWS / DigitalOcean (instance, IP, snapshots)       │
│  Owner: operator via provider console.                        │
└──────────────────────────────────────────────────────────────┘
```

## What PraefectusAI does

- **Bootstrap** — `00-bootstrap.yml` brings a fresh VM to a known baseline state: Docker Engine, Compose plugin, `deploy` user, SSH key, and sudo.
- **Maintenance** — `10-disk-cleanup.yml`, `11-periodic-cleanup-setup.yml`, `20-monitoring.yml`, `30-backup.yml`, `40-security.yml`.
- **Limits** — `60-docker-limits.yml`, `70-docker-limits-critical.yml` (host-side resource policy via override files).
- **Audit / verify** — `99-verify.yml` read-only health gate.
- **Secrets** — single Ansible Vault for every VPS-access credential.

## What PraefectusAI does **not** do

- Does not deploy applications. That is the application owner's job (their own ansible / scripts / CI).
- Does not edit application `docker-compose.yml` files.
- Does not manage application secrets (TG bot tokens, OpenAI keys, etc.) — those live in the application's own `.env.secrets` or vault.
- Does not own application-level health (business-logic errors). It only checks that the container is running and the port answers.

## Cross-project coordination

Every other project that ships code into `/opt/<app>/` is an "application owner" in this model. Coordination flows through three artefacts:

| Artefact | Purpose |
|---|---|
| `docs/ownership-matrix.md` | Authoritative map: path → owner → can PraefectusAI modify? |
| `docker-compose.override.local.yml` | Host-policy overrides written by PraefectusAI alongside the owner's compose file (memory limits, restart policy, log caps). |
| Vault | Single source of truth for VPS access credentials. Application owners read VPS host/SSH from here, not from their own secrets. |

The escalation path during incidents is documented in [`ownership-matrix.md`](ownership-matrix.md).

## Cross-project host exceptions

Some host objects are intentionally owned by a routing/application project even
though they live under system paths. PraefectusAI records and verifies them but
does not overwrite them.

```text
maxtg_bridge container
  -> docker bridge gateway:18057
  -> Channel M reverse listener on VPS
  -> SSH remote-forward opened by the home router
  -> router direct-out / home WAN for MAX API/CDN
```

The VPS-side pieces for this lane are owned by `router_configuration`:

- `/etc/ssh/sshd_config.d/51-channel-m-reverse.conf`
- `/usr/local/sbin/channel-m-reverse-firewall.sh`
- `channel-m-reverse-firewall.service`
- `channel-m-reverse-firewall.timer`
- `/usr/local/sbin/channel-m-reverse-listener-watchdog.sh`
- `channel-m-reverse-listener-watchdog.service`
- `channel-m-reverse-listener-watchdog.timer`

They keep `18057/tcp` bridge-scoped. The port must not become a public UFW or
cloud-firewall allow. The listener watchdog removes stale SSH reverse listeners
that remain bound but no longer forward to the home router, so the next router
cron recovery can recreate the tunnel.

GhostRoute Channel D is a router-owned home-WAN lane, not a VPS listener:
selected Karing/NaiveProxy-style clients reach the home endpoint on `:4444`,
the home router's Caddy `forward_proxy@naive` relays into a router-local
`channel-d-naiveproxy-socks-in`, and the router applies its managed split.
PraefectusAI must not add `4444/tcp` to VPS UFW rules, cloud-firewall rules, or
`docs/ports.md` expected VPS listeners.

GhostRoute Console may be served on standard HTTPS `:443` by host/SNI through
the routing-owned reverse proxy, while the dedicated `2087/tcp` Console listener
remains documented as a configured public path. PraefectusAI records these
exposures but does not own the reverse-proxy config.

### Runtime schemes

Channel M active service egress:

```text
maxtg_bridge container
  -> Docker bridge gateway:18057 on VPS
  -> OpenSSH reverse listener scoped by permitlisten
  -> home router loopback Channel M ingress
  -> router sing-box channel-m-maxtg-reverse-egress
  -> direct-out / home WAN
  -> MAX API/CDN
```

Channel M stale-listener recovery:

```text
channel-m-reverse-listener-watchdog.timer
  -> checks Docker bridge listener on 18057
  -> sends HTTP CONNECT probe through the reverse listener
  -> kills stale VPS sshd listener only when it no longer forwards
  -> router cron recreates the SSH -R tunnel
```

Channel D selected-client lane:

```text
Karing / NaiveProxy-style client
  -> home router WAN :4444
  -> router Caddy forward_proxy@naive
  -> router-local sing-box channel-d-naiveproxy-socks-in
  -> managed destinations: reality-out -> VPS egress
  -> non-managed destinations: direct-out -> home WAN
```

VPS invariant: `18057/tcp` is restricted to the Docker bridge, and `4444/tcp`
must not appear as a VPS listener.

## Vault as single source of truth

Every access credential — VPS IP, SSH user, port, deploy key, alert tokens, backup credentials — lives in `ansible/group_vars/all/vault.yml`. Application projects read these values via `ansible-vault view` or use placeholders in their own configs.

For multiple VPS hosts, inventory aliases are public but endpoints are encrypted:

```yaml
vault_vps_hosts:
  vps-hetzner-prod:
    ssh_host: "<vps_ip_or_dns>"
    ssh_user: "deploy"
    ssh_port: 22
    ssh_key: "~/.ssh/id_rsa"
```

`ansible/inventory/production.yml` keeps hosts in two operational groups:

- `vps` — ready managed hosts. Regular read-only checks and maintenance target this group.
- `vps_bootstrap` — fresh hosts that still need `00-bootstrap.yml`; move them to `vps` after `deploy` SSH and `99-verify` are green.

The vault password (`~/.vault_pass.txt`) lives only on the operator's control machine, encrypted offsite as backup.

## Workflow for changes

1. Read [`AGENTS.md`](../AGENTS.md).
2. Read the relevant runbook in [`docs/runbooks/`](runbooks/).
3. If the change touches another owner's zone, read [`ownership-matrix.md`](ownership-matrix.md) and coordinate.
4. Edit the role / playbook; check syntax with `--syntax-check`.
5. Run `--check --diff` against production; review the diff line by line.
6. Apply.
7. Run `./verify.sh`; it must be green.
8. Commit only with explicit operator approval.
