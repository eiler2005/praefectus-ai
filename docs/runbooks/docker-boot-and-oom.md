# Docker boot order and OOM recovery

This runbook handles shared-VPS incidents where a public data-plane is
unhealthy, Docker or an edge backend may not have started correctly, or host
resource pressure is visible. It is deliberately deployment-neutral: use
placeholders, role names and redacted status rather than addresses, credentials,
container identifiers, raw logs or provider-console screenshots.

## What this runbook owns

PraefectusAI owns the host: Docker daemon, systemd, UFW, host monitoring and
host-level resource overrides. It does not own an application's compose file,
reverse-proxy configuration, resolver configuration or edge protocol. Those
belong to their application/routing project. See
[ownership-matrix.md](../ownership-matrix.md) before changing anything outside
the host layer.

The owner of a routing resolver may install a narrow Docker unit exception when
the resolver must wait for a Docker bridge. PraefectusAI detects its host-level
symptom—a current-boot `systemd` ordering cycle—but does not overwrite the
other owner's unit or runtime configuration.

## First classify the failure

Do not use SSH success, an admin page or a provider-console graph as proof that
the public data-plane works. The application/routing owner must first run its
active end-to-end probe. Then use this host-side read-only classification:

```bash
sudo systemctl is-active docker
sudo systemctl show -p After docker.service
sudo systemctl cat docker.service
sudo journalctl -b -u docker -u <resolver-service> --no-pager
sudo docker ps --format '{{.Names}} {{.Status}}'
sudo docker stats --no-stream
```

Treat provider firewall and host UFW as independent controls. A provider rule
may allow the public listener while UFW rejects a current operator source; an
SSH allow does not validate the public data-plane. Do not disable UFW or add a
broad source allow to “test” the path.

## Docker/resolver boot-order cycle

The guarded-resolver failure pattern is:

```text
resolver waits for Docker bridge
Docker waits for nss-lookup.target
resolver supplies nss-lookup.target
```

This is a dependency cycle. `systemd` may break it differently across boots;
the consequence can be an inactive Docker daemon, missing edge containers, or
an edge path that fails while unrelated host access still works.

### Evidence and alert level

`vps-monitor.py` records a `WARN` named `docker_boot_ordering_cycle` when the
current boot's systemd journal contains a Docker `ordering cycle` or
`dependency cycle`.
It intentionally reports no raw journal line. A cycle is `WARN`, not an
automatic restart trigger: restarting Docker can drop unrelated applications
and does not repair a bad unit graph.

For a confirmed cycle:

1. Identify the exact units with `systemctl cat` and `systemctl show -p After`.
2. Identify the owner from the ownership matrix.
3. Have that owner correct the source-controlled unit/role, run its local
   checks, and obtain explicit approval before any deploy.
4. After a controlled apply/restart, verify Docker, the resolver, the affected
   backend and the owner's active end-to-end probe.

Do not add a compensating drop-in blindly. `After=` relations accumulate; a
new drop-in may retain the dependency that creates the cycle. Do not edit an
application-owned system unit from this repository.

### Package-update gate

Before a planned Docker or systemd package update, record the existing unit
graph. Before the next reboot or Docker restart, compare it with the intended
source-controlled override:

```bash
sudo systemctl cat docker.service
sudo systemctl show -p After docker.service
sudo systemd-analyze verify docker.service <resolver-service>
sudo journalctl -b -u docker -u <resolver-service> --no-pager
```

The gate passes only when there is no Docker dependency on a lookup target
provided by the resolver that waits for Docker, and no current-boot ordering
cycle. A vendor unit change is a coordination event for the owning project,
not a reason to remove the guard or broaden restarts.

## OOM and sustained CPU pressure

Recent kernel/cgroup OOM evidence and high CPU are capacity signals. They are
not proof of the boot-order root cause, even if they occur in the same incident.
Keep the two tracks separate:

- a boot-order cycle is proven by the unit graph and current-boot journal;
- OOM is proven by the monitor evidence, restart counts and container/resource
  data;
- a public data-plane outage is closed only by the owning active end-to-end
  probe, not because a container is running.

Read-only OOM triage:

```bash
sudo docker stats --no-stream
sudo docker ps --format '{{.Names}} {{.Status}}'
sudo journalctl -k --since '<lookback>' --no-pager
sudo docker inspect <container> --format '{{.HostConfig.Memory}} {{.HostConfig.NanoCpus}} {{.HostConfig.PidsLimit}} {{.HostConfig.RestartPolicy.Name}}'
```

For an application container that has exhausted a bounded `on-failure` policy,
treat the stop as host protection first. Do not change it to an unlimited
restart loop. Coordinate its memory/CPU/PID override with the application owner
and recreate only the affected service after the resource cause is understood.
Never use `docker compose down -v`, `docker volume prune`, unfiltered system
prune or a mass restart as OOM recovery.

## Access recovery boundaries

Use provider rescue/console only when normal access is genuinely unavailable
and only for a confirmed recovery action. A temporary host-firewall rule may
name one verified operator source for a short maintenance window; remove it and
reload the intended policy before closing the incident. Never document the
source value in Git, and never persist a broad “temporary” rule.

## Closure checklist

- [ ] The application/routing owner’s active data-plane probe is green.
- [ ] Docker and the affected service are active; expected containers are
      running.
- [ ] No Docker boot-order cycle appears in the current boot.
- [ ] Provider firewall and UFW were checked independently; temporary access
      rules, if any, were removed.
- [ ] OOM/capacity evidence is either absent or tracked as a separate follow-up.
- [ ] The incident note contains only sanitized statuses and ownership facts.

For routing-specific active probes and resolver-unit remediation, see the
companion [GhostRoute managed-egress boot recovery guide](https://github.com/eiler2005/ghostroute/blob/master/docs/managed-egress-vps-boot-recovery.md).
