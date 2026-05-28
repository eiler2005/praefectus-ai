# Sample Telegram alert — vps-monitor.py

This is what `vps-monitor.py` posts to the operator Telegram channel when it crosses a `CRIT` threshold (rules in [`docs/runbooks/health-rules.md`](../docs/runbooks/health-rules.md)).

## CRIT — disk full

```
🔴 CRIT vps-hetzner-prod — Disk usage 92% (>=90% CRIT)

  / : 35.1G/38.0G (92%) used
  Swap: 38% used
  RAM available: 1854 MB
  Load 5min: 1.42

Top space hogs (du):
  4.6G   /opt/<app-2>/workspace
  4.2G   /opt/<app-3>/data
  3.1G   /var/lib/docker/overlay2

Action: ./verify.sh and review docs/runbooks/disk-full.md
```

## WARN — swap pressure

```
🟡 WARN vps-hetzner-prod — Swap usage 73% (>=40% WARN)

  / : 25.6G/38.0G (71%) used
  RAM available: 1024 MB
  Swap: 73% used (1496/2048 MB)
  Load 5min: 2.31

Top RSS processes:
  1.2G   <critical-gateway> (PID 8421)
  640M   <app-3>/python (PID 8512)
  410M   <app-4>/node (PID 8602)

Hint: container near memory limit?
  Check: docker stats --no-stream
```

## Test alert

When you want to confirm the bot/chat are wired up without waiting for a real event:

```
🧪 TEST vps-hetzner-prod — Telegram alerting healthy
  Bot: @<your-bot>
  Chat: -100<chat-id>
  Topic: <topic-id> (if set)
  Time: 2026-05-15T08:00:00Z
```

Trigger with:

```bash
./modules/monitoring/bin/run-check --test-alert
```

## Notes

- Alerts only fire on transitions to `WARN` / `CRIT`. A persistent `CRIT` state does not flood the channel; `vps-monitor.py` deduplicates within a 1 h window.
- If you don't see alerts, vault tokens (`vault_tg_infra_bot_token`, `vault_tg_infra_chat_id`) are likely unset — see [`ansible/playbooks/20-monitoring.yml`](../ansible/playbooks/20-monitoring.yml) header.
