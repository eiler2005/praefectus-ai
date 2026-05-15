# Contributing to PraefectusAI

Thanks for your interest. PraefectusAI is a small, opinionated framework — contributions land fastest when they fit the existing patterns.

## Before you start

- Read [`AGENTS.md`](AGENTS.md). The same rules apply to humans and to agents.
- Read [`SECURITY.md`](SECURITY.md). Sanitisation rules are non-negotiable.
- For architectural changes, scan [`docs/adr/`](docs/adr/) first to understand the *why* behind the patterns.

## Development setup

```bash
# 1. Clone
git clone https://github.com/<org>/praefectus-ai.git
cd praefectus-ai

# 2. Install dependencies
brew install ansible git-filter-repo pre-commit  # macOS
# Linux: apt install ansible git pre-commit ; pip install --user git-filter-repo

# 3. Install pre-commit hooks
pre-commit install

# 4. Run the read-only checks
./modules/secrets-management/bin/secret-scan
ansible-playbook --syntax-check ansible/playbooks/*.yml
```

## Documentation conventions

- **Language:** English. Operator-friendly summaries may be added in another language as a `*-<locale>.md` sibling, but the English doc is authoritative.
- **No real secrets:** every example uses placeholders (`<vps_host>`, `198.51.100.10`, `example.invalid`).
- **Internal links** are relative paths — `[docs/architecture.md](docs/architecture.md)`, not absolute URLs.
- **Module-scoped docs:** if a topic is specific to one module, it lives in `modules/<module>/docs/`, not in `docs/`.

## Commit conventions

PraefectusAI uses **Conventional Commits**:

```
<type>(<scope>): <short imperative summary>

<optional longer body explaining *why*; reference ADRs by number when relevant>
```

**Types:**

| Type | Use for |
|---|---|
| `feat` | New playbook, new module, new capability |
| `fix` | Bug fix in an existing playbook / module / doc |
| `docs` | Documentation only |
| `refactor` | Restructuring without behaviour change |
| `chore` | Tooling, lockfiles, config |
| `test` | Adding or updating tests |
| `ci` | CI / pre-commit changes |

**Scopes** (use the closest match):

- `playbook` — `ansible/playbooks/*.yml`
- `role` — `ansible/roles/*`
- `module` — `modules/<module>/`
- `vault` — vault structure, schema, secrets policy
- `docs` — `docs/` (architecture, runbooks, ADRs)
- `runbook` — `docs/runbooks/` specifically
- `ci` — `.github/workflows/`, `.pre-commit-config.yaml`
- `security` — `SECURITY.md`, `secret-scan`

**Subject:** ≤ 72 characters, imperative mood, no trailing period.

**Body:** explain *why*. Reference ADRs (`See ADR-0003`) and runbooks when relevant.

**Co-authorship by AI agents:**

```
feat(playbook): add SQLite integrity check before backup

Pre-flight check catches DB corruption before restic touches the file —
restic happily backs up corrupt SQLite, restore would silently inherit.

Co-Authored-By: Claude <noreply@anthropic.com>
```

## Pull requests

A PR description should answer:

1. **What changed** — one short paragraph or a bullet list.
2. **Scope** — which files, which playbook(s), which module(s).
3. **Why** — link an issue or ADR; if not, explain the trigger.
4. **Test plan** — what you ran (`./verify.sh`, `--syntax-check`, `secret-scan`, manual playbook with `--check --diff`).
5. **Risk** — what could break, and how to verify it didn't.

Smaller, focused PRs land faster than wide refactors.

## Architecture Decision Records (ADRs)

Open an ADR for any change that:

- Adds or removes an architectural invariant.
- Changes the public ownership boundary (`docs/ownership-matrix.md`).
- Introduces a new external dependency (cloud provider, alerting service, etc.).
- Creates a new playbook number range or convention.

Use [`docs/adr/0001-host-vs-app-ownership.md`](docs/adr/0001-host-vs-app-ownership.md) as a format template.

## Pre-commit hooks

Hooks defined in [`.pre-commit-config.yaml`](.pre-commit-config.yaml):

- **`secret-scan`** — fails commit if any leak pattern matches.
- **`ansible-lint`** — playbook lint.
- **`yamllint`** — YAML formatting.

Install once:

```bash
pre-commit install
```

Run on staged files:

```bash
pre-commit run
```

Run on the whole repo:

```bash
pre-commit run --all-files
```

## Safety boundaries

These are hard limits even for maintainers:

- Never commit a real public IP, real domain, real token, or any vault payload.
- Never `git push --force` to `main` without an open conversation explaining why.
- Never bypass `secret-scan` with `--no-verify`.
- Never apply a mutating playbook in CI — these are operator-supervised actions.

If you find a sanitisation gap (a leak the scanner missed), open a private discussion before opening a public PR — `SECURITY.md` has the reporting protocol.

## Reporting security issues

For findings that affect the published code (scanner false positives, broken playbooks that could leak data, doc errors that recommend unsafe operations), open a public issue.

For findings affecting your own deployment, do not include endpoints, credentials, real IPs, or live reports in any public discussion. Sanitise to placeholders first. See [`SECURITY.md`](SECURITY.md) for the reporting policy.
