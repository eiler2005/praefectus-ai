# Agent Instructions — PraefectusAI

Shared rules for any agent (Codex, Claude Code, Cursor, others) working in this repository.

## Project Snapshot

**PraefectusAI** is a framework for AI-augmented administration of Linux VPS hosts running Dockerised application workloads. It packages production patterns as a structured knowledge base an LLM agent can consume safely:

- **Deterministic actions** — Ansible playbooks (mutating + read-only `99-verify`)
- **Decision trees** — markdown runbooks (`docs/runbooks/*.md`)
- **Agent skills** — standalone CLI modules (`modules/*/bin/`)
- **Memory** — structured reports (`reports/health/*.json`) + manual journal (`docs/journal/`)
- **Guardrails** — Ansible Vault + secret-scan + ownership matrix + read-only by default

Target host model: any Linux VPS with SSH + Docker. Reference deployment is a single Hetzner CX23 (Ubuntu 24.04, 4 GB RAM, 2 vCPU, 40 GB disk, `deploy@22`), but patterns scale to small fleets without structural change.

### What this repo owns (host layer)

- OS packages, kernel, sysctl
- `/etc/{ssh,ufw,fail2ban}` (host security)
- `/var/log`, `/var/lib/docker` (system cleanup)
- `deploy` user home (`~/.ssh`, `~/.config/*`)
- Docker daemon (but **not** application `docker-compose.yml` files)
- Host-level monitoring, backups, access secrets

### What this repo does **not** own (application layer)

- Application directories in `/opt/<app>/` are owned by the projects that deploy them
- Application `docker-compose.yml` files are deployed by the application owner, not by this repo
- Application-managed system paths (e.g. `/etc/caddy/` if a routing project owns the reverse proxy) belong to their owner

Full ownership map → [`docs/ownership-matrix.md`](docs/ownership-matrix.md).

**Source of truth for VPS access** — `ansible/group_vars/all/vault.yml` (ansible-vault encrypted and loaded by Ansible). No real IPs, SSH credentials or tokens live in tracked files outside the vault.

---

## Karpathy-Style Agent Workflow

LLM agents make avoidable mistakes when they skip context. Follow these rules to stay productive and not introduce regressions.

1. **Think before acting.** Read the task, read this file, read the relevant `docs/runbooks/`. Do not open the editor until you understand *what* and *why*.
2. **Read docs first.** Before changing a playbook or role, read `docs/architecture.md` and the matching runbook. Before touching `/opt/<app>`, read `docs/ownership-matrix.md`.
3. **Minimal changes.** One task, one change. Do not refactor "while you're there". Do not add features that were not requested.
4. **Surgical edits.** Only touch the files you need. Do not reformat unrelated files. Do not "improve" comments.
5. **Match project style.** YAML uses two-space indent; bash uses `set -euo pipefail`; role names are `snake_case`; playbooks are `kebab-case` with a numeric prefix.
6. **Preserve the operator's work.** If the repo has uncommitted changes, never run `git checkout` / `reset` / `clean`. Ask first.
7. **Clean up after yourself only.** Remove temp files you created. Do not "tidy" `reports/` or `secrets/` — those are operator artefacts.
8. **Work toward a verifiable goal.** Every change ends with something measurable: `--syntax-check` green, `verify.sh` green, a specific metric moved.

---

## Safety Rules

Hard limits. Violating them is a regression.

### Git

- Never `git commit` or `git push` without explicit operator approval.
- Never use `--no-verify`, `--no-gpg-sign`, or `--amend` without an explicit request.
- Never run `git reset --hard`, `git clean -fd`, or `git checkout -- .` — these destroy the operator's work.

### Ansible / SSH

- Never run mutating playbooks (`10-*`, `11-*`, `20-*`, `30-*`, `40-*`, `50-*`, `60-*`, `70-*`) without explicit approval.
- Before any apply, run `ansible-playbook ... --check --diff` and review the output.
- Read-only operations (`99-verify.yml`, `verify.sh`, `disk-report`, `secret-scan`) may run without confirmation.
- If `99-verify.yml` fails, diagnose first; do not paper over it with a mutating playbook.

### Docker (highest-risk zone — application data lives here)

- Never run `docker volume prune` automatically. Volumes hold state.
- Never run `docker system prune -a` without `--filter "until=Nh"`. Without a filter it removes images held by temporarily stopped containers.
- Never run `docker compose down -v` anywhere under `/opt/<app>/` — that wipes application data.
- Never edit `/opt/<app>/docker-compose.yml` directly — that file belongs to the application owner. Use a `docker-compose.override.local.yml` sibling instead (see Architecture Invariants).

### System

- Never disable UFW, not even "temporarily for a test".
- Never edit `/etc/ssh/sshd_config` directly — only through an Ansible role with `validate: sshd -t -f %s` and a config backup.
- Never run `apt full-upgrade` or `do-release-upgrade` without explicit authorisation. Only `unattended-upgrades` with a `-security` allowlist.
- Never reboot the VPS without explicit approval.

