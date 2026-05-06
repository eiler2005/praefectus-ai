# Firewall rules — vps-prod (UFW)

Актуальное состояние UFW firewall. Обновлять при изменении правил.

**Последний аудит:** 2026-05-03  
**Управляется:** `router_configuration` (caddy/xray) + `vps_management` (ssh, syncthing)

---

## Текущие правила

```
# sudo ufw status numbered
Status: active

     To                         Action      From
     --                         ------      ----
[ 1] 22/tcp                     ALLOW IN    Anywhere
[ 2] 80/tcp                     ALLOW IN    Anywhere
[ 3] 443/tcp                    ALLOW IN    Anywhere
[ 4] 22000/tcp                  ALLOW IN    Anywhere
[ 5] 22000/udp                  ALLOW IN    Anywhere
[ 6] 22/tcp (v6)                ALLOW IN    Anywhere (v6)
[ 7] 80/tcp (v6)                ALLOW IN    Anywhere (v6)
[ 8] 443/tcp (v6)               ALLOW IN    Anywhere (v6)
[ 9] 22000/tcp (v6)             ALLOW IN    Anywhere (v6)
[10] 22000/udp (v6)             ALLOW IN    Anywhere (v6)
```

---

## Обоснование правил

| Порт | Протокол | Причина открытия |
|---|---|---|
| 22 | TCP | SSH доступ с Mac → VPS |
| 80 | TCP | HTTP → HTTPS redirect (Caddy) |
| 443 | TCP | HTTPS + Xray Reality (Caddy + stealth VPN) |
| 22000 | TCP+UDP | Syncthing peer sync (Mac ↔ VPS) |

**Всё остальное — DROP** (UFW default deny incoming).

---

## Что НЕ открыто через UFW (намеренно)

| Порт | Сервис | Почему закрыт |
|---|---|---|
| 8384 | Syncthing Web UI | Только 127.0.0.1, доступ через SSH tunnel |
| 9100 | node_exporter (будущее) | Только 127.0.0.1 |
| 18789, 8020, 20128–20129 | openclaw stack | Только 127.0.0.1, внутренние API |

---

## Управление UFW

```bash
# Просмотр правил
ssh deploy@<vps> 'sudo ufw status numbered'

# Проверить что UFW active
ssh deploy@<vps> 'sudo ufw status | head -1'

# ОСТОРОЖНО: ufw disable закрывает SSH если нет rescue!
# Никогда не выполнять без консоли Hetzner в запасе.
```

---

## Аварийный доступ

Если UFW заблокировал SSH:
1. Зайти через Hetzner Cloud Console (web-based terminal)
2. `sudo ufw disable` → получить SSH доступ
3. Восстановить правила с проверкой: `sudo ufw allow 22/tcp && sudo ufw enable`
