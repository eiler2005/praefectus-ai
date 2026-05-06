# Maintenance schedule — vps-prod

Профилактические процедуры, их периодичность и ответственные.

---

## Еженедельно — автоматически (systemd timer)

**Таймер:** `vps-weekly-cleanup.timer` (Sun 03:00 UTC)  
**Скрипт:** `/usr/local/bin/vps-weekly-cleanup.sh`  
**Лог:** `/var/log/vps-weekly-cleanup.log`  
**Установить/обновить:** `ansible-playbook playbooks/11-schedule-cleanup.yml`

| Операция | Команда | Безопасность |
|---|---|---|
| apt clean | `apt-get clean` | ОС-уровень, данные не затрагиваются |
| apt autoremove | `apt-get autoremove --purge` | ОС-уровень |
| journal vacuum | `journalctl --vacuum-time=14d --vacuum-size=500M` | логи ≤14d и ≤500MB |
| docker container prune | `--filter "until=72h"` | только остановленные >3d |
| docker image prune | `--filter "until=168h"` | только неиспользуемые >7d |
| docker builder prune | `--filter "until=168h"` | build cache |

**Никогда автоматически:** `docker volume prune` — volumes хранят state.

### Получить лог с VPS на Mac

```bash
# Текущий месяц
./modules/maintenance-journal/bin/cleanup-fetch

# Все месяцы
./modules/maintenance-journal/bin/cleanup-fetch --all

# Только в stdout (без записи файла)
./modules/maintenance-journal/bin/cleanup-fetch --stdout
```

Результат сохраняется в `reports/maintenance/YYYY-MM.md`.

---

## Еженедельно — вручную (ручной запуск)

Запускать после проверки `verify.sh` или по необходимости.

```bash
# Ручная чистка (с отчётом в reports/cleanup-*.md)
ansible-playbook playbooks/10-disk-cleanup.yml --check  # dry-run
ansible-playbook playbooks/10-disk-cleanup.yml          # apply

# Проверка что всё живо
./verify.sh
```

---

## Ежемесячно — вручную

Выполнять в первых числах месяца. Ориентир: ~30 минут.

| Задача | Команда | Примечание |
|---|---|---|
| Dangling volumes review | `ssh deploy@<vps> 'docker volume ls -f dangling=true'` | Инспектировать каждый; удалять только осиротевшие |
| `/opt/*` размеры | `ssh deploy@<vps> 'du -sh /opt/* \| sort -hr'` | Если аномальный рост — разбираться с владельцем |
| lightrag/data audit | `ssh deploy@<vps> 'du -sh /opt/lightrag/data'` | При >5GB — обсудить переиндексацию |
| Syncthing conflicts | `ssh deploy@<vps> 'find /opt/obsidian-vault -name "*.sync-conflict-*" \| head -20'` | Разрешить вручную |
| SSH authorized_keys | `ssh deploy@<vps> 'cat ~/.ssh/authorized_keys'` | Подтвердить что нет лишних ключей |
| Apt pinned versions | `ssh deploy@<vps> 'apt list --upgradable 2>/dev/null'` | Проверить pending security updates |
| Записать в журнал | `docs/journal/YYYY-MM.md` | Любые нетривиальные изменения |

---

## Ежеквартально — вручную

| Задача | Как | Примечание |
|---|---|---|
| Secret rotation review | Просмотр vault + authorized_keys | Когда последний раз меняли? |
| Image vulnerability scan | `trivy image <name>` для всех running | Критичные CVE — обновить image |
| DR drill (опц.) | Restore test на fresh CX23 | Проверяет backup + bootstrap |
| Memory budget review | `docker stats --no-stream` vs limits в docs/containers.md | Скорректировать лимиты при drift |

---

## Красные линии (НИКОГДА автоматом)

- `docker volume prune` — volumes = state приложений
- `docker system prune -a` без `--filter "until=Nh"`
- `docker compose down -v` в `/opt/*`
- `apt full-upgrade` или `do-release-upgrade`
- Перезагрузка VPS без явного разрешения
- Удаление содержимого `/opt/<app>/data` или `/opt/<app>/workspace`

---

## Файлы и артефакты

| Артефакт | Где |
|---|---|
| Отчёты ручной чистки | `reports/cleanup-<ts>.md` (gitignored) |
| Агрегированные weekly logs | `reports/maintenance/YYYY-MM.md` (gitignored) |
| Журнал ручных изменений | `docs/journal/YYYY-MM.md` (в git) |
| Weekly cleanup лог на VPS | `/var/log/vps-weekly-cleanup.log` |
