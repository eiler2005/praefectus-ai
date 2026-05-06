# Port map — vps-prod

Каноническая таблица всех сетевых портов на VPS. Обновлять при добавлении/удалении сервисов.

**Последний аудит:** 2026-05-03  
**Инструмент проверки:** `./modules/port-audit/bin/port-audit`

---

## Публичные порты (0.0.0.0 / ::)

| Порт | Протокол | Сервис | Процесс/контейнер | Владелец | Healthcheck |
|---|---|---|---|---|---|
| 22 | TCP | sshd | system (sshd) | vps_management | `nc -z <host> 22` |
| 80 | TCP | Caddy (HTTP→HTTPS redirect) | system (caddy) | router_configuration | `curl -I http://<host>/` |
| 443 | TCP | Caddy HTTPS | system (caddy) | router_configuration | TLS handshake |
| 443 | TCP | Xray Reality (multiplexed на 443) | xray (host net) | router_configuration | TLS handshake |
| 22000 | TCP | Syncthing sync | system (syncthing) | vps_management | TCP connect |

## Приватные порты (127.0.0.1 — внутренние)

| Порт | Протокол | Сервис | Контейнер | Владелец | Healthcheck |
|---|---|---|---|---|---|
| 3000 | TCP | ghostroute-console | ghostroute-console (host net) | router_configuration | `GET /api/health` |
| 8020 | TCP | lightrag API | lightrag-lightrag-1 | openclaw_firststeps | `GET /health` |
| 8092 | TCP | agentmail-email-bridge | agentmail-email-bridge | openclaw_firststeps | TCP connect |
| 8093 | TCP | signals-bridge | signals-bridge | openclaw_firststeps | TCP connect |
| 8094 | TCP | agentmail-work-email-bridge | agentmail-work-email-bridge | openclaw_firststeps | TCP connect |
| 8095 | TCP | wiki-import | wiki-import | openclaw_firststeps | `GET /health` |
| 8384 | TCP | Syncthing Web UI | system (syncthing) | vps_management | `curl /rest/system/ping` |
| 18789 | TCP | openclaw-gateway (main) | openclaw-openclaw-gateway-1 | openclaw_firststeps | `GET /healthz` |
| 18790 | TCP | openclaw-gateway (bridge) | openclaw-openclaw-gateway-1 | openclaw_firststeps | TCP connect |
| 20128 | TCP | omniroute dashboard | omniroute | openclaw_firststeps | `node healthcheck.mjs` |
| 20129 | TCP | omniroute OpenAI API | omniroute | openclaw_firststeps | TCP connect |

## Внутренние docker-сети (недоступны с хоста)

| Сервис | Сеть | Порт (internal) | Примечание |
|---|---|---|---|
| integration-bus-redis | openclaw_default | 6379 | доступен только внутри сети |
| xray-xhttp | — | внутренние | транспорт Xray, нет публичного bind |

---

## Резервы портов

| Диапазон | Назначение |
|---|---|
| 8100–8199 | openclaw_firststeps — новые сервисы |
| 9100–9199 | мониторинг (node_exporter, будущее) |
| 18000–18999 | openclaw internal API |
| 20000–20999 | AI routing / omniroute |

---

## Небезопасные bindings — чего не должно быть

Следующие порты должны быть **только на 127.0.0.1**, не на 0.0.0.0:

- 3000, 8020–8095, 8384, 18789–18790, 20128–20129
- Если `ss -tlnp` показывает 0.0.0.0 для этих портов → немедленный инцидент

**Исключения (публичные по назначению):** 22, 80, 443, 22000

---

## Как проверить

```bash
# Standalone audit (сравнивает с docs/ports.md)
./modules/port-audit/bin/port-audit

# Только показать текущие listeners
./modules/port-audit/bin/port-audit --live-only

# Сохранить отчёт
./modules/port-audit/bin/port-audit --save
```

```bash
# Вручную на VPS
ssh deploy@<vps> 'ss -tlnp'    # TCP listeners
ssh deploy@<vps> 'ss -ulnp'    # UDP listeners
ssh deploy@<vps> 'docker ps --format "table {{.Names}}\t{{.Ports}}"'
```
