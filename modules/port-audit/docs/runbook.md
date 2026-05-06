# Port audit runbook

## Цель

Убедиться что на VPS нет неожиданных открытых портов и нет небезопасных bindings (приватный сервис торчит на 0.0.0.0).

## Запуск

```bash
# Стандартный audit (сравнение с docs/ports.md)
./modules/port-audit/bin/port-audit

# + сохранить отчёт в reports/
./modules/port-audit/bin/port-audit --save

# Только посмотреть текущие listeners (без сравнения)
./modules/port-audit/bin/port-audit --live-only
```

Результат: exit 0 — OK, exit 1 — проблемы найдены.

## Интерпретация результатов

### NEW port (не в docs/ports.md)

Новый публичный порт (0.0.0.0) → **немедленная проверка**:
1. `ssh deploy@<vps> 'ss -tlnp | grep :<port>'` — какой процесс слушает
2. `ssh deploy@<vps> 'docker ps --format "{{.Names}} {{.Ports}}"'` — может, новый контейнер
3. Если легитимный — добавить в `docs/ports.md`
4. Если неизвестный — см. `docs/runbooks/security-incident.md`

Новый приватный порт (127.0.0.1) → менее срочно, но добавить в `docs/ports.md`.

### MISSING port (в docs/ports.md, но не слушает)

Сервис упал или изменил порт:
1. Проверить `docker ps` — контейнер running?
2. Проверить `./verify.sh` — найдёт проблему
3. Если сервис поменял порт — обновить `docs/ports.md`

### UNSAFE BINDING

Приватный сервис слушает на 0.0.0.0 вместо 127.0.0.1:

1. `ssh deploy@<vps> 'docker inspect <container> | grep -A5 PortBindings'`
2. Исправить bind в docker-compose файле (зона владельца сервиса)
3. Перезапустить: `docker compose up -d <service>`
4. Повторно запустить port-audit для подтверждения

## Обновление docs/ports.md

После добавления нового сервиса:
1. Узнать порт: `ssh deploy@<vps> 'docker inspect <container> | grep HostPort'`
2. Добавить строку в правильную секцию (Public/Private)
3. Запустить `./modules/port-audit/bin/port-audit` — должен показать 0 расхождений

## Зарезервированные диапазоны

| Диапазон | Назначение |
|---|---|
| 8100–8199 | openclaw_firststeps — новые сервисы |
| 9100–9199 | мониторинг (node_exporter и др.) |
| 18000–18999 | openclaw internal |
| 20000–20999 | AI routing / omniroute |

При добавлении нового сервиса выбирать порт из подходящего диапазона.
