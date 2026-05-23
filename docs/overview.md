# Overview — PraefectusAI

Full navigation index for the repository: what's here, where it lives, when to use it.

> README.md is the quick start (clone → vault → smoke test). This file is the reference: every playbook, every CLI tool, every doc, every runbook.

---

## TL;DR — where to look first

| I want to | Command / document |
|---|---|
| Check VPS health right now | `./verify.sh` |
| Current snapshot of state | [`docs/dashboard.md`](dashboard.md) (refresh: `./modules/dashboard/bin/update-dashboard`) |
| Understand who owns what on the host | [`ownership-matrix.md`](ownership-matrix.md) |
| Free up disk space | `ansible-playbook playbooks/10-disk-cleanup.yml --check` → apply |
| Run a manual health check + Telegram alert | `./modules/monitoring/bin/run-check` |
| Threat model and recovery boundaries | [`SECURITY.md`](../SECURITY.md) |
| Agent contract and safety rules | [`AGENTS.md`](../AGENTS.md) |
| Architecture decisions | [`docs/adr/`](adr/) |

---

## Playbooks (`ansible/playbooks/`)

| # | File | Purpose | Mutating? |
|---|---|---|---|
| 10 | `10-disk-cleanup.yml` | One-shot cleanup: apt clean, journal vacuum (14 d / 500 M), filtered docker prune, logrotate config. Volumes untouched. | yes |
| 11 | `11-periodic-cleanup-setup.yml` | Installs canonical `vps-cleanup.timer` + `/usr/local/bin/vps-periodic-cleanup.sh` (Sun 03:00 UTC); retires legacy `vps-weekly-cleanup.timer`. | yes (one-shot setup) |
| 11 deprecated | `11-schedule-cleanup.yml` | Guardrail only: intentionally fails and points to `11-periodic-cleanup-setup.yml`. | no |
| 20 | `20-monitoring.yml` | Deploys Python poller `/usr/local/bin/vps-monitor.py` + systemd timer (5 min). Sends Telegram alerts on `WARN` / `CRIT`. | yes |
| 30 | `30-backup.yml` | restic + B2: encrypted backups of application data. Daily timer at 02:00 UTC. Tags: `--tags run` (one-off), `--tags status` (snapshots + timer). | yes (one-shot setup) |
| 40 | `40-security.yml` | `fail2ban` (sshd jail), `unattended-upgrades` (`-security` only), sshd `MaxSessions` enforcement, UFW audit. | yes |
| 50 | `50-syncthing-audit.yml` | Scans for `*.sync-conflict-*`, files larger than 100 MB, peer status via Syncthing API. Writes `reports/syncthing-audit-*.md`. | read + report |
| 60 | `60-docker-limits.yml` | `mem_limit` for less-critical containers (256–384 m) via `docker-compose.override.local.yml`. | yes (no auto-restart) |
| 70 | `70-docker-limits-critical.yml` | `mem_limit` for critical services: override.local.yml + immediate `docker update --memory` (no restart). | yes |
| 99 | `99-verify.yml` | Read-only health gate. 12 checks (disk, mem, swap, load, docker, containers, ufw, restarts, app dirs). Emits `reports/health/<ts>.json` + `reports/verify-*.md`. | **no** |

Before any mutating playbook, run `--check --diff` and review the output (see [AGENTS.md](../AGENTS.md) safety rules).

---

## CLI utilities (`modules/<name>/bin/`)

| Command | What it does | When you need it |
|---|---|---|
| `./verify.sh` | Wrapper over `99-verify.yml`. Full health check in seconds. | Before / after any mutating action |
| [`modules/dashboard/bin/update-dashboard`](../modules/dashboard/bin/update-dashboard) | Reads latest `reports/health/*.json` + cleanup / syncthing reports, regenerates `docs/dashboard.md`. | When you want a fresh state snapshot without SSH |
| [`modules/disk-observatory/bin/disk-report`](../modules/disk-observatory/bin/disk-report) | Standalone (no Ansible) SSH into VPS for `df` / `du` / `docker df`; prints + saves to `reports/`. | Quick disk audit without a playbook |
| [`modules/health-trends/bin/health-trend`](../modules/health-trends/bin/health-trend) | Trend analysis over the last N `reports/health/*.json`: disk, swap, memory trend, unstable containers. Flags: `--last N`, `--trend disk`. | When you want a trajectory, not a snapshot |
| [`modules/maintenance-journal/bin/cleanup-fetch`](../modules/maintenance-journal/bin/cleanup-fetch) | Pulls `/var/log/vps-periodic-cleanup.log` from VPS, aggregates by week into `reports/maintenance/<YYYY-MM>.md`. Flags: `--all`, `--stdout`. | Monthly review of what the auto-cleanup timer did |
| [`modules/monitoring/bin/run-check`](../modules/monitoring/bin/run-check) | Runs `vps-monitor.py --once` on VPS. Flags: `--test-alert`, `--log`, `--status`. | Manual check outside the 5 min timer |
| [`modules/port-audit/bin/port-audit`](../modules/port-audit/bin/port-audit) | Compares live `ss -tlnp` against `docs/ports.md`. Flags new ports, missing ports, unsafe `0.0.0.0` bindings. Flags: `--save`, `--live-only`. | After adding a service; monthly security audit |
| [`modules/secrets-management/bin/secret-scan`](../modules/secrets-management/bin/secret-scan) | Scans the repo for: real VPS IPs, public IPv4 (excluding TEST-NET), SSH private keys, hardcoded `api_key=` / `token=`. Ignores vault.yml and reports/. | **Before every commit** |

