# Firewall rules — vps-prod (UFW)

Актуальное состояние UFW firewall. Обновлять при изменении правил.

**Последний аудит:** 2026-05-06  
**Управляется:** `router_configuration` (caddy/xray/console) + `vps_management` (ssh, syncthing)

---

## Текущие правила

```
# sudo ufw status numbered
Status: active

     To                         Action      From
     --                         ------      ----
[ 1] 22/tcp                     ALLOW IN    <denis-home-ip>            # SSH from Denis home
[ 2] 22/tcp                     ALLOW IN    <work-ip>                  # SSH from work
[ 3] 80/tcp                     ALLOW IN    Anywhere                   # HTTP for ACME
[ 4] 443/tcp                    ALLOW IN    Anywhere
[ 5] 22000/tcp                  ALLOW IN    Anywhere                   # Syncthing data TCP
[ 6] 22000/udp                  ALLOW IN    Anywhere                   # Syncthing data QUIC
[ 7] 21027/udp                  ALLOW IN    Anywhere                   # Syncthing discovery
[ 8] 22/tcp                     ALLOW IN    <denis-home-ip-2>          # SSH from Denis (alt)
[ 9] 22/tcp                     ALLOW IN    <trusted-ip-1>             # allow ssh trusted
[10] 22/tcp                     ALLOW IN    <trusted-ip-2>
[11] 53/tcp                     DENY IN     Anywhere
[12] 53/udp                     DENY IN     Anywhere
[13] 22/tcp                     ALLOW IN    <ghostroute-control-ip>    # GhostRoute current control SSH
[14] 15353/tcp                  ALLOW IN    172.22.0.0/16              # GhostRoute Xray bridge to Unbound
[15] 15353/udp                  ALLOW IN    172.22.0.0/16              # GhostRoute Xray bridge to Unbound
[16] 2087/tcp                   ALLOW IN    Anywhere                   # GhostRoute Console HTTPS
[17] 443/tcp                    ALLOW OUT   Anywhere                   (out)
[18] 53                         ALLOW OUT   Anywhere                   (out)
[19] 80/tcp (v6)                ALLOW IN    Anywhere (v6)              # HTTP for ACME
[20] 443/tcp (v6)               ALLOW IN    Anywhere (v6)
[21] 22000/tcp (v6)             ALLOW IN    Anywhere (v6)              # Syncthing data TCP
[22] 22000/udp (v6)             ALLOW IN    Anywhere (v6)              # Syncthing data QUIC
[23] 21027/udp (v6)             ALLOW IN    Anywhere (v6)              # Syncthing discovery
[24] 53/tcp (v6)                DENY IN     Anywhere (v6)
[25] 53/udp (v6)                DENY IN     Anywhere (v6)
[26] 2087/tcp (v6)              ALLOW IN    Anywhere (v6)              # GhostRoute Console HTTPS
[27] 443/tcp                    ALLOW OUT   Anywhere (v6)              (out)
[28] 53 (v6)                    ALLOW OUT   Anywhere (v6)              (out)
```

Реальные IP-адреса хранятся в vault.yml, в docs используются плейсхолдеры.

---

## Обоснование правил

| Порт | Протокол | Причина открытия | Владелец |
|---|---|---|---|
| 22 | TCP | SSH-доступ с разрешённых IP (несколько правил) | vps_management |
| 80 | TCP | HTTP → HTTPS redirect, ACME challenge (Caddy) | router_configuration |
| 443 | TCP | HTTPS + Xray Reality (Caddy + stealth VPN) | router_configuration |
| 2087 | TCP | GhostRoute Console HTTPS (внешний доступ) | router_configuration |
| 21027 | UDP | Syncthing discovery protocol | vps_management |
| 22000 | TCP+UDP | Syncthing peer sync (Mac ↔ VPS) | vps_management |
| 53 | TCP+UDP | **DENY IN** — VPS не должен быть публичным DNS | vps_management |
| 15353 | TCP+UDP | Unbound resolver — только из Xray Docker bridge (172.22.0.0/16). **Опционально** с 2026-05-06: основной путь managed DNS перенесён на dnscrypt-proxy на роутере | router_configuration |
| 443, 53 | OUT | Исходящие HTTPS и DNS — нужны для apt, restic B2, ACME | vps_management |

**Всё остальное — DROP** (UFW default deny incoming).

---

> **Изменение 2026-05-06 (router_configuration f773f17):**  
> Правила 14–15 (порт 15353, Unbound) теперь **опциональны**. Основной managed DNS  
> перемещён на dnscrypt-proxy→sing-box→Reality на роутере. VPS Unbound включается  
> только для приватной диагностики. Правила UFW остаются на месте.

---

## Что НЕ открыто через UFW (намеренно)

| Порт | Сервис | Почему закрыт |
|---|---|---|
| 8384 | Syncthing Web UI | Только 127.0.0.1, доступ через SSH tunnel |
| 9100 | node_exporter (будущее) | Только 127.0.0.1 |
| 18789, 8020, 20128–20129 | openclaw stack | Только 127.0.0.1, внутренние API |
| 3000 | ghostroute-console internal | Только 127.0.0.1 (внешний — 2087 через Caddy) |

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

### SSH allowlist and VPN changes

SSH is allowlisted by source IP. If the operator switches to a third-party VPN,
mobile hotspot, office network, or any other route with a new egress IP, direct
SSH may fail even when the VPS is healthy. Before depending on that route:

1. Add the new source IP to the VPS SSH allowlist and any provider firewall
   allowlist.
2. Verify direct SSH from that network: `./ansible/scripts/ssh-vps.sh 'echo OK'`.
3. Keep the router bastion or Hetzner Console available before changing rules.

Never replace the SSH allowlist with `Anywhere` as a convenience shortcut.

---

## Аварийный доступ

Если UFW заблокировал SSH:
1. Зайти через Hetzner Cloud Console (web-based terminal)
2. `sudo ufw disable` → получить SSH доступ
3. Восстановить правила с проверкой: `sudo ufw allow 22/tcp && sudo ufw enable`
