# ADR-0005: `docker-compose.override.local.yml` as the host-policy zone

**Status:** Accepted
**Date:** 2026-04-22

## Context

PraefectusAI needs to apply host-level policy to containers it does not own:

- Memory limits to prevent OOM cascades on a small VPS.
- Restart policies for resilience.
- Logging caps to prevent log bloat.

Three options were on the table:

1. **Edit the application's `docker-compose.yml`** — direct, but breaks the ownership boundary. The application owner's next deploy would either revert our changes or merge-conflict.
2. **Use Docker daemon defaults** (`daemon.json`) — coarse-grained; same defaults for every container; can't differentiate critical from optional.
3. **Use compose's override file mechanism** — well-defined merge semantics, opt-in per stack.

## Decision

PraefectusAI writes `docker-compose.override.local.yml` next to the application's main compose file. By convention:

- Compose's auto-loaded merge order is `docker-compose.yml + docker-compose.override.yml + docker-compose.override.local.yml` (the `.local.yml` is *not* auto-loaded by compose; we make it explicit by naming or by `-f` chains in deploy scripts).
- The file contains **only** host-level constraints: `mem_limit`, `cpus`, `restart`, `logging.driver`, `logging.options`.
- It does **not** change `services`, `ports`, `env`, `volumes`, `image`, or `command`.

Playbooks `60-docker-limits.yml` and `70-docker-limits-critical.yml` write these files via Ansible templates. Operators can verify with `docker inspect <container> | grep -i memory`.

The boundary is documented in [`docs/ownership-matrix.md`](../ownership-matrix.md) under "What 'PraefectusAI override' means".

## Consequences

**Positive:**

- Host policy lives in one well-known file per stack, not scattered across daemon configs.
- Application owners can ignore the override file entirely — they don't read it, don't merge it, don't worry about it.
- Easy to audit: every override file is rendered by a known playbook; drift is caught by re-running the playbook.

**Negative:**

- Some compose toolchains (older `docker-compose v1`, certain CI scripts) don't auto-load `.local.yml`. Operators must invoke `docker compose -f ... -f docker-compose.override.local.yml` explicitly when restarting from the application directory.
- Adds one more file per stack — small but visible cognitive load.
- Application owners can still over-specify limits in their main compose; PraefectusAI's override would lose. Coordination via `ownership-matrix.md` mitigates this.
