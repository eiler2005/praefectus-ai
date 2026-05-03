# Agent Instructions — vps_management

Shared rules for any agent (Codex, Claude Code, others) working in this repository.

## Project Snapshot

`vps_management` — централизованный оркестратор для одного Hetzner CX23 VPS (Ubuntu 24.04, 4GB RAM, 2 vCPU, 40GB диск, deploy@22).

**Что мы владеем (host layer):**
- OS пакеты, ядро, sysctl
- `/etc/{ssh,ufw,fail2ban}` (системная безопасность)
- `/var/log`, `/var/lib/docker` (системная чистка)
- `/home/deploy/.ssh`, `/home/deploy/.config/syncthing`
- Docker daemon (но НЕ application docker-compose файлы)
- Мониторинг здоровья сервера, бэкапы host-уровня, секреты доступа

**Что мы НЕ владеем (application layer):**
- `/opt/maxtg-bridge/` — владелец [`maxtg_bridge`](../maxtg_bridge/)
- `/opt/openclaw/`, `/opt/lightrag/`, `/opt/omniroute/`, `/opt/{telethon-digest,signals-bridge,wiki-import,agentmail-*}/` — владелец [`openclaw_firststeps`](../openclaw_firststeps/)
- `/etc/{caddy,xray,unbound}/` — владелец [`router_configuration`](../router_configuration/)
- Любые `docker-compose.yml` в `/opt/<app>/` — это файлы-владельцы чужих репо

Полная карта владения — [`docs/ownership-matrix.md`](docs/ownership-matrix.md).

**Источник истины для VPS access** — `ansible/secrets/vault.yml` (ansible-vault encrypted). Никаких реальных IP/SSH/токенов в коммитах вне vault.

---

## Karpathy-Style Agent Workflow

LLM-агенты часто ошибаются на ровном месте — следуй этим правилам, чтобы не терять время на регрессии.

1. **Думай перед действием.** Прочитай задачу, прочитай AGENTS.md, прочитай нужные docs/runbooks/. Не открывай редактор пока не понял что и зачем.
2. **Читай документацию первым.** Перед изменением плейбука/роли — прочитай `docs/architecture.md` и соответствующий runbook. Перед трогением `/opt/<app>` — обязательно `docs/ownership-matrix.md`.
3. **Минимальные изменения.** Один тикет — одна правка. Не рефакторь "заодно". Не добавляй фичи которые не просили.
4. **Хирургические edits.** Меняй только нужные файлы. Не переформатируй чужие. Не "улучшай" комментарии.
5. **Соответствуй стилю проекта.** YAML с двухпробельным отступом, bash с `set -euo pipefail`, имена ролей в `snake_case`, плейбуки в `kebab-case` с числовым префиксом.
6. **Сохраняй работу пользователя.** Если в репо есть незафиксированные изменения — НЕ запускай `git checkout`/`reset`/`clean`. Сначала спроси.
7. **Чисти только за собой.** Если создал tmp-файл — удали. Не "приберись" в `reports/` или `secrets/` — это пользовательские артефакты.
8. **Работай к проверяемой цели.** Каждая правка должна заканчиваться чем-то измеримым: `--syntax-check` зелёный, `verify.sh` зелёный, конкретная метрика изменилась.

---

## Safety Rules

Жёсткие ограничения. Нарушение = регрессия.

### Git
- Никогда `git commit` или `git push` без явного разрешения пользователя.
- Никогда не делай `--no-verify`, `--no-gpg-sign`, `--amend` без явного запроса.
- Никогда `git reset --hard`, `git clean -fd`, `git checkout -- .` — это уничтожает чужую работу.

### Ansible / SSH
- Никогда не запускай mutating плейбуки (`10-*, 11-*, 20-*, 30-*, 40-*, 50-*, 60-*`) без явного разрешения.
- Перед apply — обязательно `ansible-playbook ... --check --diff` и review output.
- Read-only операции (`99-verify.yml`, `verify.sh`, `disk-report`, `secret-scan`) можно запускать без подтверждения.
- Если `99-verify.yml` показывает fail — сначала разобраться, потом mutating плейбук.

### Docker (особенно опасно — данные приложений)
- Никогда `docker volume prune` автоматом. Volumes хранят state.
- Никогда `docker system prune -a` без `--filter "until=Nh"`. Без фильтра прибьёт images используемые остановленными временно контейнерами.
- Никогда `docker compose down -v` где-либо в `/opt/*` — это снесёт application data.
- Никогда не редактируй `/opt/<app>/docker-compose.yml` — это файл чужого репо. Override-файлы (`docker-compose.override.local.yml`) — наша зона.

