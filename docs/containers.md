# Container Registry — vps-prod

Полная карта всех Docker-контейнеров на VPS. Обновлять при добавлении/удалении сервисов.

**Сервер:** Hetzner CX23 · 4GB RAM · 2 vCPU · Ubuntu 24.04  
**Последний аудит:** 2026-05-03 (Этапы 2+3 завершены — mem_limit на всех сервисах)  
**Всего контейнеров:** 13

---

## Критичность и лимиты памяти

| Контейнер | Критичность | mem_limit | Заметка |
|---|---|---|---|
| deploy-bridge-1 | КРИТИЧНЫЙ | 256m ✅ | Задан в docker-compose.prod.yml |
| xray | КРИТИЧНЫЙ | нет | Зона router_configuration |
| xray-xhttp | КРИТИЧНЫЙ | нет | Зона router_configuration |
| openclaw-openclaw-gateway-1 | КРИТИЧНЫЙ | 1024m ✅ | 70-docker-limits-critical.yml |
| lightrag-lightrag-1 | ВЫСОКАЯ | 192m ✅ | 70-docker-limits-critical.yml (факт. ~117MB) |
| omniroute | ВЫСОКАЯ | 512m ✅ | 70-docker-limits-critical.yml |
| integration-bus-redis | ВЫСОКАЯ | 256m ✅ | 70-docker-limits-critical.yml |
| signals-bridge | СРЕДНЯЯ | 384m ✅ | 60-docker-limits.yml |
| telethon-digest-cron-bridge | СРЕДНЯЯ | 256m ✅ | 60-docker-limits.yml |
| ghostroute-console | СРЕДНЯЯ | 450m ✅ | router_configuration, скоординировано с vps_management |
| wiki-import | НИЗКАЯ | 256m ✅ | 60-docker-limits.yml |
| agentmail-email-bridge | НИЗКАЯ | 256m ✅ | 60-docker-limits.yml |
| agentmail-work-email-bridge | НИЗКАЯ | 256m ✅ | 60-docker-limits.yml |

---

## Детали контейнеров

### deploy-bridge-1
| Параметр | Значение |
|---|---|
| Владелец | `maxtg_bridge` |
| Образ | `maxtg-bridge:prod` (build from Dockerfile) |
| Порты | нет (outbound only) |
| Volumes | `../data:/app/data`, `config.yaml`, `config.local.yaml` |
| Healthcheck | нет |
| mem_limit | **256m** (в docker-compose.prod.yml) |
| Роль | Telegram бот, основной продукт пользователя |
| Данные | `/opt/maxtg-bridge/data/` — sqlite + sessions (критично для бэкапа) |
| Deploy | `maxtg_bridge/infra/ansible/` |

---

### xray
| Параметр | Значение |
|---|---|
| Владелец | `router_configuration` |
| Образ | xray (stealth proxy) |
| Порты | :443 (HTTPS + Reality), внутренние |
| Volumes | `/etc/xray/` конфиги |
| mem_limit | нет |
| Роль | Xray Reality — VPN/stealth транспорт |
| Deploy | `router_configuration` ansible |

---

### xray-xhttp
| Параметр | Значение |
|---|---|
| Владелец | `router_configuration` |
| Образ | xray (xHTTP transport) |
| Порты | внутренние |
| mem_limit | нет |
| Роль | xHTTP транспорт для Xray |
| Deploy | `router_configuration` ansible |

---

### openclaw-openclaw-gateway-1
| Параметр | Значение |
|---|---|
| Владелец | `openclaw_firststeps` |
| Образ | `${OPENCLAW_IMAGE}` |
| Порты | `127.0.0.1:18789` (main), `127.0.0.1:18790` (bridge) |
| Volumes | config dir, workspace dir, `/opt/obsidian-vault` |
| Healthcheck | `GET /healthz` на 127.0.0.1:18789 (10s interval) |
| mem_limit | нет (Этап 3 → ~768m) |
| Роль | Основной AI gateway, точка входа для всех AI-запросов |
| Deploy | `openclaw_firststeps/artifacts/openclaw/` |

---

