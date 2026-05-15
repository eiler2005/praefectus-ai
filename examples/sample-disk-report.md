# Disk report — vps-prod — 20260512T063326

## Filesystem usage

```
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1        38G   26G   11G  71% /
tmpfs           2.0G     0  2.0G   0% /dev/shm
tmpfs           1.0M     0  1.0M   0% /run
```

## Top directories under /

```
12G    /var
8.4G   /opt
2.1G   /usr
1.6G   /root
820M   /home
```

## /var breakdown

```
9.8G   /var/lib/docker
1.2G   /var/log
580M   /var/cache
180M   /var/lib/apt
```

## /opt breakdown

```
4.2G   /opt/<app-2>          # gateway + workspace
1.7G   /opt/<app-3>          # knowledge-graph data
820M   /opt/<sync-vault>     # bidirectional Syncthing target
640M   /opt/<app-4>          # router service
460M   /opt/<app-1>          # bridge data + sessions
180M   /opt/<routing-side>   # stealth routing config
```

## Docker layer breakdown

```
TYPE            TOTAL     ACTIVE    SIZE      RECLAIMABLE
Images          14        13        9.793GB   8.897GB (90%)
Containers      13        13        395MB     0B (0%)
Local Volumes   11        11        1.714GB   0B (0%)
Build Cache     0         0         0B        0B
```

90 % of image storage is reclaimable — most candidates are old rollback tags.

## Top large files

```
410M   /opt/<app-3>/data/vector-store/snapshot-2026-05.db
180M   /var/log/journal/<machine-id>/system@*.journal
120M   /opt/<app-2>/workspace/imports/2026-05-12.bundle
```

## Dangling volumes

```
None
```

## Suggested actions

- `ansible-playbook playbooks/10-disk-cleanup.yml --check --diff` — review prune plan.
- Check the 90 % reclaimable images: most are app rollback tags older than 7 days.
- `<app-2>` workspace imports may be safe to clean — escalate to owner.

## How to read this report

This is the output of `./modules/disk-observatory/bin/disk-report`. It is a
standalone audit (no Ansible) — fast to run when `verify.sh` reports `disk: WARN`
and you want a richer breakdown before deciding what to clean.

See [`docs/runbooks/disk-full.md`](../docs/runbooks/disk-full.md) for the full decision tree.
