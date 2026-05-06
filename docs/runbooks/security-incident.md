# Security incident runbook

Что делать при подозрении на компрометацию VPS.

---

## Признаки компрометации

- Неизвестные процессы в `ps aux` или новые контейнеры в `docker ps`
- Новые открытые порты (проверить: `./modules/port-audit/bin/port-audit`)
- Незнакомые строки в `~/.ssh/authorized_keys`
- Аномальный исходящий трафик (высокий load без причины)
- Ошибки `sudo: 3 incorrect password attempts` в `/var/log/auth.log`
- OOM-kill без роста трафика
- Изменения в `/etc/crontab`, `/etc/cron.d/`, `~/.bashrc`, `~/.profile`

---

## Шаг 1 — Первичная оценка (не теряя SSH)

```bash
# Что сейчас запущено (аномальные процессы?)
ssh deploy@<vps> 'ps aux --sort=-%cpu | head -20'
ssh deploy@<vps> 'ps aux --sort=-%mem | head -20'

# Сетевые соединения (неожиданные исходящие?)
ssh deploy@<vps> 'ss -tnp | grep ESTABLISHED'

# Кто сейчас залогинен
ssh deploy@<vps> 'who; last | head -20'

# Новые файлы за последние 24h (исключая /proc, /sys, /dev)
ssh deploy@<vps> 'find /usr /etc /tmp /var/tmp -newer /etc/passwd -type f 2>/dev/null | head -30'

# Cron (нет ли постороннего?)
ssh deploy@<vps> 'cat /etc/crontab; ls /etc/cron.d/; crontab -l 2>/dev/null'

# authorized_keys
ssh deploy@<vps> 'cat ~/.ssh/authorized_keys'

# OOM events за последние 24h
ssh deploy@<vps> 'dmesg --since "24h ago" | grep -i oom | tail -20'
```

---

## Шаг 2 — Немедленные действия (при подтверждении)

### Изоляция (если есть rescue доступ)
```bash
# НЕ делать без rescue если потеряем SSH!
# Заблокировать всё кроме нашего IP:
ssh deploy@<vps> 'sudo ufw default deny outgoing && sudo ufw allow out to <наш_ip>'
```

### Смена SSH ключей
```bash
# На Mac: сгенерировать новый ключ
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_vps_new -C "vps-recovery-$(date +%Y%m%d)"

# Зайти через Hetzner Console, добавить новый ключ
cat ~/.ssh/id_ed25519_vps_new.pub  # → вставить в authorized_keys через Console

# Удалить скомпрометированный ключ из authorized_keys
```

### Остановить подозрительные процессы
```bash
# Найти PID
ssh deploy@<vps> 'ps aux | grep <suspect>'
# Остановить
ssh deploy@<vps> 'sudo kill -9 <pid>'
```

---

## Шаг 3 — Форензика (после стабилизации)

```bash
# История команд
ssh deploy@<vps> 'cat ~/.bash_history | tail -100'

# Последние изменения в /etc
ssh deploy@<vps> 'find /etc -newer /etc/passwd -type f 2>/dev/null'

# Логи fail2ban (кто пытался подобрать пароль?)
ssh deploy@<vps> 'sudo fail2ban-client status sshd'
ssh deploy@<vps> 'sudo grep "Ban" /var/log/fail2ban.log | tail -30'

# Логи auth
ssh deploy@<vps> 'sudo grep -E "(Failed|Accepted|Invalid)" /var/log/auth.log | tail -50'
```

---

## Шаг 4 — Восстановление

1. **Snapshot** — сделать snapshot в Hetzner Console ДО любых изменений (forensic copy)
2. **Определить вектор** — как попали? Слабый ключ? Уязвимость в приложении?
3. **Закрыть вектор**
4. **Проверить все сервисы** — не скомпрометированы ли конфиги, данные, credentials
5. **Сменить все секреты**: vault.yml, Telegram tokens, API keys
6. **Пересоздать authorized_keys** с чистыми ключами
7. **Провести полный verify**: `./verify.sh`
8. **Задокументировать** в `docs/journal/YYYY-MM.md`

---

## Контакты / escalation

- Hetzner Support: support.hetzner.com (при необходимости блокировки IP)
- Hetzner Console: console.hetzner.cloud (rescue access без SSH)

---

## Превентивные меры (уже применены)

- fail2ban: sshd jail — 3 попытки/600s → бан 24h
- UFW: только 22, 80, 443, 22000
- PasswordAuthentication: должен быть `no` (проверить: `grep PasswordAuthentication /etc/ssh/sshd_config`)
- Только key-based SSH
- unattended-upgrades: security patches автоматически
