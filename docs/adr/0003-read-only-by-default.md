# ADR-0003: Read-only by default; mutating requires explicit elevation

**Status:** Accepted
**Date:** 2026-04-15

## Context

LLM-driven operations have a default failure mode: confidently destructive actions taken without enough context. A naive agent given root SSH and a vague "free up disk" prompt can:

- `docker volume prune` and wipe application state.
- `apt full-upgrade` and break a service that depends on a pinned package.
- `git reset --hard` and lose uncommitted operator work.

Even careful operators are not immune — a typo in the wrong terminal is the source of countless post-mortems.

We needed a default posture that fails closed: the agent (or the operator) does the safe thing first and asks before doing anything irreversible.

## Decision

Every action in PraefectusAI is classified into one of three buckets:

1. **Read-only** — checks, audits, reports. Examples: `verify.sh`, `disk-report`, `secret-scan`, `port-audit`. These run without confirmation, in CI, and on every commit.
2. **Mutating, dry-runnable** — playbooks that change state but support `--check --diff`. Examples: every `10-*` through `70-*` playbook. The operator must run `--check --diff` first, review the diff, then explicitly apply.
3. **Destructive** — actions with no safe dry-run (force-push, volume prune, container removal). These require explicit operator approval per invocation; no agent or hook may run them automatically.

The classification is encoded in [`AGENTS.md`](../../AGENTS.md) as hard rules. Pre-commit hooks (`secret-scan`) and CI (`secret-scan`, `--syntax-check`, lint) only run read-only checks. Mutating playbooks can never run from CI.

## Consequences

**Positive:**

- A bad prompt in the worst case produces a verbose report, not a deleted volume.
- The dry-run / apply / verify rhythm makes diffs reviewable and incidents reconstructable.
- New contributors and new agents inherit the discipline by following AGENTS.md.

**Negative:**

- Slightly slower routine operations — the "two commands and a diff review" pattern adds 30 seconds vs. one-shot apply.
- The classification is convention, not enforcement. A determined human or agent can still bypass it. We accept this as an acceptable trade for the default-safe posture.
