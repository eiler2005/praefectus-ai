# Runbook: disk-full

Что делать когда диск VPS заполнился. От лёгкого случая (>80%) до тяжёлого (>95%).

## Триггер

- `verify.sh` возвращает `disk: WARN` (≥80%) или `FAIL` (≥90%).
- Контейнер не стартует с `no space left on device`.
- Telegram алёрт (когда появится monitoring).

## Шаг 0 — diagnose

Никогда не запускай чистку вслепую. Сначала пойми что разрослось.

```bash
./modules/disk-observatory/bin/disk-report
```

Прочитай отчёт. Обрати внимание на:
- `du -sh /var/log` — много логов?
- `du -sh /var/lib/docker` — много images/build cache?
- `du -sh /opt/lightrag/data` — KG распух?
- Top large files — есть аномалии?
- Dangling volumes — есть orphaned state?

## Шаг 1 — стандартная чистка

```bash
cd ansible
ansible-playbook playbooks/10-disk-cleanup.yml --check --diff
# Review что будет удалено (особенно docker prune)
ansible-playbook playbooks/10-disk-cleanup.yml
./verify.sh
```

Это типично освобождает 1-5GB на работающем сервере (apt cache + journal vacuum + docker image prune старше 7 дней).

Если `verify.sh` зелёный после — закончили.

## Шаг 2 — если мало освободилось (<500MB)

Возможные причины:
1. **Application data** в `/opt/<app>/{data,workspace}` — это не наша зона, обращайся к владельцу проекта (см. `ownership-matrix.md`).
2. **Recent docker images** — `--filter until=168h` не их захватил. Проверь:
   ```bash
   ssh deploy@<vps> 'docker images --format "{{.Repository}}:{{.Tag}} {{.CreatedAt}} {{.Size}}" | sort -k2'
   ```
   Если есть огромный образ (>1GB) от tooling/CI который точно не нужен — удали вручную: `docker rmi <id>`.
3. **Dangling volumes** — manual review. Список вывел `disk-report`. Для каждого:
   ```bash
   ssh deploy@<vps> 'docker volume inspect <name>'
   ```
   - Если `Mountpoint` пуст или содержит только tmp — `docker volume rm <name>`.
   - Если содержит state — связаться с владельцем проекта.
4. **Build cache не удалился** — иногда `docker builder prune --filter until=` фильтр странно работает на старых docker. Проверь:
   ```bash
   ssh deploy@<vps> 'docker buildx du'
   ```
   При острой нужде: `docker buildx prune -af` (без фильтра — но это **только** build cache, не runtime).

## Шаг 3 — если >90% и нужно срочно

Не паникуй, ничего не удаляй "наобум". Применяй по порядку:

1. **Журналы вручную:**
   ```bash
   ssh deploy@<vps> 'sudo journalctl --vacuum-size=100M'
   ```
2. **Старые kernel пакеты:**
   ```bash
   ssh deploy@<vps> 'sudo apt-get autoremove --purge -y'
   ```
3. **Большие лог-файлы конкретных сервисов:**
   ```bash
   ssh deploy@<vps> 'sudo find /var/log -type f -size +100M -exec ls -lh {} \;'
   # Для каждого: truncate -s 0 <path> (если знаешь что делаешь)
   ```
4. **Docker — снять running stale контейнеры:**
   ```bash
   ssh deploy@<vps> 'docker ps -a --filter "status=exited" --format "{{.ID}} {{.Names}} {{.Status}}"'
   # Для совсем старых: docker rm <id>
   ```

## Шаг 4 — если >95% и сервисы падают

Критичная ситуация. Запретить автоматическую чистку:
- `10-disk-cleanup.yml` имеет safety check и **остановится** если `disk_used_pct >= disk_crit_pct` (95% по умолчанию).
- Это намеренно — на критическом диске любой `apt-get` может оставить системы в полу-сломанном состоянии.

Действия:
1. Свободить минимум 1-2GB вручную (см. шаг 3).
2. После — нормальный `10-disk-cleanup.yml`.
3. После — `./verify.sh` должен быть OK.

Если по факту места нет даже под `apt clean`:
1. `truncate` крупных логов (но осторожно — потеря данных).
2. `docker stop` non-critical контейнеров вручную для освобождения tmpfs/overlay.
3. Эскалация: апгрейд плана Hetzner до CX33 (8GB/80GB) или добавление volume.

## Шаг 5 — root cause analysis

После того как вылечили — найди причину:
- Почему `/opt/lightrag/data` вырос? — owner: openclaw_firststeps. Может быть pruning issue или KG переиндексировался.
- Почему так много docker images? — owner проекта много раз rebuild без `--rm` или CI без cleanup.
- Почему journal распух? — какой-то сервис спамит ошибками.

Зафиксировать вывод в `reports/post-mortem-YYYY-MM-DD.md` и обсудить с владельцем проекта.

## Превентивно

- `10-disk-cleanup.yml` запускать раз в неделю по cron / `loop`-skill.
- `verify.sh` — раз в час (warn @80% даёт неделю на реакцию).
- При появлении `30-backup.yml` — следить за тем, чтобы локальный restic-кэш на VPS не разрастался (он на VPS не нужен, restic пишет напрямую в repo).
