# Cleanup report — vps-prod — 20260512T063447

## Disk

| | Value |
|---|---|
| Before | 70% (25520M used) |
| After  | 71% (25642M used) |
| Freed  | -122M |

## APT

- apt clean: changed
- apt autoremove: no change

## Journal vacuum

- Time (14d): Vacuuming done, freed 0B of archived journals from /var/log/journal.
- Size (500M): Vacuuming done, freed 0B of archived journals from /var/log/journal/<machine-id>.

## Docker prune

- Container (until=72h): Total reclaimed space: 0B
- Image     (until=168h): Total reclaimed space: 0B
- Builder:  Total:	0B
- Dangling volumes: 0 (NEVER auto-pruned)

## Docker disk (after)

```
TYPE            TOTAL     ACTIVE    SIZE      RECLAIMABLE
Images          14        13        9.793GB   8.897GB (90%)
Containers      13        13        395MB     0B (0%)
Local Volumes   11        11        1.714GB   0B (0%)
Build Cache     0         0         0B        0B
```

## Notes

- Net disk delta is **negative** (-122 MB) because the `until=` filters protected fresh-but-unused images. This is expected behaviour — `10-disk-cleanup.yml` errs on the side of safety.
- The 90 % reclaimable images are a known signal: at the next manual review (see
  [`docs/runbooks/disk-full.md`](../docs/runbooks/disk-full.md) Step 2), the
  operator decides which old rollback tags to drop.
- The weekly `vps-cleanup.timer` produces a similar report at `/var/log/vps-periodic-cleanup.log`. Pull it with:

  ```bash
  ./modules/maintenance-journal/bin/cleanup-fetch
  ```
