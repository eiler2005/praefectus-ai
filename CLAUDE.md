@AGENTS.md

# Claude Code

All shared rules live in [`AGENTS.md`](AGENTS.md). This file holds short Claude Code-specific notes only.

## Local notes

- Vault password lives in `~/.vault_pass.txt` (mode `0600`). Created manually; backed up in a password manager.
- Before any playbook other than `99-verify`, run `--check --diff` first, then apply.
- When changing `vault.yml`, mirror the schema (no values, only key names) into `vault.yml.example` in the same commit.
- Before touching another owner's directory (`/opt/<app>/`), read [`docs/ownership-matrix.md`](docs/ownership-matrix.md) first.
