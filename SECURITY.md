# Security

PraefectusAI is a single-operator framework for managing one or a small number of VPS hosts. The security model focuses on keeping production secrets out of git, limiting mutation paths into the host, and making recovery explicit and rehearsable.

## Protected Assets

| Asset | Where it lives | Compromise impact |
|---|---|---|
| `~/.vault_pass.txt` | Control machine, mode `0600` | Full VPS access — IP, SSH, every downstream secret |
| `~/.ssh/<deploy_key>` | Control machine | SSH access to the VPS as the `deploy` user |
| `ansible/secrets/vault.yml` | This repo, encrypted | With the vault password, equivalent to `~/.vault_pass.txt` |
| Restic password | In vault | Read/decrypt every backup snapshot |
| B2 / S3 application key | In vault | Delete or overwrite remote backups |
| Telegram bot token | In vault | Send forged alerts as the operator's bot |
| Cloud-provider API token (Hetzner / AWS / DigitalOcean…) | In vault | Provider-level VPS control (resize, snapshot, delete) |

## Threat Model

PraefectusAI reduces accidental leaks and operator mistakes within a **single-operator threat envelope**. The scenarios below name what it does and does not address.

### Threat scenarios in scope

1. **Secret exfiltration via git.** A real VPS IP, SSH key, or token committed into a tracked file in this or any related repo.
2. **Vault password loss.** The control machine is lost or rotated without a recoverable backup, leaving the encrypted vault unreadable.
3. **SSH credential compromise.** The `deploy` user's authorised keys are extended by an attacker, granting persistent access.
4. **Disk-full induced outage.** A growing log, image cache, or build cache fills the root filesystem; OOM killer or service crashes follow.
5. **Memory exhaustion (OOM).** An unbounded container consumes all RAM on a small VPS and triggers cascading restarts.
6. **Unfiltered Docker pruning.** A `docker system prune -a` or `docker volume prune` without filters wipes images held by stopped containers, or destroys application state.
7. **Bidirectional sync data loss.** Two-way file synchronisation (e.g. Syncthing) propagates a deletion or unresolved conflict from the control machine to the VPS.
8. **Operator deploy mistake.** A misapplied playbook (wrong host, missing `--check`, accidental scope) silently mutates production state.
9. **Cross-project boundary breach.** A change attributed to host management mutates application state in another owner's `/opt/<app>/` directory.

### Mitigations

| Scenario | Primary mitigation | Verification |
|---|---|---|
| Secret exfiltration via git | `secret-scan` pre-commit + CI; placeholders policy in [`AGENTS.md`](AGENTS.md); vault-only storage for real values | `./modules/secrets-management/bin/secret-scan` |
| Vault password loss | Encrypted offsite backup of `~/.vault_pass.txt` (1Password or equivalent); periodic restore drill | Quarterly DR drill (see `docs/runbooks/`) |
| SSH credential compromise | `40-security.yml` enforces `fail2ban` (sshd jail) + `MaxSessions` cap; `unattended-upgrades` for `-security` patches; key-only auth | `journalctl -u sshd \| grep Accepted`; `last`; `40-security.yml` audit step |
| Disk-full outage | `10-disk-cleanup.yml` (manual) + `11-schedule-cleanup.yml` (weekly Sunday 03:00 UTC); always `docker prune --filter "until=Nh"`; no volume prune | `99-verify.yml` disk check; `disk-report` |
| Memory exhaustion (OOM) | `60-docker-limits.yml` + `70-docker-limits-critical.yml` apply `mem_limit` via `docker-compose.override.local.yml`; OOM detection on the monitoring backlog | `99-verify.yml` mem check; `health-trend --trend mem` |
| Unfiltered Docker pruning | Hard rule in `AGENTS.md`: every prune carries `--filter "until=Nh"`; volumes never pruned automatically | Code review; pre-commit shell-syntax hook |
| Bidirectional sync data loss | `50-syncthing-audit.yml` reports `*.sync-conflict-*`, peer status, files >100 MB | Weekly audit run; manual conflict resolution runbook |
| Operator deploy mistake | Read-only by default (`99-verify` first); `--check --diff` required before apply; `verify.sh` after | `verify.sh`; AGENTS.md safety rules |
| Cross-project boundary breach | `docs/ownership-matrix.md` enumerates every `/opt/<app>/`; agents must read it before touching foreign zones | `docs/ownership-matrix.md` review; `port-audit` |

### Out-of-scope risks

This project does **not** attempt to address:

