# Overview — vps_management

Полный навигационный индекс репозитория: что есть, где лежит, когда использовать.

> README.md — quick-start (clone → vault → smoke test). Этот файл — справочник по всему, что управляет VPS.

---

## TL;DR — куда смотреть в первую очередь

| Хочу | Команда / документ |
|---|---|
| Проверить здоровье VPS прямо сейчас | `./verify.sh` |
| Текущий снимок состояния | [`docs/dashboard.md`](dashboard.md) (обновить: `./modules/dashboard/bin/update-dashboard`) |
| Понять, кто чем владеет на сервере | [`docs/ownership-matrix.md`](ownership-matrix.md) |
| Освободить место на диске | `ansible-playbook playbooks/10-disk-cleanup.yml --check` → apply |
| Запустить health-check + Telegram alert вручную | `./modules/monitoring/bin/run-check` |
| Threat model и границы recovery | [`SECURITY.md`](../SECURITY.md) |
| Правила работы агентов в репо | [`AGENTS.md`](../AGENTS.md) |

---

## Playbooks (`ansible/playbooks/`)

| # | Файл | Назначение | Mutating? |
|---|---|---|---|
| 10 | `10-disk-cleanup.yml` | Однократная чистка: apt clean, journal vacuum (14d/500M), docker prune (с `--filter until=Nh`), logrotate config. Volumes не трогаем. | yes |
| 11 | `11-periodic-cleanup-setup.yml` | Устанавливает canonical `vps-cleanup.timer` + `/usr/local/bin/vps-periodic-cleanup.sh` (вс 03:00 UTC), retires legacy `vps-weekly-cleanup.timer`. | yes (one-shot setup) |
| 11 deprecated | `11-schedule-cleanup.yml` | Guardrail only: intentionally fails and points to `11-periodic-cleanup-setup.yml`. | no |
| 20 | `20-monitoring.yml` | Деплоит Python-poller `/usr/local/bin/vps-monitor.py` + systemd timer (5 мин). Алертит в Telegram при WARN/CRIT. | yes |
| 30 | `30-backup.yml` | restic + B2: бэкап `/opt/maxtg-bridge/data`, `/opt/openclaw/workspace`, `/opt/obsidian-vault/wiki`. Systemd timer ежедневно 02:00 UTC. Теги: `--tags run` (разовый запуск), `--tags status` (снимки + таймер). | yes (one-shot setup) |
| 40 | `40-security.yml` | fail2ban (sshd jail), unattended-upgrades (только -security), sshd MaxSessions enforcement, UFW audit. | yes |
| 50 | `50-syncthing-audit.yml` | Поиск `*.sync-conflict-*`, файлы > 100MB, peer status через Syncthing API. Пишет `reports/syncthing-audit-<ts>.md`. | read + report |
| 60 | `60-docker-limits.yml` | mem_limit для 5 less-critical контейнеров (256–384m) через `docker-compose.override.local.yml`. | yes (без auto-restart) |
| 70 | `70-docker-limits-critical.yml` | mem_limit для критичных (gateway/omniroute/lightrag/redis): override.local.yml + `docker update --memory` (без перезапуска). | yes |
| 99 | `99-verify.yml` | Read-only health gate. 12 проверок (disk, mem, swap, load, docker, containers, ufw, restarts, app dirs). Пишет `reports/health/<ts>.json` + `reports/verify-<ts>.md`. | **no** |

Перед любым mutating playbook — обязательно `--check --diff` (см. [AGENTS.md](../AGENTS.md) safety rules).

---

## CLI utilities (`modules/<name>/bin/`)

