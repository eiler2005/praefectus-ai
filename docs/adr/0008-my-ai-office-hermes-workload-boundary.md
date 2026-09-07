# ADR-0008: Record My AI Office as an app-owned Hermes workload

## Context

My AI Office now runs as the `benka-hermes` Docker Compose project on the
Hermes workload host. It has thirteen cooperating containers, durable Redis and
knowledge state, private profile manifests, a Telegram polling Gateway, and a
dashboard exposed through an mTLS-protected listener.

The host needs to notice a stopped container, a resource-pressure pattern, an
unexpected listener, or a missing backup. None of those facts make the host
administrator the correct owner of the office's schedules, credentials, Redis
streams, delivery recovery, model routes, knowledge indexes, or Compose
lifecycle.

## Decision

PraefectusAI treats `/opt/benka-hermes` as an application-owned boundary.

- The production inventory records the application directory and all thirteen
  expected container names for read-only health verification.
- The host backs up only the designated `state/` and `private/` paths through
  encrypted restic, without reading their contents or adding them to Git.
- The port map records the single panel listener on `8451`; Caddy's TLS, mTLS,
  dashboard authentication, certificates, and route configuration remain with
  `my-ai-office`.
- The application owns Compose files, images, manifests, secrets, queues,
  profiles, model configuration, schedules, container restarts, and all
  business-level acceptance.
- A host warning records evidence and names the application owner. It does not
  trigger a `docker compose` action, replay a job, or change application state.

## Consequences

Positive:

- Host monitoring and backups cover the office without giving infrastructure
  automation authority over private business data or agent actions.
- `99-verify.yml` can distinguish an absent office container from unrelated
  neighbouring workloads such as `reddit-compass`.
- The encrypted backup contract supports recovery without relying on a Mac-held
  copy as the primary transfer medium.

Negative:

- A green host check does not prove Telegram ingress, model-provider access,
  queue correctness, or confirmed delivery; those remain My AI Office checks.
- Restoring the application requires its own recovery runbook to reconcile
  queues, receipts, credentials, and application state before it is started.
