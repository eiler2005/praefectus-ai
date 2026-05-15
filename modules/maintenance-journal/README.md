# maintenance-journal

Pulls the weekly auto-cleanup log from the VPS and aggregates it by month into `reports/maintenance/<YYYY-MM>.md`.

## Usage

```bash
./bin/cleanup-fetch                  # current month
./bin/cleanup-fetch --all            # every month (full history)
./bin/cleanup-fetch --stdout         # print only, do not write file
```

## What it does

- SSHs into the VPS and reads `/var/log/vps-periodic-cleanup.log` (fallback: legacy `/var/log/vps-weekly-cleanup.log`).
- Groups runs by month.
- Writes a Markdown summary per month to `reports/maintenance/<YYYY-MM>.md` (gitignored).

## When to run

- Once a month — confirm the timer ran every Sunday and what it freed.
- After a cleanup-related incident — review what auto-cleanup did or did not do.

## Output sample

See [`examples/sample-cleanup-log.md`](../../examples/sample-cleanup-log.md).
