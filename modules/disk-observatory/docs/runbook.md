# Runbook: disk-observatory

Standalone отчёт по состоянию диска VPS. Используется для быстрого ad-hoc audit без запуска ansible.

## Когда запускать

- Перед каждым `10-disk-cleanup.yml` — посмотреть что вырастет/уменьшится.
- При срабатывании disk-алёрта (когда появится monitoring).
- Раз в неделю как plain audit, результат сохраняется в `reports/disk-report-*.md`.

## Использование

```bash
# Полный отчёт с сохранением в reports/
./modules/disk-observatory/bin/disk-report

# Только в stdout (без файла)
./modules/disk-observatory/bin/disk-report --no-save
```

## Что собирает

Через одну SSH-сессию:
- `df -h /` — общая занятость
- `free -h` — память
- `/proc/loadavg` — нагрузка
- `du -sh` для `/var/log`, `/var/lib/docker`, `/var/cache`, `/opt/*`, `/home/*` (top 20)
- `docker system df` — детальная docker-разбивка
- `journalctl --disk-usage` — место под журналом
- Размер apt cache
- Top-50 файлов >100M
- Dangling docker volumes (для manual review)

## Зависимости

- На Mac: `ansible` (для `ansible-vault view`)
- На VPS: стандартный coreutils + docker
- Vault password в `~/.vault_pass.txt`
