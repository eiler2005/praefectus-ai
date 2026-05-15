# Container registry

Inventory of every Docker container running on the VPS. Update when adding or removing services.

> **This file is meant to be customised for your deployment.** The structure below is the template; fill in the rows with your own containers. A complete sanitised reference inventory from the maintainer's deployment lives at [`examples/sample-containers.md`](../examples/sample-containers.md).

---

## Criticality and memory limits

| Container | Criticality | `mem_limit` | Notes |
|---|---|---|---|
| `<container-1>` | CRITICAL | `<NN>m` | Source of limit (e.g. `70-docker-limits-critical.yml`) |
| `<container-2>` | HIGH | `<NN>m` | |
| `<container-3>` | MEDIUM | `<NN>m` | |
| `<container-4>` | LOW | `<NN>m` | |

Criticality scale:

- **CRITICAL** — service unavailability is a user-facing outage
- **HIGH** — degraded mode acceptable for minutes; backup-recoverable
- **MEDIUM** — internal automation; can be restarted at leisure
- **LOW** — best-effort; failure does not affect users

---

## Per-container detail (template)

For every container, document:

```
### <container-name>

| Parameter | Value |
|---|---|
| Owner | <owner-project> |
| Image | <image:tag> |
| Ports | <bind-spec> (e.g. 127.0.0.1:8080) |
| Volumes | <list of mounted paths> |
| Healthcheck | <command or "none"> |
| `mem_limit` | <limit> + source playbook |
| Role | <one line: what it does for the system> |
| Data | <where state lives, recovery story> |
| Deploy | <which repo/script/playbook deploys it> |
```

---

## Memory budget

Document the running memory shape so you can plan limits:

```
OS + system daemons:           ~500 MB
<critical-1>:                  <NN> MB    (limit <NNN>m)
<critical-2>:                  <NN> MB    (limit <NNN>m)
<medium-1>:                    <NN> MB    (limit <NNN>m)
…
────────────────────────────────────
Total measured:               ~<NNNN> MB
```

**Update the measured column with:** `docker stats --no-stream`.

---

## Verification commands

```bash
# Current RAM usage per container
docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}"

# Verify a limit is applied after `docker compose up -d`
docker inspect <container> | grep -i memory

# Every limit at once
docker inspect $(docker ps -q) | jq '.[] | {Name: .Name, MemLimit: .HostConfig.Memory}'
```
