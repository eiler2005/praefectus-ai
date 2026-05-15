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

- **Bootstrap** *(planned: `00-bootstrap.yml`)* — bring a fresh VM to a known baseline state.
- **Maintenance** — `10-disk-cleanup.yml`, `11-periodic-cleanup-setup.yml`, `20-monitoring.yml`, `30-backup.yml`, `40-security.yml`.
- **Limits** — `60-docker-limits.yml`, `70-docker-limits-critical.yml` (host-side `mem_limit` policy via override files).
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

## Vault as single source of truth

Every access credential — VPS IP, SSH user, port, deploy key, alert tokens, backup credentials — lives in `ansible/secrets/vault.yml`. Application projects read these values via `ansible-vault view` or use placeholders in their own configs.

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