### System
- Никогда не отключай UFW даже "временно для теста".
- Никогда не редактируй `/etc/ssh/sshd_config` напрямую — только через ansible role с `validate: sshd -t -f %s` и backup.
- Никогда не делай `apt full-upgrade` или `do-release-upgrade` без явной авторизации. Только `unattended-upgrades` с allowlist `-security`.
- Никогда не перезагружай VPS без явного разрешения.

### Cross-project
- Перед mutating действием на работающие сервисы (`/opt/maxtg-bridge`, `/opt/openclaw`, etc.) — прочитай `docs/ownership-matrix.md`. Это зоны других проектов; вмешательство = координация с владельцем.
- Override-файлы лимитов (`docker-compose.override.local.yml`) — единственная легитимная модификация в чужой зоне со стороны vps_management.

---

## Secrets and Privacy

### Что считается секретом
- VPS публичный IP
- SSH user, SSH port (даже если стандартные)
- Имена контейнеров с уникальными суффиксами/UUID
- Telegram bot tokens, chat IDs, topic IDs
- B2/S3 ключи, restic password (когда появятся)
- Trusted IPs в UFW allowlist
- Hetzner API tokens

### Где живут
- **Все секреты** → `ansible/secrets/vault.yml` (ansible-vault AES-256 encrypted, в git зашифрованным).
- Vault password → `~/.vault_pass.txt` (mode 0600, НЕ в git, бэкап в 1Password).
- Шаблон без значений → `ansible/secrets/vault.yml.example` (в git plaintext).

### В коммитах и документации
- Используй плейсхолдеры: `<vps_host>`, `<vps_ip>`, `198.51.100.10` (RFC5737 TEST-NET), `example.invalid`.
- Никогда не коммить реальный IP/токен даже в комментарии или в `docs/`.
- Перед каждым коммитом — `./modules/secrets-management/bin/secret-scan`. Должен exit 0.

---

## Architecture Invariants

1. **Host vs app ownership** — vps_management управляет хостом. Приложения управляют собой.
2. **Vault — single source of truth** — все секреты доступа здесь, дочерние проекты читают через `ansible-vault view` или плейсхолдеры.
3. **Playbook numbering — semantic** — `00` bootstrap (одноразово), `10-50` mutating maintenance, `60-80` advanced/optional, `99` verify (read-only).
4. **Read-only by default** — все operations начинаются с audit. Mutating требует явного permission.
5. **Override files are our zone** — `/opt/<app>/docker-compose.override.local.yml` — наш способ накладывать host-policy (mem_limits, restart policies). Основной compose — не наш.
6. **Filters always** — любой `docker prune` имеет `--filter "until=Nh"`. Без фильтра — fail.
7. **Volumes are sacred** — никогда не prune автоматом. Только manual review.

---

## Where Things Live

| Что | Где |
|---|---|
| Shared rules | `AGENTS.md` (этот файл) |
| Local Claude Code notes | `CLAUDE.md` |
| User-facing overview | `README.md` |
| Threat model | `SECURITY.md` |
| Architecture docs | `docs/architecture.md`, `docs/ownership-matrix.md` |
| Runbooks | `docs/runbooks/*.md` |
| Ansible config | `ansible/ansible.cfg` |
| Inventory | `ansible/inventory/production.yml` |
| Non-secret vars | `ansible/group_vars/{all,vps}.yml` |
| Secrets (encrypted) | `ansible/secrets/vault.yml` |
| Secrets template | `ansible/secrets/vault.yml.example` |
| Playbooks | `ansible/playbooks/NN-name.yml` |
| Reusable roles | `ansible/roles/<name>/` |
| Helper scripts (vault, ssh) | `ansible/scripts/*.sh` |
| Module CLI tools | `modules/<module>/bin/<tool>` |
| Module docs | `modules/<module>/docs/*.md` |
| Verify entrypoint | `verify.sh` (root) |
| Local-only outputs | `reports/*.md` (gitignored) |

---

## Checks

Read-only проверки которые можно запускать без подтверждения:

```bash
# Сканер утечек секретов в коммитах
./modules/secrets-management/bin/secret-scan

# Синтаксис всех плейбуков
cd ansible
ansible-playbook --syntax-check playbooks/*.yml

# Линтеры (если установлены)
ansible-lint playbooks/ roles/
yamllint inventory/ group_vars/ playbooks/ roles/

# Health gate
./verify.sh

# Standalone disk report
./modules/disk-observatory/bin/disk-report
```

---

## Docs to Read

Перед любой нетривиальной правкой — прочитай относящееся:

- [`docs/architecture.md`](docs/architecture.md) — модель host vs app, что где живёт
- [`docs/ownership-matrix.md`](docs/ownership-matrix.md) — кто чем владеет на VPS
- [`docs/runbooks/disk-full.md`](docs/runbooks/disk-full.md) — что делать при заполнении диска
- [`SECURITY.md`](SECURITY.md) — threat model, recovery boundaries
- [`README.md`](README.md) — high-level overview, quick start