| Команда | Что делает | Когда нужна |
|---|---|---|
| `./verify.sh` | Wrapper над `99-verify.yml`. Полный health-check за 5 секунд. | Перед/после любого mutating действия |
| [`modules/dashboard/bin/update-dashboard`](../modules/dashboard/bin/update-dashboard) | Читает свежий `reports/health/*.json` + `reports/cleanup-*.md` + `reports/syncthing-audit-*.md`, генерит `docs/dashboard.md`. | Когда нужна актуальная картина без логина в VPS |
| [`modules/disk-observatory/bin/disk-report`](../modules/disk-observatory/bin/disk-report) | Standalone (без ansible) SSH в VPS, собирает df/du/docker df, печатает + сохраняет в `reports/`. | Быстрый disk-audit без playbook |
| [`modules/health-trends/bin/health-trend`](../modules/health-trends/bin/health-trend) | Анализ N последних `reports/health/*.json`: тренд диска/swap/памяти, нестабильные контейнеры. Флаги: `--last N`, `--trend disk`. | Когда хочется видеть динамику, а не точечный снимок |
| [`modules/maintenance-journal/bin/cleanup-fetch`](../modules/maintenance-journal/bin/cleanup-fetch) | SSH в VPS, тянет `/var/log/vps-periodic-cleanup.log` (fallback: legacy weekly log), агрегирует по неделям в `reports/maintenance/<YYYY-MM>.md`. Флаги: `--all`, `--stdout`. | Раз в месяц — посмотреть что чистил автотаймер |
| [`modules/monitoring/bin/run-check`](../modules/monitoring/bin/run-check) | Запускает `vps-monitor.py --once` на VPS. Флаги: `--test-alert` (тест Telegram), `--log` (показать `/var/log/vps-monitor.log`), `--status` (systemd timer). | Ручная проверка вне 5-мин таймера |
| [`modules/port-audit/bin/port-audit`](../modules/port-audit/bin/port-audit) | Сравнивает реальные listeners (`ss -tlnp`) с `docs/ports.md`. Ловит новые порты, пропавшие, небезопасные `0.0.0.0`-bindings. Флаги: `--save`, `--live-only`. | После добавления нового сервиса; ежемесячный security audit |
| [`modules/secrets-management/bin/secret-scan`](../modules/secrets-management/bin/secret-scan) | Grep по всему репо: реальный VPS IP, публичные IPv4 (кроме TEST-NET), SSH private keys, hardcoded `api_key=`/`token=`. Игнорит vault.yml и reports/. | **Перед каждым commit** |

---

## Roles (`ansible/roles/`)

| Роль | Используется в | Статус |
|---|---|---|
| `monitoring` | `20-monitoring.yml` | active |
| `disk_audit`, `disk_cleanup`, `verify` | — | scaffolded, но логика inline в playbooks (раз раз module = `raw` для pipelining-совместимости) |

---

## Documentation index (`docs/`)

| Документ | Тема | Когда читать |
|---|---|---|
| [`architecture.md`](architecture.md) | Host vs app ownership: что владеет vps_management vs соседние проекты | Первый онбординг |
| [`ownership-matrix.md`](ownership-matrix.md) | Таблица: путь на VPS → проект-владелец → можно ли модифицировать | **Обязательно** перед mutating действием в `/opt/<app>` |
| [`dashboard.md`](dashboard.md) | Текущий снимок состояния (генерится `update-dashboard`) | Быстрый взгляд «как дела сейчас» |
| [`containers.md`](containers.md) | Все 13 контейнеров: owner, image, ports, mem_limit | При планировании ресурсов / новых сервисов |
| [`ports.md`](ports.md) | Каноническая карта портов (источник для `port-audit`) | При добавлении сервиса; разбор конфликтов |
| [`firewall.md`](firewall.md) | UFW правила и trusted IPs | Security review |
| [`overview.md`](overview.md) | Этот файл — индекс всего | Когда забыл, что у нас вообще есть |

Top-level (корень репо):

| Файл | Назначение |
|---|---|
| [`README.md`](../README.md) | Quick-start: clone → vault → smoke test → first playbook |
| [`AGENTS.md`](../AGENTS.md) | Shared rules для всех агентов (Karpathy workflow + safety + secrets policy) |
| [`CLAUDE.md`](../CLAUDE.md) | Local notes для Claude Code (vault password location, lean-ctx prefs) |
| [`SECURITY.md`](../SECURITY.md) | Threat model, recovery boundaries |

---

## Runbooks (`docs/runbooks/`)

Сценарий → инструкция.

