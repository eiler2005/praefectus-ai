# Port audit runbook

## Goal

Confirm that no unexpected ports are open on the VPS, and no private services are bound to `0.0.0.0` instead of `127.0.0.1`.

## Run

```bash
# Standard audit (compares live state with docs/ports.md)
./modules/port-audit/bin/port-audit

# Same, plus save a snapshot to reports/
./modules/port-audit/bin/port-audit --save

# Show only current listeners (no comparison)
./modules/port-audit/bin/port-audit --live-only
```

Exit codes: `0` — OK, `1` — discrepancies found.

## Interpreting results

### NEW port (not in docs/ports.md)

A new public port (`0.0.0.0`) → **investigate immediately**:

1. `ssh deploy@<vps> 'ss -tlnp | grep :<port>'` — which process is listening
2. `ssh deploy@<vps> 'docker ps --format "{{.Names}} {{.Ports}}"'` — possibly a new container
3. If legitimate — add it to `docs/ports.md`
4. If unknown — see `docs/runbooks/security-incident.md`

A new private port (`127.0.0.1`) → less urgent, but still add it to `docs/ports.md`.

### MISSING port (in docs/ports.md but not listening)

Service is down or moved port:

1. Check `docker ps` — is the container running?
2. Run `./verify.sh` — it will catch the same problem from another angle
3. If the service moved port — update `docs/ports.md`

### UNSAFE BINDING

A private service is listening on `0.0.0.0` instead of `127.0.0.1`:

1. `ssh deploy@<vps> 'docker inspect <container> | grep -A5 PortBindings'`
2. Fix the bind in the application's `docker-compose.yml` (owner zone — coordinate)
3. Restart: `docker compose up -d <service>`
4. Re-run `port-audit` to confirm

## Updating docs/ports.md

After adding a new service:

1. Find the port: `ssh deploy@<vps> 'docker inspect <container> | grep HostPort'`
2. Add a row to the correct section (Public / Restricted / Private)
3. Run `./modules/port-audit/bin/port-audit` — must report 0 discrepancies

## Reserved port ranges

See `docs/ports.md` for the canonical port-range conventions used in this deployment. When adding a new service, pick a port from the appropriate range.
