# ADR-0002: Vault as the single source of truth for secrets

**Status:** Accepted
**Date:** 2026-04-15

## Context

Multiple projects deploy to the same VPS. Each historically maintained its own copy of access credentials (VPS host, SSH key path, deploy user, etc.) in its own inventory or `.env`. This led to:

- Drift when one project's IP / port / key changed and others were not updated.
- Real values leaking into project READMEs because there was no canonical place to look them up.
- Painful credential rotation — every project's repo had to be touched separately.

## Decision

`ansible/secrets/vault.yml` (encrypted with ansible-vault, AES-256) is the **single source of truth** for every VPS access credential.

- The vault holds: VPS host, SSH user, SSH port, SSH private-key path, deploy user, alert tokens, backup credentials, and any third-party API tokens used from the VPS context.
- Every other project that needs a VPS credential reads it via `ansible-vault view` or via a placeholder that is filled in from the vault at deploy time.
- The vault password (`~/.vault_pass.txt`) lives only on the operator's control machine, mode `0600`, with an offsite encrypted backup.
- A schema-only template lives at `ansible/secrets/vault.yml.example` (plaintext, in git) so new clones know which keys to fill.

## Consequences

**Positive:**

- One credential rotation step (edit vault, redeploy what reads it) instead of N.
- Sanitisation is enforceable: `secret-scan` ignores `vault.yml` (because it's encrypted) and treats every plaintext credential elsewhere as a leak.
- Onboarding a new operator is one well-defined handoff: vault password + control-machine setup.

**Negative:**

- Single point of failure: vault password loss is unrecoverable. Mitigated by the offsite-backup discipline in [`SECURITY.md`](../../SECURITY.md).
- Application owners must agree to the convention. Without buy-in, the vault becomes a duplicate rather than a source of truth.
- Adding a new credential is a multi-step process: edit the vault, mirror the schema into `vault.yml.example`, and re-run any playbook that reads it.