---

## Roles (`ansible/roles/`)

| Role | Used by | Status |
|---|---|---|
| `monitoring` | `20-monitoring.yml` | active |
| `disk_audit`, `disk_cleanup`, `verify` | — | scaffolded; logic lives inline in playbooks (because `raw` module pipelining is incompatible with task-level role decomposition) |

---

## Documentation index (`docs/`)

| Document | Topic | When to read |
|---|---|---|
| [`architecture.md`](architecture.md) | Host-vs-app ownership model; what lives where | First onboarding |
| [`ownership-matrix.md`](ownership-matrix.md) | Path-by-path table: VPS path → owner → can PraefectusAI modify? | **Required** before any mutating action in `/opt/<app>/` |
| [`adr/`](adr/) | Architecture Decision Records | Whenever you wonder *why* a pattern exists |
| [`dashboard.md`](dashboard.md) | Current state snapshot (regenerated by `update-dashboard`) | Quick "how are things" |
| [`containers.md`](containers.md) | Container inventory with owner, image, ports, mem_limit | Resource planning, new services |
| [`ports.md`](ports.md) | Canonical port map (source of truth for `port-audit`) | Adding a service; resolving conflicts |
| [`firewall.md`](firewall.md) | UFW rules, trusted IPs and documented non-UFW bridge-scoped exceptions such as Channel M reverse | Security review |
| [`overview.md`](overview.md) | This file — index of everything | When you forgot what's in the repo |

Top-level (repo root):

| File | Purpose |
|---|---|
| [`README.md`](../README.md) | Quick start: clone → vault → smoke test → first playbook |
| [`AGENTS.md`](../AGENTS.md) | Shared rules for every agent (Karpathy workflow + safety + secrets policy) |
| [`CLAUDE.md`](../CLAUDE.md) | Local notes for Claude Code |
| [`SECURITY.md`](../SECURITY.md) | Threat model, recovery boundaries |
| [`CONTRIBUTING.md`](../CONTRIBUTING.md) | Conventional commits, PR workflow, dev setup |
| [`LICENSE`](../LICENSE) | MIT |

---

## Runbooks (`docs/runbooks/`)

Scenario → instructions.

| Trigger | Runbook |
|---|---|
| Disk ≥ 90 %, operator under pressure | [`disk-full.md`](runbooks/disk-full.md) |
| What does OK / WARN / CRIT mean | [`health-rules.md`](runbooks/health-rules.md) |
| When to run what (auto / manual cadence) | [`maintenance-schedule.md`](runbooks/maintenance-schedule.md) |
| Suspected compromise | [`runbooks/security-incident.md`](runbooks/security-incident.md) |
| SSH `Too many authentication failures` / MaxSessions | [`runbooks/ssh-maxsessions.md`](runbooks/ssh-maxsessions.md) |
| SSH banner timeout, direct path unavailable, VPN source changed | [`runbooks/ssh-breakglass-bastion.md`](runbooks/ssh-breakglass-bastion.md) |

---

## Reports (`reports/` — gitignored, local artefacts)

| Pattern | Source | Contents |
|---|---|---|
| `reports/health/<ts>.json` | `99-verify.yml` | Structured metrics (consumed by `health-trend`) |
| `reports/verify-<ts>.md` | `99-verify.yml` | Human-readable snapshot of all 12 checks |
| `reports/cleanup-<ts>.md` | `10-disk-cleanup.yml` | Before / after disk, what was cleaned, freed MB |
| `reports/syncthing-audit-<ts>.md` | `50-syncthing-audit.yml` | Conflict files, peer status, large files |
| `reports/maintenance/<YYYY-MM>.md` | `cleanup-fetch` | Aggregated weekly auto-cleanup history |
| `reports/disk-<ts>.md` | `disk-observatory/bin/disk-report` | Disk audit without a playbook |
| `reports/port-audit-<ts>.txt` | `port-audit --save` | Port snapshot + diffs against `docs/ports.md` |

Sanitised samples of each are checked in under [`examples/`](../examples/).

---

## Journal (`docs/journal/`)

Manual log of significant interventions — what was done, by whom, why. One file per month.

Filled in by hand after each major action (migration, restart of a critical service, limit changes, etc.).

---

## Roadmap

| # | What | Why | Priority |
|---|---|---|---|
| `00` | `00-bootstrap.yml` — DR / fresh install | Cold-provision a fresh VPS (apt baseline, deploy user, UFW, Docker CE, `/opt/*` skeleton, restic restore). | medium |
| `tls-audit` | TLS / cert monitoring | Expiry alert for any TLS endpoint, < 14 days warning. | medium |
| `trivy` | Image vulnerability scan | Monthly CVE audit of running images. | low |
| OOM | OOM detection with TG alert | `dmesg \| grep "killed process"` → Telegram (important once `mem_limit`s are tight). | low — partially in `monitoring` |
| SQLite | SQLite integrity check | `PRAGMA integrity_check` on `.db` files in application data dirs before backup. | low |
| Cost | Cost monitoring | Cloud-provider API + B2 storage usage, monthly check. | low |
| Migration | Migration playbook small VPS → larger | When 4 GB stops being enough. Test on a test-VM each quarter. | low |

---

## Where to find history and decisions

| What | Where |
|---|---|
| Architectural decisions | [`docs/adr/`](adr/) (Architecture Decision Records) |
| Ad-hoc operator actions | [`docs/journal/`](journal/) |
| Code history | `git log` (Conventional Commits — see [`CONTRIBUTING.md`](../CONTRIBUTING.md)) |
