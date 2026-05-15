# ADR-0001: Host-vs-app ownership boundary

**Status:** Accepted
**Date:** 2026-04-15

## Context

PraefectusAI runs on a VPS that hosts multiple Docker applications, each with its own deployment pipeline and ownership. Without a clear boundary, two failure modes are easy to fall into:

1. PraefectusAI's automation accidentally mutates application data (e.g. `docker compose down -v` wipes a volume).
2. Each application project re-implements host-level concerns (disk cleanup, monitoring, security baseline), leading to drift and conflict.

We needed a single, enforceable boundary between "the host" and "the apps that run on the host".

## Decision

PraefectusAI owns:

- OS packages, kernel, sysctl
- `/etc/{ssh,ufw,fail2ban}` (host security)
- `/var/log`, `/var/lib/docker` (system cleanup)
- `deploy` user home, Docker daemon
- Host-level monitoring, backups, access secrets

Application owners own everything inside `/opt/<app>/`:

- `docker-compose.yml`, images, env files
- Application data, workspaces, configs
- Application-level health and incident response

PraefectusAI may write **only** `docker-compose.override.local.yml` next to an application's compose file (see [ADR-0005](0005-override-files-as-host-policy-zone.md)). It must never edit the application's own compose, env, or data.

The boundary is documented authoritatively in [`docs/ownership-matrix.md`](../ownership-matrix.md) and enforced by hard rules in [`AGENTS.md`](../../AGENTS.md).

## Consequences

**Positive:**

- Each project can migrate to PraefectusAI gradually — no one needs to rewrite their deploy.
- "Who deployed this?" has a deterministic answer.
- Host maintenance can be automated safely, because PraefectusAI never touches application state.
- Incident response has a clear escalation path (PraefectusAI alerts, application owner restarts).

**Negative:**

- Adds coordination overhead for changes that span the boundary (e.g. a memory-limit policy that requires application restart).
- Requires every new application to be added to `ownership-matrix.md` explicitly — easy to forget.
- The boundary is enforced by convention + agent contract, not by OS-level isolation. A misbehaving operator (or agent) can still cross it.
