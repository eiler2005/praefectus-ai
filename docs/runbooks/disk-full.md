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
- `sudo du -xhd1 / /var /opt /home /root` — реальные размеры, включая protected dirs.
- `/var/lib/docker` и `/var/lib/containerd` — много images/build cache?
- `/opt/lightrag/data` — KG распух?
- `/opt/ghostroute-console/data/backups` — app-owned DB backups; только owner review.
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

Если `verify.sh` зелёный и диск <80% после — закончили.
Если `verify.sh` зелёный, но диск всё ещё ≥80% — это уже не emergency, но нужен owner review по application data.

## Шаг 2 — если мало освободилось (<500MB)

Возможные причины:
1. **Application data** в `/opt/<app>/{data,workspace}` — это не наша зона, обращайся к владельцу проекта (см. `ownership-matrix.md`).
2. **Recent docker images** — `--filter until=168h` не их захватил. Проверь активные image ID и свежие rollback tags:
   ```bash
   ssh deploy@<vps> 'docker ps -q | xargs -r docker inspect --format "{{.Name}} {{.Config.Image}} {{.Image}}"'
   ssh deploy@<vps> 'docker images --format "{{.ID}} {{.CreatedAt}} {{.Size}} {{.Repository}}:{{.Tag}}" | sort -k2r'
   ```
   Если есть fresh rollback images, которых не забрал age-filter:
   - Не удаляй image ID, который используется running container.
   - Для `ghostroute-console` оставь активный image ID, `latest`, и минимум один самый свежий unused rollback.
   - Остальные unused rollback/git-tag images можно удалять через `docker rmi <tag-or-id>`.
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

## App-owned cleanup candidates

Эти пути не принадлежат `vps_management`. Удалять только после явного owner/operator approval, но полезно знать что безопасно считать reclaim-кандидатом.

### `router_configuration` / `ghostroute-console`

Источник: `router_configuration/modules/ghostroute-console/`.

Можно удалять после approval:
- `/opt/ghostroute-console/data/backups/ghostroute-*.db` — daily SQLite safety backups. Код создаёт их из live DB и сам должен ограничивать retention через `GHOSTROUTE_BACKUP_RETENTION_DAYS=2` и `GHOSTROUTE_DB_BACKUP_MAX_FILES=2`.
- Старые неактивные Docker rollback/git-tag images `ghostroute-console:*`, если image ID не используется running container. Оставь active image, `latest`, и минимум один самый свежий rollback.

Не удалять:
- `/opt/ghostroute-console/data/ghostroute.db` — live SQLite DB.
- `/opt/ghostroute-console/data/snapshots/` без owner review — это runtime evidence; сначала проверь retention/collector.
- `/opt/ghostroute-console/{auth,ssh,router-ssh,repo}` — runtime/deploy assets.

Проверки перед удалением backups:
```bash
ssh deploy@<vps> 'df -h /'
ssh deploy@<vps> 'sudo ls -lh /opt/ghostroute-console/data/backups'
ssh deploy@<vps> 'docker ps --format "{{.Names}} {{.Status}}" | grep ghostroute-console'
```

Удаление approved DB backups:
```bash
ssh deploy@<vps> 'sudo sh -c "rm -vf /opt/ghostroute-console/data/backups/ghostroute-*.db"'
./verify.sh
```

Если backups снова быстро растут, это bug/drift в `router_configuration`: проверить retention env в `/opt/ghostroute-console` compose/deploy и последний `retention_runs` в DB.

### `openclaw_firststeps` / LightRAG and OpenClaw

Источник: `openclaw_firststeps/scripts/setup-llm-wiki.sh` и operational docs.

Можно удалять после approval:
- `/opt/lightrag/backups/llm-wiki-*` — setup/import rollback snapshots.
- `/opt/lightrag/data-backups/*pre-knowledgebackfill-reset*` — one-off pre-reset snapshots.
- `/opt/openclaw-backup-*` — old gateway upgrade rollback dirs, если соответствующий upgrade давно принят.

