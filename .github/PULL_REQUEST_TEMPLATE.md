## Summary

One short paragraph or a bullet list — what does this PR change?

## Scope

- Files / playbooks / modules touched:
- Conventional-commit type and scope (e.g. `feat(playbook)`, `fix(module)`, `docs(runbook)`):

## Why

Link an issue or ADR. If neither exists, explain the trigger:

## Test plan

What did you run? Tick what applies.

- [ ] `./modules/secrets-management/bin/secret-scan` exits 0
- [ ] `cd ansible && ansible-playbook --syntax-check playbooks/*.yml` exits 0
- [ ] Affected playbook(s) run with `--check --diff` against a staging host
- [ ] `pre-commit run --all-files` exits 0
- [ ] Live `verify.sh` is green after apply (if playbook is mutating)

## Risk

- What could break?
- How would you detect it?
- Rollback plan if needed?

## Checklist

- [ ] Conventional-commit subject (`<type>(<scope>): <imperative>`)
- [ ] No real IPs, hostnames, or tokens in tracked files
- [ ] If architectural change: ADR added or updated
- [ ] If new playbook: header comment block in EN; numeric prefix follows convention
- [ ] If new module: `README.md` + sample output for `examples/`
