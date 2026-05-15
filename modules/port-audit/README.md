# port-audit

Compares live `ss -tlnp` listeners on the VPS against the canonical port map in [`docs/ports.md`](../../docs/ports.md). Flags new ports, missing ports, and unsafe `0.0.0.0` bindings.

## Usage

```bash
./bin/port-audit             # compare live state with docs/ports.md
./bin/port-audit --live-only # show live listeners only
./bin/port-audit --save      # save snapshot to reports/port-audit-<ts>.txt
```

## What it does

- SSHs into the VPS and runs `ss -tlnp` and `ss -ulnp`.
- Parses `docs/ports.md` and reconciles the two.
- Reports:
  - **Unexpected** — listening but not in `docs/ports.md`.
  - **Missing** — in `docs/ports.md` but not listening.
  - **Unsafe binding** — bound to `0.0.0.0` when `docs/ports.md` requires `127.0.0.1`.

## When to run

- After deploying a new service — confirm the port shows up.
- Monthly security audit — catch drift.
- After any `docker compose up` in another owner's zone.

## Detailed runbook

[`docs/runbook.md`](docs/runbook.md).
