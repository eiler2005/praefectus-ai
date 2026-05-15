# Changelog

All notable changes to PraefectusAI are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and PraefectusAI aims to follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html) once a stable API surface is published.

---

## [Unreleased]

### Added

- Hero banner illustration (`docs/assets/hero-banner.png`) and "The name" section in README.
- "What PraefectusAI does for you" section in README — sales-style capabilities pitch (pain → daily routine → on-demand skills → trust through limits → audience CTA), positioned right after the tagline so a 30-second visitor sees concrete value before brand story or architecture.
- "Features" section in README — scannable employee-qualities list framed as "what you get when you hire PraefectusAI". Complements the narrative pitch above with bullet-form selling points (always-on, written job description, ownership boundaries, persistent memory, MIT contract).
- "What it does as a sysadmin" sub-section under Features — verb-first concrete actions (Cleans / Caps / Hardens / Backs up / Watches / Audits / Scans / Aggregates / Refreshes), each linked to the exact playbook or module that runs it. 12 items covering every active capability.
- AGENTS.md callout under the Features list — one short blockquote replacing the standalone "AGENTS.md contract pattern" H2 section (which duplicated information already present in Features, "The name", and four other inline links).

### Removed

- README "Why PraefectusAI exists" section — duplicated the philosophical argument already made in the "What PraefectusAI does for you" intro.
- README "The AGENTS.md contract pattern" section — replaced by the inline callout above.

### Changed

- README section order — `Demo` and `Quick Start` moved up to sit right after `Features`, so a 30-second visitor sees runnable proof and a try-it-now path before brand story (`The name`), philosophy, architecture, and the developer-reference inventory. Reader flow becomes: hook → daily routine → employee qualities → real outputs → try it → backstory → architecture → reference. README total length dropped from 344 to 314 lines.
- README: replaced `The name` (10-line brand-only story) with `The praefectus pattern` (~25 lines), merging the Roman etymology with the design principles previously in the cut `Why PraefectusAI exists` section. Now includes a 6-row mapping table: Roman principle → file in this repo (`AGENTS.md` = mandate, `ownership-matrix` = scope, Ansible playbooks = deterministic actions, `verify.sh` = read-only by default, `reports/` + `journal/` = faithful reporting, `secret-scan` = mistakes caught before they ship). Repositioned to between "What it does for you" and "Features" so a reader gets the full mental model — pain → offer → why-this-approach-works → what-it-has — before scrolling further.

### Notes

- The control machine is expected to run the [`pre-commit`](https://pre-commit.com/) hooks on every commit. Install once with `pre-commit install`.

---

## [1.0.0] — 2026-05-15

First public release. PraefectusAI is positioned as a universal framework for AI-augmented VPS administration, ready for fork-and-customise use.

### Added

**Brand and concept**

- Project rebranded to **PraefectusAI** — an LLM-agent contract for safely operating production Linux servers.
- New README centred on the [`AGENTS.md`](AGENTS.md) contract pattern, with a Mermaid architecture diagram and worked-out quick start.
- "The name" section explaining the Roman *praefectus* metaphor — appointed administrator with structured authority, narrow scope, and faithful reporting back.

**Engineering signals**

- `LICENSE` (MIT, © 2026 Denis Ermilov).
- `CONTRIBUTING.md` documenting the conventional-commit format, scopes, pre-commit hooks, and PR workflow.
- `SECURITY.md` with the full threat model, mitigations, recovery scenarios with target times, and the secrets policy.
- 6 Architecture Decision Records in [`docs/adr/`](docs/adr/) covering the host-vs-app boundary, vault as source of truth, read-only by default, the `raw` module choice, override files as the host-policy zone, and the `AGENTS.md` contract pattern.
- `.pre-commit-config.yaml` with secret-scan, ansible-syntax check, yamllint, and ansible-lint.
- `.yamllint` configuration aligned with ansible-lint defaults.
- `.github/workflows/ci.yml` running secret-scan, syntax-check, and linters on every push.
- `.github/ISSUE_TEMPLATE/` (bug, feature, runbook-gap) and `.github/PULL_REQUEST_TEMPLATE.md`.

**Showcase**

- [`examples/`](examples/) directory with 8 sanitised real outputs: `verify`, `dashboard`, `disk-report`, `health-trend`, `cleanup-log`, `monitor-alert`, `secret-scan`, `containers`.
- Per-module README files for all 7 CLI modules (`dashboard`, `disk-observatory`, `health-trends`, `maintenance-journal`, `monitoring`, `port-audit`, `secrets-management`).

**Documentation**

- All docs, playbooks, runbooks, and scripts translated to English.
- Application paths in `docs/ownership-matrix.md` and `docs/ports.md` genericised to `<app-N>` placeholders so the repo reads as a fork-and-customise template.
- Operator runbooks: `disk-full`, `health-rules`, `maintenance-schedule`, `security-incident`, `ssh-breakglass-bastion`, `ssh-maxsessions`.

### Changed

- Project structure remains stable from the last private release. No breaking changes to playbook numbering, role contracts, or module CLI surfaces.

### Security

- Pre-publication audit: `./modules/secrets-management/bin/secret-scan` exits 0; `ansible-playbook --syntax-check` passes on every playbook; full git history scanned for the maintainer's real production IP — not present in any commit.
- Real values continue to live only in the encrypted `ansible/secrets/vault.yml`; placeholders (`<vps_host>`, `198.51.100.10`, `example.invalid`) are used everywhere else.
- One operator-named placeholder appears in the very first commit's UFW rule comments (`<denis-home-ip>`). It is not a leak — only the placeholder string. Operators forking the repo are expected to swap their own placeholder names in.

---

## [0.x] — Internal development (2026-04 → 2026-05)

Internal-only iterations on the original `vps_management` repository: 10 playbooks, 7 CLI modules, 5 runbooks, monitoring + backup + security hardening + Docker memory limits, applied to a single Hetzner CX23 reference deployment. History preserved in `git log`.
