# Security

## Protected Assets

| Ресурс | Где | Compromise impact |
|---|---|---|
| `~/.vault_pass.txt` | Mac home, mode 0600 | Полный доступ к VPS — IP, SSH, все downstream secrets |
| `~/.ssh/id_rsa` | Mac home | SSH доступ к VPS как `deploy` |
| `ansible/secrets/vault.yml` | Этот репо, encrypted | При наличии vault password — то же что vault_pass |
| Restic password (когда появится) | В vault | Доступ ко всем бэкапам |
| B2 application key (когда появится) | В vault | Удаление/перезапись бэкапов |
| Telegram bot token (когда появится) | В vault | Возможность слать фейковые алёрты от имени бота |
| Hetzner API token (если будет) | В vault | Управление VPS на уровне провайдера (resize, delete) |

## Threat Model

**Single point of failure:** один VPS, один Mac. Потеря Mac без бэкапа vault password = потеря доступа к VPS. Восстановление возможно только через Hetzner Cloud Console (rescue mode + reset root password).

**Высокая ценность:** на VPS живут данные нескольких проектов:
- maxtg_bridge: чат-историю (приватные переписки)
- openclaw_firststeps: workspace с personal knowledge
- obsidian-vault: curated knowledge (двусторонняя синхронизация — конфликты могут уничтожить данные)

**Низкая площадь атаки:** UFW, sshd с keys-only, Reality stealth для VPN — основные сетевые сервисы скрыты от поверхностного скана.

**Главные риски:**
1. Утечка vault password (например, через коммит `~/.vault_pass.txt` в любом репо).
2. Утечка реального IP в публичном коммите (даёт цель для атаки).
3. Disk full — приложения падают, OOM-killer убивает критичные процессы.
4. OOM на 4GB — uncapped контейнеры (LightRAG/OmniRoute) могут съесть всю память.
5. Двусторонний Syncthing — конфликт-файлы накапливаются, разрешаются неправильно, теряются данные.
6. Компрометация deploy user — root через sudo? Нужен audit прав.

## Recovery Boundaries

### Потеря SSH доступа
- Hetzner Cloud Console → Rescue mode → перезагрузка → mount root → восстановление `~deploy/.ssh/authorized_keys`.
- Альтернатива: добавить второй ключ в `vault_deploy_user_pubkey` заранее.

### Потеря vault password
- Если есть бэкап в 1Password → восстановить.
- Если нет → vault.yml не расшифровать. Восстанавливать значения вручную:
  - SSH host/user — пересобрать из истории Hetzner Console.
  - Telegram tokens (когда появятся) — пересоздать через @BotFather.
  - Restic password (когда появится) — потеря бэкапов (см. ниже).

### Потеря restic password (когда появится backup)
- Бэкапы становятся **нечитаемыми** навсегда. Restic не имеет recovery механизма.
- **Поэтому:** restic password обязательно дублировать в 1Password отдельно от vault password.

### Компрометация deploy user
1. Сразу: `ssh deploy@<vps>` → удалить чужой ключ из `~/.ssh/authorized_keys`.
2. Сменить SSH ключ на новый.
3. Прогнать `40-security.yml --tags sshd,fail2ban` (когда появится).
4. Проверить `last`, `journalctl _COMM=sshd | grep Accepted` — кто и когда заходил.
5. Проверить cron, systemd timer, crontab `-u deploy -l` — нет ли persistence.
6. Если был root через sudo — переустановка системы (нельзя гарантировать чистоту).

### Компрометация конкретного контейнера приложения
- vps_management не отвечает за application security — только эскалация владельцу проекта (`docs/ownership-matrix.md`).
- Host-уровень: проверить `docker inspect <container>` на mounts, проверить нет ли `--privileged` или `--cap-add SYS_ADMIN`.

### Disaster recovery (полная переустановка VPS)
1. В Hetzner Cloud Console: создать новый CX23 с тем же IP (или принять новый IP — обновить vault).
2. На Mac: `ansible-playbook playbooks/00-bootstrap.yml` (когда появится).
3. Восстановить из бэкапов (когда появится `30-backup.yml`): `restic restore latest --target /`.
4. Перезапустить владельцев приложений — они сами `git pull` + `docker compose up -d` своих стэков.
5. Smoke test: `./verify.sh`.

Тренировка (DR drill) — раз в квартал, см. roadmap.

## Reporting

Это приватный личный репозиторий. Если ты не владелец и нашёл проблему — связаться с владельцем напрямую.

## Pre-commit checklist

Перед каждым `git commit`:

```bash
./modules/secrets-management/bin/secret-scan   # exit 0
git status                                     # никаких .vault_pass.txt, secrets/, *.yml не из vault.yml.example
git diff --cached                              # глазами на IP/токены
```