### lightrag-lightrag-1
| Параметр | Значение |
|---|---|
| Владелец | `openclaw_firststeps` |
| Образ | lightrag (KG + vector store) |
| Порты | `127.0.0.1:8020` (HTTP /health) |
| Volumes | `/opt/lightrag/data/` (1.7GB на диске — KG + embeddings) |
| Healthcheck | `GET /health` на 127.0.0.1:8020 |
| mem_limit | нет (**OOM-риск!** Этап 3 → ~1-1.5GB после замера) |
| Роль | Knowledge Graph + vector search, используется gateway |
| Данные | `/opt/lightrag/data/` — восстановимо, но переиндексация долгая |
| Deploy | `openclaw_firststeps` deploy скрипты |

---

### omniroute
| Параметр | Значение |
|---|---|
| Владелец | `openclaw_firststeps` |
| Образ | build from `./omniroute-src` |
| Порты | `127.0.0.1:20128` (dashboard), `127.0.0.1:20129` (OpenAI-compatible API) |
| Volumes | `omniroute-data:/app/data` |
| Healthcheck | `node healthcheck.mjs` (30s interval, 60s start_period) |
| mem_limit | нет (Этап 3 → ~512m) |
| Роль | AI routing — маршрутизация запросов между моделями |
| Deploy | `openclaw_firststeps/artifacts/omniroute/docker-compose.override.yml` |

---

### integration-bus-redis
| Параметр | Значение |
|---|---|
| Владелец | `openclaw_firststeps` |
| Образ | `redis:7-alpine` |
| Порты | внутренние (сеть `openclaw_default`) |
| Volumes | `redis-data:/data` (persistence: save 60s/1 key) |
| Healthcheck | нет |
| mem_limit | нет (Этап 3 → ~256m) |
| Роль | Шина данных для signals-bridge, agentmail, telethon-digest |
| Deploy | `openclaw_firststeps/artifacts/integration-bus/docker-compose.yml` |

---

### signals-bridge
| Параметр | Значение |
|---|---|
| Владелец | `openclaw_firststeps` |
| Образ | build from `.` |
| Порты | `127.0.0.1:8093:8093` |
| Volumes | sessions vol, state vol, config.json, rules/, `/opt/obsidian-vault` |
| mem_limit | **384m** ✅ (60-docker-limits.yml, applied 2026-05-03) |
| Роль | Обработка сигналов, интеграция с Redis bus |
| Deploy | `openclaw_firststeps/artifacts/signals-bridge/docker-compose.yml` |

---

### telethon-digest-cron-bridge
| Параметр | Значение |
|---|---|
| Владелец | `openclaw_firststeps` |
| Образ | build from `.` |
| Порты | нет |
| Volumes | sessions vol, state vol, config.json, obsidian/Telegram Digest |
| Healthcheck | нет |
| mem_limit | **256m** ✅ (60-docker-limits.yml, applied 2026-05-03) |
| Роль | Cron-мост для Telegram Digest, scheduled tasks |
| Deploy | `openclaw_firststeps/artifacts/telethon-digest/docker-compose.yml` |
| Замечание | docker-compose.yml содержит ДВА сервиса: `telethon-digest` и `telethon-digest-cron-bridge`. При `docker compose up -d` без аргументов запустятся оба. Нужно: `docker compose up -d telethon-digest-cron-bridge` |

---

### ghostroute-console
| Параметр | Значение |
|---|---|
| Владелец | `router_configuration` |
| Образ | `ghostroute-console:latest` (build from `../app`) |
| Порты | `127.0.0.1:3000` (network_mode: host) |
| Volumes | `/opt/ghostroute-console/data`, repo (ro), ssh (ro) |
| Healthcheck | `GET /api/health` на 127.0.0.1:3000 (30s interval) |
| mem_limit | нет (зона router_configuration, не трогаем без координации) |
| Роль | Admin/monitoring console для ghostroute |
| Данные | `/opt/ghostroute-console/data/` (3.8GB — самая большая директория!) |
| Deploy | `router_configuration/modules/ghostroute-console/` |

---