| Триггер | Runbook |
|---|---|
| Диск ≥ 90%, пользователь зажат | [`disk-full.md`](runbooks/disk-full.md) |
| «Что значит OK / WARN / CRIT» | [`health-rules.md`](runbooks/health-rules.md) |
| Когда что запускать (auto/manual cadence) | [`maintenance-schedule.md`](runbooks/maintenance-schedule.md) |
| Подозрение на компрометацию | [`security-incident.md`](runbooks/security-incident.md) |
| SSH `Too many authentication failures` / MaxSessions | [`ssh-maxsessions.md`](runbooks/ssh-maxsessions.md) |
| SSH banner timeout, direct path unavailable, VPN source changed | [`ssh-breakglass-bastion.md`](runbooks/ssh-breakglass-bastion.md) |

---

## Reports (`reports/` — gitignored, локальные артефакты)

| Паттерн | Источник | Что внутри |
|---|---|---|
| `reports/health/<ts>.json` | `99-verify.yml` | Структурированные метрики (для `health-trend`) |
| `reports/verify-<ts>.md` | `99-verify.yml` | Human-readable снимок 12 проверок |
| `reports/cleanup-<ts>.md` | `10-disk-cleanup.yml` | До/после диска, что почистил, freed MB |
| `reports/syncthing-audit-<ts>.md` | `50-syncthing-audit.yml` | Conflict-файлы, peer status, large files |
| `reports/maintenance/<YYYY-MM>.md` | `cleanup-fetch` | Агрегированная история weekly auto-cleanup |
| `reports/disk-<ts>.md` | `disk-observatory/bin/disk-report` | Disk audit без playbook |
| `reports/port-audit-<ts>.txt` | `port-audit --save` | Snapshot портов + расхождения с `docs/ports.md` |

---

## Journal (`docs/journal/`)

Ручной журнал серьёзных вмешательств — что сделано, кем, зачем. Один файл на месяц.

- [`docs/journal/2026-05.md`](journal/2026-05.md) — текущий

Заполняется руками после каждого крупного действия (миграция, рестарт критичного сервиса, изменение лимитов и т.п.).

---

## Roadmap — что осталось сделать

| # | Что | Зачем | Приоритет |
|---|---|---|---|
| 11 | `00-bootstrap.yml` — DR / fresh install | Холодный provisioning свежей CX23 (apt baseline, deploy user, UFW, Docker CE, /opt/* каталоги, restic restore). | средний |
| 12 | TLS / cert monitoring | `tls-audit`: expiry для 443/22000, alert < 14 дней. | средний |
| 13 | Image vulnerability scan (trivy) | Ежемесячный CVE-аудит запущенных images. | низкий |
| 14 | OOM detection с TG алертом | `dmesg \| grep "killed process"` → Telegram (важно после установки лимитов в этапах 2–3). | низкий — частично уже в monitoring |
| 15 | SQLite integrity check | `PRAGMA integrity_check` на `.db` в `/opt/maxtg-bridge/data` перед backup. | низкий |
| 16 | Cost monitoring | Hetzner API + B2 storage usage, monthly check. | низкий |
| 17 | Migration playbook CX23 → CX33 | Когда 4GB станет мало. Тестировать на test-VM ежеквартально. | низкий |

### Open todo (не из roadmap, выявлено в текущей сессии)

- **Telegram токены в vault.** Без `vault_tg_infra_bot_token` + `vault_tg_infra_chat_id` мониторинг работает, но ничего не алертит. После добавления — `ansible-playbook playbooks/20-monitoring.yml` для перерендера скрипта.
- **`openclaw-openclaw-gateway-1 RestartCount=4`** — known WARN. Не наша зона (owner = `openclaw_firststeps`), фиксируем для координации.

---

## Где искать историю и решения

| Что | Где |
|---|---|
| План изменений / архитектурные решения | `~/.claude/plans/*.md` (личные плановые файлы, не в git) |
| Журнал ручных действий | [`docs/journal/<YYYY-MM>.md`](journal/) |
| История кода | `git log` |
| История этапов реализации | См. таблицу в верхней части старых plan-файлов |
