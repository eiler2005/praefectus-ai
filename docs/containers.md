# Container registry

Inventory of every Docker container running on the VPS. Update when adding or removing services.

> **This file is meant to be customised for your deployment.** The structure below is the template; fill in the rows with your own containers. A complete sanitised reference inventory from the maintainer's deployment lives at [`examples/sample-containers.md`](../examples/sample-containers.md).

---

## Criticality and memory limits

| Container | Criticality | `mem_limit` | Notes |
|---|---|---|---|
| `deploy-bridge-1` | CRITICAL | 512m | `maxtg_bridge` production bridge; MAX egress uses reverse Channel M through VPS docker bridge listener |
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

### `deploy-bridge-1`

| Parameter | Value |
|---|---|
| Owner | `maxtg_bridge` |
| Image | `maxtg-bridge:prod` |
| Ports | none published; container reaches Channel M via Docker bridge gateway on `18057/tcp` |
| Volumes | `/opt/maxtg-bridge/data`, `config.yaml`, `config.local.yaml` |
| Healthcheck | Docker healthcheck from bridge runtime heartbeat |
| `mem_limit` | 512m from application compose |
| Role | MAX -> Telegram bridge; Telegram direct from VPS; MAX API/CDN through reverse Channel M |
| Data | SQLite DB, MAX session and runtime health files under `/opt/maxtg-bridge/data` |
| Deploy | `maxtg_bridge` repo; `infra/ansible/deploy.yml` and `infra/ansible/channel-m-reverse.yml` |
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
