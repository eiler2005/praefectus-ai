# Architecture

## Принцип: host vs app ownership

`vps_management` владеет **хостом**. Дочерние проекты владеют **своими приложениями**.

Это разделение позволяет:
- Постепенно мигрировать (не нужно переписывать всё разом).
- Чётко отвечать на вопрос "кто это деплоил" → читай `docs/ownership-matrix.md`.
- Безопасно автоматизировать host maintenance (диск, мониторинг) без риска снести application data.

## Слои

```
┌─────────────────────────────────────────────────────────────┐
│  L4: Application data                                        │
│  /opt/<app>/{data,workspace,config}                          │
│  Владелец: проект-владелец app. vps_management только бэкап. │
├─────────────────────────────────────────────────────────────┤
│  L3: Application runtime                                     │
│  /opt/<app>/docker-compose.yml + образа                      │
│  Владелец: проект-владелец app. vps_management не трогает.   │
│  Override-файлы (override.local.yml для лимитов) — наша зона.│
├─────────────────────────────────────────────────────────────┤
│  L2: Container runtime + system services                     │
│  Docker daemon, sshd, ufw, fail2ban, systemd                 │
│  Владелец: vps_management.                                   │
├─────────────────────────────────────────────────────────────┤
│  L1: Host OS                                                 │
│  Ubuntu 24.04 пакеты, /var/log, /var/lib, sysctl             │
│  Владелец: vps_management.                                   │
├─────────────────────────────────────────────────────────────┤
│  L0: Hardware / провайдер                                    │
│  Hetzner Cloud (CX23, IP allocation, snapshots)              │
│  Владелец: оператор через Hetzner Console.                   │
└─────────────────────────────────────────────────────────────┘
```

## Что vps_management делает

- **Bootstrap (планируется)** — `00-bootstrap.yml` приводит свежую CX23 в готовое состояние.
- **Maintenance** — `10-disk-cleanup.yml` (этот этап), `20-monitoring.yml` (планируется), `30-backup.yml` (планируется), `40-security.yml` (планируется).
- **Audit/Verify** — `99-verify.yml` read-only health gate.
- **Secrets** — единый Ansible Vault для всех VPS-access реквизитов.

## Что vps_management НЕ делает

- Не деплоит приложения. Это делают сами проекты (`maxtg_bridge/infra/ansible/`, `openclaw_firststeps/scripts/deploy-*.sh`, `router_configuration/deploy.sh`).
- Не редактирует основные `docker-compose.yml` приложений.
- Не управляет application secrets (TG_BOT_TOKEN, OPENAI_API_KEY и т.п.) — они в `.env.secrets` приложения.
- Не отвечает за application-level health (внутренние ошибки бизнес-логики). Только за то, что контейнер running и порт отвечает.

## Связь с другими проектами

| Проект | Связь | Кто инициирует |
|---|---|---|
| `router_configuration` | Делит `/etc/{caddy,xray,unbound}` | router_configuration деплоит, vps_management только верифицирует |
| `maxtg_bridge` | Делит `/opt/maxtg-bridge` | maxtg_bridge деплоит, vps_management бэкапит data + чистит docker images |
| `openclaw_firststeps` | Делит `/opt/openclaw`, `/opt/lightrag`, `/opt/{telethon-digest,...}` | openclaw деплоит, vps_management мониторит память + бэкапит workspace |

## Vault как single source of truth

Все секреты доступа (IP, SSH, port, ключи, токены алёртов) — в `ansible/secrets/vault.yml`. Дочерние проекты постепенно переводятся на чтение значений отсюда (через `ansible-vault view` или плейсхолдер в их inventory).

Сейчас (этап 1): vault содержит копию реквизитов; чужие проекты работают со своими копиями. Миграция — отдельный roadmap-item.

## Workflow для изменений

1. Прочитать AGENTS.md.
2. Прочитать relevant runbook в `docs/runbooks/`.
3. Если зона другого проекта — прочитать `docs/ownership-matrix.md`, скоординироваться.
4. Изменить роль/плейбук, синтаксис проверить (`--syntax-check`).
5. `--check --diff` против prod — review diff.
6. Apply.
7. `verify.sh` — должен быть зелёным.
8. Коммит (только с явного разрешения).
