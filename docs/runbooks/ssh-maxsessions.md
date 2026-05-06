# Runbook: SSH MaxSessions limit

## Симптом

SSH порт открыт (nc -z <vps_ip> 22 → success), пинг работает, но:
```
Connection timed out during banner exchange
```

## Причина

В `/etc/ssh/sshd_config.d/99-maxtg-hardening.conf` задано `MaxSessions 2`.  
При множестве параллельных/незакрытых SSH-попыток (Ansible, прямой SSH, фоновые команды)
очередь `MaxStartups` заполняется и sshd перестаёт принимать новые соединения.

## Немедленный обход

Дождаться освобождения слотов (старые сессии закрываются через 30-60 сек):
```bash
until ssh -o ControlMaster=no -o ConnectTimeout=10 deploy@<vps_ip> 'echo ok' 2>/dev/null; do
  sleep 15
done
```

## Постоянное исправление

Увеличить `MaxSessions` с 2 до 6 (достаточно для Ansible + ручной SSH + мониторинг):

```bash
# Проверить текущее значение
ssh deploy@<vps> 'sudo grep -r MaxSessions /etc/ssh/'

# Изменить
ssh deploy@<vps> 'sudo sed -i "s/MaxSessions 2/MaxSessions 6/" /etc/ssh/sshd_config.d/99-maxtg-hardening.conf && sudo sshd -t && sudo systemctl reload sshd'
```

Или через Ansible (когда будет playbook 40-security.yml):
```yaml
- name: "sshd | MaxSessions"
  ansible.builtin.raw: |
    sudo sed -i 's/MaxSessions 2/MaxSessions 6/' /etc/ssh/sshd_config.d/99-maxtg-hardening.conf
    sudo sshd -t && sudo systemctl reload sshd && echo CHANGED
```

## Правила работы с SSH на этом VPS

1. Никогда не запускать фоновые SSH (`run_in_background=true`) — они не закрываются вовремя
2. Ansible: всегда `ControlMaster=no` в ansible.cfg (уже настроено)
3. Минимизировать число SSH-сессий — объединять команды в одну сессию
4. При зависании Ansible — ждать 60 сек, не делать повторных попыток сразу
