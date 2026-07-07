# ADR-0007: External watchdog and early resource alerts

**Status:** Accepted
**Date:** 2026-07-07

## Context

A managed VPS can become unavailable because of shared host pressure even when a
specific application is not the root cause. The July 2026 incident showed this
failure mode: OpenClaw containers produced OOM evidence and high swap pressure,
while dependent services looked broken from the outside because the whole VPS
was not reliably reachable.

An on-host monitor is necessary but insufficient. If the host is powered off,
hung, or unreachable at the network layer, its own monitor may not be able to
send an alert. SSH and ICMP are also poor assumptions for cross-host health in
this fleet: they can be blocked independently from the public service listener.

## Decision

PraefectusAI owns a two-layer host monitoring design:

- `vps-monitor.timer` runs on each managed VPS every five minutes and evaluates
  local host state: disk, available RAM, swap, load, Docker, expected
  containers, container restarts, Docker memory pressure, and recent
  kernel/cgroup OOM events.
- `vps-external-watchdog.timer` runs on each managed VPS every minute and checks
  peer VPS reachability from outside the checked host.
- The external probe uses TCP/443 by default because that listener is the
  stable public reachability contract for the managed hosts. Probe mode and
  port remain vault-driven.
- Telegram credentials stay in Ansible Vault. Missing credentials degrade to
  local logging and an explicit `TELEGRAM: not configured` result instead of
  failing the monitoring deployment.
- Expected monitoring timers are listed in inventory and verified by
  `99-verify.yml`, so disabled watchdogs become visible in the normal health
  gate.

## Consequences

Positive:

- Host pressure is visible before it becomes a full application outage.
- A completely stuck or powered-off host can be reported by a peer VPS.
- The design preserves the host-vs-application ownership boundary: PraefectusAI
  watches resource health and container-level symptoms, not app business logic.
- The reachability contract is explicit and testable with
  `modules/monitoring/bin/run-check --watchdog`.

Negative:

- Telegram alerts require vault variables to be present before notifications
  leave the host.
- TCP/443 reachability proves the public listener path, not full application
  correctness.
- Peer watchdogs reduce blind spots but do not replace provider-level alerts or
  backups.
- High swap usage can be detected here, but capacity fixes still need separate
  resource-limit or workload-isolation changes.