### wiki-import
| Параметр | Значение |
|---|---|
| Владелец | `openclaw_firststeps` |
| Образ | build from `.` |
| Порты | `127.0.0.1:8095:8095` |
| Volumes | `/opt/obsidian-vault` (rw), `/opt` (ro), wiki-import-state vol |
| Healthcheck | `GET /health` на 127.0.0.1:8095 (30s interval) |
| mem_limit | **256m** ✅ (60-docker-limits.yml, applied 2026-05-03) |
| Роль | Импорт wiki-данных из obsidian vault |
| Deploy | `openclaw_firststeps/artifacts/wiki-import/docker-compose.yml` |

---

### agentmail-email-bridge
| Параметр | Значение |
|---|---|
| Владелец | `openclaw_firststeps` |
| Образ | build from `.` |
| Порты | `127.0.0.1:8092:8092` |
| Volumes | state vol, config.json, `/var/run/docker.sock` (!) |
| Healthcheck | нет |
| mem_limit | **256m** ✅ (60-docker-limits.yml, applied 2026-05-03) |
| Роль | Email bridge, интеграция с Redis bus |
| Замечание | Монтирует docker.sock — имеет доступ к Docker API |
| Deploy | `openclaw_firststeps/artifacts/agentmail-email/docker-compose.yml` |

---

### agentmail-work-email-bridge
| Параметр | Значение |
|---|---|
| Владелец | `openclaw_firststeps` |
| Образ | build from `.` (аналог agentmail-email) |
| Порты | внутренние |
| Volumes | аналог agentmail-email |
| Healthcheck | нет |
| mem_limit | **256m** ✅ (60-docker-limits.yml, applied 2026-05-03) |
| Роль | Work email bridge |
| Deploy | `openclaw_firststeps/artifacts/agentmail-work-email/` |
| Замечание | Сервис в docker-compose.yml называется `agentmail-email-bridge` (не work-email). container_name задаётся через `${EMAIL_CONTAINER_NAME}` из env_file (не из shell), поэтому при перезапуске нужны явные env vars: `sudo env EMAIL_CONTAINER_NAME=agentmail-work-email-bridge EMAIL_STATE_VOLUME=agentmail-work-email-state EMAIL_BRIDGE_PORT=8094 docker compose -f docker-compose.yml -f docker-compose.override.local.yml up -d` |

---

## Бюджет памяти (4GB RAM)

```
OS + system daemons:           ~500 MB
deploy-bridge-1:                256 MB  ← лимит 256m ✅ (в docker-compose.prod.yml)
xray + xray-xhttp:              ~51 MB  (measured, нет лимита — Этап 3)
openclaw-gateway:              ~599 MB  (measured, нет лимита — Этап 3, крупнейший!)
lightrag:                      ~136 MB  (measured, нет лимита — Этап 3)
omniroute:                     ~182 MB  (measured, нет лимита — Этап 3)
redis:                           ~6 MB  (measured, нет лимита — Этап 3)
signals-bridge:                 ~54 MB  (measured, лимит 384m ✅)
telethon-digest-cron-bridge:    ~32 MB  (measured, лимит 256m ✅)
ghostroute-console:            ~132 MB  (measured, нет лимита — зона router_configuration)
wiki-import:                     ~6 MB  (measured, лимит 256m ✅)
agentmail-email-bridge:         ~23 MB  (measured, лимит 256m ✅)
agentmail-work-email-bridge:    ~34 MB  (measured, лимит 256m ✅)
────────────────────────────────────────
Итого measured:               ~2.0 GB
Своп (после Этапа 2):         ~1.3/2GB → openclaw-gateway главный потребитель
Этап 2 завершён 2026-05-03: 5 лимитов применены
```

**Для точного замера:** `docker stats --no-stream`

---

## Команды для проверки

```bash
# Текущее потребление RAM
docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}"

# Проверить что лимит применился после docker compose up -d
docker inspect <name> | grep -i memory

# Все лимиты разом
docker inspect $(docker ps -q) | jq '.[] | {Name: .Name, MemLimit: .HostConfig.Memory}'
```
