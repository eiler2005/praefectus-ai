# Architecture Decision Records

This directory captures the *why* behind PraefectusAI's invariants. Each ADR follows Michael Nygard's classic format (Context, Decision, Consequences) and is short — usually 1–3 KB.

## Index

| # | Decision | Status |
|---|---|---|
| [0001](0001-host-vs-app-ownership.md) | Host-vs-app ownership boundary | Accepted |
| [0002](0002-vault-as-single-source-of-truth.md) | Vault as the single source of truth for secrets | Accepted |
| [0003](0003-read-only-by-default.md) | Read-only by default; mutating requires explicit elevation | Accepted |
| [0004](0004-raw-module-for-ssh-pipelining.md) | `raw` module + `gather_facts: false` for SSH pipelining compatibility | Accepted |
| [0005](0005-override-files-as-host-policy-zone.md) | `docker-compose.override.local.yml` as the host-policy zone | Accepted |
| [0006](0006-agents-md-contract-pattern.md) | `AGENTS.md` as a hard contract for LLM agents | Accepted |

## When to add an ADR

Open a new ADR when a change:

- Introduces or removes an architectural invariant.
- Modifies an ownership boundary (`docs/ownership-matrix.md`).
- Adds a new external dependency (cloud provider, alerting service, package manager).
- Creates a new playbook number range or naming convention.
- Reverses or supersedes a previous ADR (mark old one as `Superseded by ADR-NNNN`).

## Format

Copy the next number, use this skeleton:

```markdown
# ADR-NNNN: <Title>

**Status:** Accepted | Proposed | Superseded by ADR-XXXX
**Date:** YYYY-MM-DD

## Context
What forces are at play. The problem we're addressing.

## Decision
What we decided.

## Consequences
What changes as a result. Both positive and negative.
```