Не удалять:
- `/opt/lightrag/data/rag_storage/` — live LightRAG graph/vector store.
- `/opt/lightrag/data/inputs/` — source/input queue unless owner confirms.
- `/opt/openclaw/config/memory/main.sqlite` — live OpenClaw memory/state DB.
- `/opt/openclaw/workspace/` — durable workspace.

Проверка кандидатов:
```bash
ssh deploy@<vps> 'sudo du -xhd2 /opt/lightrag /opt/openclaw 2>/dev/null | sort -hr | head -60'
ssh deploy@<vps> 'sudo find /opt/lightrag /opt/openclaw -xdev \( -path "*/backups/*" -o -path "*/data-backups/*" -o -name "*backup*" \) -printf "%s %TY-%Tm-%Td %p\n" 2>/dev/null | sort -nr | head -60'
```

Удаление approved LightRAG/OpenClaw snapshots:
```bash
ssh deploy@<vps> 'sudo rm -rfv /opt/lightrag/backups/llm-wiki-* /opt/lightrag/data-backups/*pre-knowledgebackfill-reset* /opt/openclaw-backup-*'
./verify.sh
```

## Шаг 3 — если >90% и нужно срочно

Не паникуй, ничего не удаляй "наобум". Применяй по порядку:

1. **Снимок состояния:**
   ```bash
   ssh deploy@<vps> 'df -h /; df -ih /; sudo du -xhd1 / /var /opt /home /root 2>/dev/null | sort -hr | head -50'
   ```
2. **Журналы вручную:**
   ```bash
   ssh deploy@<vps> 'sudo journalctl --vacuum-size=100M'
   ```
3. **Старые kernel пакеты:**
   ```bash
   ssh deploy@<vps> 'sudo apt-get autoremove --purge -y'
   ```
4. **Большие лог-файлы конкретных сервисов:**
   ```bash
   ssh deploy@<vps> 'sudo find /var/log -type f -size +100M -exec ls -lh {} \;'
   # Для каждого: truncate -s 0 <path> (если знаешь что делаешь)
   ```
5. **Docker — безопасный host-side prune:**
   ```bash
   ssh deploy@<vps> 'docker ps -a --filter "status=exited" --format "{{.ID}} {{.Names}} {{.Status}}"'
   ssh deploy@<vps> 'docker container prune -f --filter "until=72h"'
   ssh deploy@<vps> 'docker image prune -af --filter "until=168h"'
   ssh deploy@<vps> 'docker builder prune -af --filter "until=168h"'
   ```
   Volumes не prune автоматически.

После ручного emergency-pass обязательно вернись к стандартной процедуре:

```bash
cd ansible
ansible-playbook playbooks/10-disk-cleanup.yml --check --diff
ansible-playbook playbooks/10-disk-cleanup.yml
./verify.sh
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
- Почему `/opt/ghostroute-console/data/backups` вырос? — owner: router_configuration. vps_management только фиксирует размер и reclaim potential.
- Почему так много docker images? — owner проекта много раз rebuild без `--rm` или CI без cleanup.
- Почему journal распух? — какой-то сервис спамит ошибками.

Зафиксировать вывод в `reports/post-mortem-YYYY-MM-DD.md` и обсудить с владельцем проекта.

## Превентивно

- Canonical weekly cleanup timer: `vps-cleanup.timer`, управляется `ansible/playbooks/11-periodic-cleanup-setup.yml`.
- Legacy `vps-weekly-cleanup.timer` должен быть disabled/removed; не включай два cleanup timer одновременно.
- `10-disk-cleanup.yml` запускать вручную при WARN/CRIT после `--check --diff`.
- `verify.sh` — раз в час (warn @80% даёт неделю на реакцию).
- При появлении `30-backup.yml` — следить за тем, чтобы локальный restic-кэш на VPS не разрастался (он на VPS не нужен, restic пишет напрямую в repo).
