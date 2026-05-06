# Health rules — vps-prod

Формальные критерии состояния сервера. Используются в `99-verify.yml`, `health-trend`, и будущем мониторинге.

---

## Статусы

| Статус | Цвет | Значение |
|---|---|---|
| **OK** | зелёный | Всё в норме, действий не требуется |
| **WARN** | жёлтый | Подозрительно, наблюдать; действий пока не требуется |
| **CRIT** | красный | Требует немедленного внимания |

---

## Правила по метрикам

### Диск (`/`)

| Метрика | OK | WARN | CRIT |
|---|---|---|---|
| `disk_used_pct` | < 80% | 80–89% | ≥ 90% |

**Действия:**
- WARN → log, проверить `./modules/disk-observatory/bin/disk-report`
- CRIT → log + Telegram alert + запустить `10-disk-cleanup.yml`

### Память (RAM)

| Метрика | OK | WARN | CRIT |
|---|---|---|---|
| `mem_available_mb` | > 500 MB | 200–500 MB | < 200 MB |
| `swap_used_pct` | < 40% | 40–79% | ≥ 80% |

**Действия:**
- WARN → log; проверить `docker stats --no-stream` на кандидатов в OOM
- CRIT → log + Telegram alert + топ-5 процессов по RSS в alert

### Load average (5 min)

| Метрика | OK | WARN | CRIT |
|---|---|---|---|
| `load_5min` | < 2.0 | 2.0–3.9 | ≥ 4.0 |

**Действия:**
- WARN → log
- CRIT → log + Telegram alert

### Docker daemon

| Метрика | OK | WARN | CRIT |
|---|---|---|---|
| `systemctl is-active docker` | active | — | inactive |

**Действия:**
- CRIT → Telegram alert с последними 20 строками `journalctl -u docker`

### Контейнеры (vault_expected_containers)

| Метрика | OK | WARN | CRIT |
|---|---|---|---|
| Все expected_containers running | все | — | хотя бы один упал |
| Healthcheck (http/tcp/docker) | ok | — | fail |
| RestartCount за 24h | 0–2 | 3–9 | ≥ 10 |

**Действия:**
- Контейнер не running → CRIT + Telegram с именем + последние 20 строк `docker logs`
- RestartCount ≥ 3 → WARN в лог, проверить `docker logs <name>`

### UFW

| Метрика | OK | WARN | CRIT |
|---|---|---|---|
| UFW status | active | not installed | inactive |

### OOM events

| Метрика | OK | WARN | CRIT |
|---|---|---|---|
| `dmesg \| grep "oom-kill"` за 1h | 0 | — | > 0 |

**Действия:**
- CRIT → Telegram alert с именем процесса; проверить лимиты в `docs/containers.md`

---

## Правила для JSON-отчётов

Verify role пишет параллельно два файла:
- `reports/verify-<ts>.md` — читаемый Markdown
- `reports/health/<ts>.json` — машиночитаемый JSON для тренд-анализа

### Формат JSON

```json
{
  "timestamp": "2026-05-03T09:00:00Z",
  "host": "vps-prod",
  "overall_status": "ok",
  "metrics": {
    "disk_pct": 78,
    "mem_available_mb": 980,
    "load_5min": 0.42,
    "swap_used_pct": 12
  },
  "checks": [
    {"check": "ssh",           "status": "ok",   "detail": "connected"},
    {"check": "disk",          "status": "ok",   "detail": "78%"},
    {"check": "memory",        "status": "ok",   "detail": "980M available"},
    {"check": "load_5min",     "status": "ok",   "detail": "0.42"},
    {"check": "docker_daemon", "status": "ok",   "detail": "active"},
    {"check": "container_running:openclaw-openclaw-gateway-1", "status": "ok", "detail": "owner=openclaw_firststeps running"}
  ]
}
```

**`overall_status`** = `fail` если хоть один check `fail`; `warn` если хоть один `warn`; иначе `ok`.

---

## Тренд-анализ (health-trend)

```bash
./modules/health-trends/bin/health-trend          # последние 10 проверок
./modules/health-trends/bin/health-trend --last 30  # последние 30
./modules/health-trends/bin/health-trend --trend disk  # только диск
```

Выявляет:
- Диск: растёт / стабилен / уменьшился (тренд на 7/30 точках)
- Контейнеры с RestartCount > 0
- Контейнеры регулярно близко к лимиту памяти (> 80% от mem_limit) → OOM-кандидаты

---

## Ротация отчётов

| Тип | Хранить | Как |
|---|---|---|
| `reports/verify-*.md` | последние 100 | `ls -t reports/verify-*.md \| tail -n +101 \| xargs rm -f` |
| `reports/health/*.json` | последние 100 | аналогично |
| `reports/cleanup-*.md` | последние 30 | аналогично |

Скрипт ротации: запускать вручную или добавить в `10-disk-cleanup.yml` как пост-шаг.