- Endpoint compromise of the control machine (malware, supply-chain, OS-level keylogging). The control machine is the trusted root.
- Provider-level VPS takeover (the cloud vendor seizes or reimages the host).
- Multi-operator authorisation, role separation, or audited admin actions.
- High-availability VPS failover. The reference design is single-VPS by intent; any HA story is operator-built on top.
- DDoS or volumetric attack mitigation on the VPS.
- Kernel-level container escape via `--privileged` or excessive capabilities (host policy bans `--privileged`; agents must check).

### Acceptable risks

The operator explicitly accepts:

- Single-VPS / single-operator design — no automated failover.
- Local-only health monitoring with optional Telegram alerts; no external paging integration.
- Manual quarterly DR drill rather than continuous failover testing.

## Secrets Policy

- Real values live only in `ansible/secrets/vault.yml` (encrypted) or in gitignored local files.
- Tracked docs use placeholders: `<vps_host>`, `<vps_ip>`, `198.51.100.10`, `example.invalid`.
- Never commit a generated profile, real UUID, private key, admin path, or production listener value.
- Run `./modules/secrets-management/bin/secret-scan` before pushing.

## Recovery Boundaries

Repo-level CI checks syntax, linting, and secret hygiene. It does not require vault access, VPS access, or a live host — anything that needs production access is an operator task.

### Recovery scenarios and target times

| Scenario | Recovery path | Target time | Reference |
|---|---|---|---|
| Lost SSH access | Provider rescue console (e.g. Hetzner Cloud Console, AWS EC2 console, DigitalOcean web terminal) → mount root → restore `~deploy/.ssh/authorized_keys` | 15–30 min | [`docs/runbooks/ssh-breakglass-bastion.md`](docs/runbooks/ssh-breakglass-bastion.md) |
| Lost vault password | Restore from offsite backup (password manager); if unrecoverable, regenerate every value (SSH keys, tokens, restic password — last loses the backup history) | 15 min restore; 1–2 h regenerate | `SECURITY.md` (this file) |
| Lost restic password | Backups become **permanently** unreadable. Restic has no recovery mechanism. Mitigation: store in offsite password manager separately from the vault password | N/A (preventative only) | `30-backup.yml` |
| `deploy` user compromise | Remove unknown keys from `~/.ssh/authorized_keys`; rotate operator key; re-run `40-security.yml`; audit `last`, `journalctl _COMM=sshd \| grep Accepted`, cron, systemd timers | 30 min for rotation; 1–2 h for full audit | [`docs/runbooks/security-incident.md`](docs/runbooks/security-incident.md) |
| Application container compromise | Out of scope for this repo — escalate to the application owner (see `docs/ownership-matrix.md`); host-side, inspect `docker inspect` for mounts, capabilities, `--privileged` | Coordination time with owner | `docs/ownership-matrix.md` |
| Full VPS reinstall (DR) | Provision new host (same or new IP); `00-bootstrap.yml` (planned) for baseline; `30-backup.yml --tags restore` to recover application data; application owners redeploy their stacks | 1–3 h | Backlog: `00-bootstrap.yml`; `30-backup.yml` |
| Disk full ≥ 90 % | `10-disk-cleanup.yml --check --diff` → apply; `disk-report` to confirm; if still full, see runbook for application-owned cleanup escalation | 5–15 min | [`docs/runbooks/disk-full.md`](docs/runbooks/disk-full.md) |

DR drill cadence — quarterly, see roadmap.

## Vault Backup

Vault loss is the highest-impact operational risk. Keep an encrypted offsite backup of `~/.vault_pass.txt` and periodically test restore without touching production. Storage options:

- A password manager that supports secure file attachments (1Password, Bitwarden Premium, KeePassXC)
- An encrypted USB key kept in a separate physical location
- A `gpg`-encrypted file in a personal cloud account, with the GPG private key offline

Test restore at least once per quarter — read the file, decrypt the vault, exit without modifying anything.

## Reporting Issues

PraefectusAI is an open-source reference implementation. For findings affecting the published code (scanner false positives, broken playbooks, doc errors), open a public GitHub issue.

For findings affecting your own deployment, do not include endpoints, credentials, real IPs, or live reports in any public discussion. Sanitise to placeholders first.

## Pre-commit Checklist

Before every `git commit`:

```bash
./modules/secrets-management/bin/secret-scan          # must exit 0
git status                                            # no .vault_pass.txt, no real secrets/, no untracked vault.yml
git diff --cached                                     # eyeball the diff for IPs and tokens
```

The `.pre-commit-config.yaml` automates the first check; the other two are operator discipline.
