# vps_management

Централизованный оркестратор для одного Hetzner CX23 VPS (Ubuntu 24.04, 4GB RAM, 40GB диск). Управляет **хостом** (диск, OS, sshd, ufw, мониторинг, бэкап, секреты доступа). Не управляет **приложениями** — это зоны других проектов в этом монорепо.

Источник истины для VPS access — `ansible/secrets/vault.yml` (ansible-vault encrypted).

## Структура

```
ansible/                  # Control plane (playbooks, roles, inventory, vault)
modules/                  # Standalone CLI tools (disk-report, secret-scan)
docs/                     # Architecture, ownership matrix, runbooks
reports/                  # Local-only verify/audit outputs (gitignored)
secrets/                  # Local fallback (gitignored, основное хранилище — vault)
verify.sh                 # Read-only health gate
```

## Quick start

### 1. Установка зависимостей (на Mac, один раз)

```bash
brew install ansible
ansible-galaxy collection install -r ansible/requirements.yml
```

### 2. Vault password

```bash
# Создать пароль
pwgen -s 32 1 > ~/.vault_pass.txt
chmod 600 ~/.vault_pass.txt

# Бэкап в 1Password (запись "vps_management ansible vault password")
```

### 3. Заполнить vault значениями

Скопировать значения из существующих файлов:
- `router_configuration/secrets/vps-access.local.env`
- `openclaw_firststeps/LOCAL_ACCESS.md`

```bash
cp ansible/secrets/vault.yml.example ansible/secrets/vault.yml
# Отредактировать ansible/secrets/vault.yml — заполнить значения
ansible-vault encrypt ansible/secrets/vault.yml
```

### 4. Smoke test

```bash
cd ansible
ansible -i inventory/production.yml vps -m ping
# Ожидаемо: vps-prod | SUCCESS => {"ping": "pong"}
```

### 5. Read-only health check

```bash
./verify.sh
# Все проверки должны пройти (exit 0)
```

### 6. Первая задача — освободить диск

```bash
cd ansible
ansible-playbook playbooks/10-disk-cleanup.yml --check --diff   # dry-run
# Review output — особенно строки про docker prune
ansible-playbook playbooks/10-disk-cleanup.yml                  # apply
./verify.sh                                                     # все сервисы должны остаться up
```

## Playbooks

| Playbook | Назначение | Mutating? |
|---|---|---|
| `99-verify.yml` | Read-only health checks (12 проверок) | No |
| `10-disk-cleanup.yml` | apt clean, journal vacuum, docker prune (с фильтрами!), logrotate | Yes |

Roadmap (не в этом этапе):
- `00-bootstrap.yml` — провижининг свежей VM
- `20-monitoring.yml` — node_exporter + Telegram alerter
- `30-backup.yml` — restic snapshots
- `40-security.yml` — fail2ban, unattended-upgrades, sshd baseline
- `60-docker-limits.yml` — mem_limit для uncapped контейнеров

## Modules

| Module | Tool | Назначение |
|---|---|---|
| `secrets-management` | `bin/secret-scan` | Сканер утечек VPS IP/ключей перед коммитом |
| `disk-observatory` | `bin/disk-report` | Standalone отчёт по диску (без ansible) |

## Безопасность

См. [SECURITY.md](SECURITY.md) для threat model и recovery boundaries.

Перед любым изменением — прочитай [AGENTS.md](AGENTS.md). Особенно safety rules.

## Owned vs not owned

Карта владения — [`docs/ownership-matrix.md`](docs/ownership-matrix.md).

**Кратко:** vps_management владеет хостом (`/etc/{ssh,ufw}`, `/var/log`, `/var/lib/docker` чисткой, sshd, мониторингом). Приложения в `/opt/<app>/` — зоны других проектов; vps_management их не деплоит и не трогает основные compose-файлы. Override-файлы для лимитов (`docker-compose.override.local.yml`) — единственная легитимная модификация.

## Verify

```bash
./verify.sh                                    # все проверки (12 шт)
./modules/disk-observatory/bin/disk-report     # детальный disk audit
./modules/secrets-management/bin/secret-scan   # перед каждым commit
```
