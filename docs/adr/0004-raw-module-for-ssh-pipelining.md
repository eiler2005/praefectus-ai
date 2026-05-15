# ADR-0004: `raw` module + `gather_facts: false` for SSH pipelining compatibility

**Status:** Accepted
**Date:** 2026-04-18

## Context

The reference VPS hardens sshd with `MaxSessions 6` (up from a stricter `MaxSessions 2`). Even at 6, default Ansible behaviour exhausts the session budget during a multi-task playbook:

- `gather_facts: true` opens additional sessions to collect setup facts.
- The `command` and `shell` modules use Ansible's full module-execution path, which transfers a Python wrapper, executes it, and tears it down — multiple sessions per task.
- ControlMaster (when enabled) batches sessions through a single channel, but introduces stale-socket failures on slow networks and competing controllers.

The symptoms we hit before settling on this decision:

- "Connection timed out during banner exchange" mid-playbook, even when sshd was healthy.
- Mysterious task failures that disappeared on retry.
- Inability to run multiple playbooks in parallel without `MaxStartups` queue saturation.

## Decision

Every PraefectusAI playbook uses:

- `gather_facts: false` at the play level — no setup-fact session.
- `ansible.builtin.raw` for any command that doesn't strictly need a Python module — the operation runs over a single `ssh` invocation.
- `ControlMaster=no` in `ansible.cfg` — fresh sessions per task; no stale-socket surprise.
- `ANSIBLE_SSH_ARGS="-o ServerAliveInterval=30 -o ServerAliveCountMax=10"` for long-running operations.

Where a real Ansible module is required (e.g. `copy`, `template`, `systemd`), it is used sparingly and the play's session budget is sized accordingly.

## Consequences

**Positive:**

- Playbooks complete reliably on a low-`MaxSessions` host.
- No dependency on ControlMaster — works the same on macOS, Linux, CI, and ephemeral VMs.
- Each task is one SSH invocation, which makes debugging straightforward (`ssh -v` shows exactly what happened).

**Negative:**

- Loses `gather_facts` — every variable that would normally come from `ansible_facts` must be derived inline.
- Loses Ansible module richness — error handling, idempotency, type conversion all become the playbook author's job. Tasks must use `changed_when` and `failed_when` explicitly.
- Roles built around "real" Ansible modules don't transplant cleanly. PraefectusAI keeps logic inline in playbooks rather than decomposing into reusable role tasks.
