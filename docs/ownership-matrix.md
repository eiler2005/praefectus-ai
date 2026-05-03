# Ownership matrix

Кто чем владеет на VPS. Перед любым mutating действием в чужой зоне — координация с владельцем.

## Системные пути

| Путь | Владелец | Что | Может ли vps_management менять |
|---|---|---|---|
| `/etc/ssh/` | vps_management | sshd_config + host keys | Да (через role с validate) |
| `/etc/ufw/` | vps_management | firewall rules | Да |
| `/etc/fail2ban/` | vps_management | jails | Да |
| `/etc/systemd/system/` | vps_management | host-level units (мониторинг, бэкап) | Да для своих unit'ов |
| `/etc/logrotate.d/vps-management` | vps_management | logrotate для caddy/nginx | Да |
| `/etc/caddy/` | router_configuration | host Caddy L4 конфиг | **Нет** (только координация) |
| `/etc/xray/` | router_configuration | Xray Reality конфиг | **Нет** |
| `/etc/unbound/` | router_configuration | DNS resolver | **Нет** |
| `/var/log/` | vps_management | system + service logs | Да (vacuum, rotate) |
| `/var/lib/docker/` | vps_management (host-side) | docker storage | Да (prune с фильтрами!) |
| `/var/cache/apt/` | vps_management | apt cache | Да (clean) |
| `/home/deploy/.ssh/authorized_keys` | vps_management | SSH ключи доступа | Да |
| `/home/deploy/.config/syncthing/` | vps_management | syncthing config | Да |

## Application пути в `/opt/`

| Путь | Владелец-проект | Что внутри | Деплоится через | vps_management override |
|---|---|---|---|---|
| `/opt/maxtg-bridge/` | [maxtg_bridge](../../maxtg_bridge/) | TG↔MAX bridge, sqlite, sessions | `infra/ansible/` оттуда | `docker-compose.override.local.yml` для mem_limit |
| `/opt/openclaw/` | [openclaw_firststeps](../../openclaw_firststeps/) | gateway, workspace (md), config | `scripts/deploy-openclaw.sh` | mem_limit |
| `/opt/lightrag/` | [openclaw_firststeps](../../openclaw_firststeps/) | KG + vector store | `scripts/deploy-lightrag.sh` | mem_limit (важно: prone to OOM) |
| `/opt/omniroute/` | [openclaw_firststeps](../../openclaw_firststeps/) | router service на :20128 | `scripts/deploy-omniroute.sh` | mem_limit |
| `/opt/telethon-digest/` | [openclaw_firststeps](../../openclaw_firststeps/) | telethon cron bridge | `scripts/deploy-telethon-digest.sh` | mem_limit |
| `/opt/signals-bridge/` | [openclaw_firststeps](../../openclaw_firststeps/) | signals bridge :8093 | `scripts/deploy-signals-bridge.sh` | mem_limit |
| `/opt/wiki-import/` | [openclaw_firststeps](../../openclaw_firststeps/) | wiki import :8095 | `scripts/deploy-wiki-import.sh` | mem_limit |
| `/opt/agentmail-email/`, `/opt/agentmail-work-email/` | [openclaw_firststeps](../../openclaw_firststeps/) | mail bots | свои deploy скрипты | mem_limit |
| `/opt/obsidian-vault/` | vps_management (Syncthing host) | синхронизируется с Mac (двусторонне!) | Syncthing | Да |

## Что значит "владелец"

- **Деплой и конфигурация:** все изменения в этой директории делает владелец через свой репо.
- **Application secrets:** `.env.secrets`, `config.local.yaml` и т.п. — зона владельца.
- **Образа docker:** какие версии, какие теги — зона владельца.
- **Healthcheck endpoints:** какие пути отвечают, что они возвращают — владелец.

## Что значит "vps_management override"

`vps_management` может (и должен) накладывать host-policy через `docker-compose.override.local.yml` рядом с основным compose-файлом. Этот файл:
- Создаётся ансиблом (`60-docker-limits.yml`, планируется).
- Не управляется владельцем приложения.
- Содержит **только** host-level constraints: `mem_limit`, `cpus`, `restart`, `logging.driver`.
- Не меняет сервисы, порты, env, volumes.
- Подхватывается автоматически: `docker compose up` читает `docker-compose.yml + docker-compose.override.yml + docker-compose.override.local.yml`.

Пример:
```yaml
# /opt/openclaw/docker-compose.override.local.yml — managed by vps_management
services:
  openclaw-gateway:
    mem_limit: 512m
    cpus: 0.5
    restart: unless-stopped
    logging:
      driver: json-file
      options: { max-size: 10m, max-file: "3" }
```

## Эскалация при инциденте

1. **vps_management алерт показывает container down в чужой зоне** → vps_management фиксирует факт + uptime + last logs в Telegram, **не** перезапускает.
2. Уведомление владельцу (через Telegram канал или вручную).
3. Владелец приходит в свой репо, разбирается, перезапускает.
4. После recovery — `./verify.sh` со стороны vps_management должен показать ok.

Исключение: если контейнер падает циклически и сжирает диск логами — vps_management имеет право остановить (`docker stop <container>`) с уведомлением, чтобы не упал host. Никогда не делать `docker rm` или удалять данные.