### Cross-project

- Before any mutating action against a service that lives in `/opt/<app>/`, read `docs/ownership-matrix.md`. Those are other owners' zones; touching them is coordination, not autonomy.
- Override files (`docker-compose.override.local.yml`) are the only legitimate modification this repo makes inside another owner's directory.

---

## Secrets and Privacy

### What counts as a secret

- Real public VPS IP
- SSH user, SSH port (even if standard)
- Container names with unique suffixes / UUIDs
- Telegram bot tokens, chat IDs, topic IDs
- B2 / S3 keys, restic password
- Trusted IPs in UFW allowlists
- Cloud-provider API tokens (Hetzner, AWS, DigitalOcean, etc.)

### Where they live

- **All secrets** → `ansible/group_vars/all/vault.yml` (ansible-vault AES-256 encrypted, stored encrypted in git).
- Vault password → `~/.vault_pass.txt` on the control machine (mode `0600`, **not** in git, backed up to a password manager).
- Schema without values → `ansible/secrets/vault.yml.example` (plaintext, tracked).

### In commits and documentation

- Use placeholders: `<vps_host>`, `<vps_ip>`, `198.51.100.10` (RFC 5737 TEST-NET-1), `example.invalid`.
- Never commit a real IP or token, not even inside a comment or in `docs/`.
- Before every commit, run `./modules/secrets-management/bin/secret-scan`. It must exit 0.

---

## Architecture Invariants

1. **Host vs. app ownership** — this repo manages the host. Applications manage themselves.
2. **Vault is the single source of truth** — every access credential lives there; downstream projects read via `ansible-vault view` or use placeholders.
3. **Playbook numbering is semantic** — `00` bootstrap (one-shot), `10–50` mutating maintenance, `60–80` advanced/optional, `99` verify (read-only).
4. **Read-only by default** — every operation starts with an audit. Mutating requires explicit permission.
5. **Override files are our zone** — `/opt/<app>/docker-compose.override.local.yml` is how we apply host policy (`mem_limit`, restart policy, logging caps). The base compose file is not ours.
6. **Filters always** — every `docker prune` carries `--filter "until=Nh"`. No filter, no run.
7. **Volumes are sacred** — never pruned automatically. Manual review only.

---

## Where Things Live

| What | Where |
|---|---|
| Shared agent rules | `AGENTS.md` (this file) |
| Claude Code local notes | `CLAUDE.md` |
| User-facing overview | `README.md` |
| Threat model | `SECURITY.md` |
| Architecture docs | `docs/architecture.md`, `docs/ownership-matrix.md` |
| Architecture Decision Records | `docs/adr/` |
| Runbooks | `docs/runbooks/*.md` |
| Ansible config | `ansible/ansible.cfg` |
| Inventory | `ansible/inventory/production.yml` |
| Non-secret vars | `ansible/group_vars/{all,vps}.yml` |
| Secrets (encrypted) | `ansible/group_vars/all/vault.yml` |
| Secrets template | `ansible/secrets/vault.yml.example` |
| Playbooks | `ansible/playbooks/NN-name.yml` |
| Reusable roles | `ansible/roles/<name>/` |
| Helper scripts (vault, ssh) | `ansible/scripts/*.sh` |
| Module CLI tools | `modules/<module>/bin/<tool>` |
| Module docs | `modules/<module>/docs/*.md` |
| Verify entrypoint | `verify.sh` (repo root) |
| Local-only outputs | `reports/*` (gitignored) |
| Sample outputs (sanitised) | `examples/*` |

---

## Checks

Read-only checks that may run without confirmation:

```bash
# Secret leak scanner — run before every commit
./modules/secrets-management/bin/secret-scan

# Syntax check for every playbook
cd ansible
ansible-playbook --syntax-check playbooks/*.yml

# Linters (if installed)
ansible-lint playbooks/ roles/
yamllint inventory/ group_vars/ playbooks/ roles/

# Health gate
./verify.sh

# Standalone disk report
./modules/disk-observatory/bin/disk-report
```

---

## Docs to Read

Before any non-trivial change, read the relevant document:

- [`docs/architecture.md`](docs/architecture.md) — host-vs-app model, where things live
- [`docs/ownership-matrix.md`](docs/ownership-matrix.md) — who owns what on the VPS
- [`docs/adr/`](docs/adr/) — Architecture Decision Records (the *why* behind invariants)
- [`docs/runbooks/disk-full.md`](docs/runbooks/disk-full.md) — what to do when disk fills
- [`SECURITY.md`](SECURITY.md) — threat model, recovery boundaries
- [`README.md`](README.md) — high-level overview, quick start

<!-- lean-ctx -->
## lean-ctx

Prefer lean-ctx MCP tools over native equivalents for token savings.
Full rules: @LEAN-CTX.md
<!-- /lean-ctx -->
