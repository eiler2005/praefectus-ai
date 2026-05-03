@AGENTS.md

# Claude Code

Все shared правила — в [AGENTS.md](AGENTS.md). Этот файл — короткие локальные заметки для Claude Code конкретно.

## Local notes

- Vault password живёт в `~/.vault_pass.txt` (mode 0600). Создаётся вручную, бэкап в 1Password.
- Перед любым плейбуком кроме `99-verify` — сначала `--check --diff`, потом apply.
- Если меняешь `vault.yml` — синхронно обнови `vault.yml.example` без значений (только новые ключи).
- Если впервые трогаешь зону другого проекта (`/opt/maxtg-bridge`, `/opt/openclaw`, etc.) — сначала прочитай [`docs/ownership-matrix.md`](docs/ownership-matrix.md).
- `lean-ctx` MCP инструменты предпочтительны (см. global CLAUDE.md): `ctx_read` вместо `Read` для повторных чтений, `ctx_search` вместо `grep`, `ctx_shell` вместо `bash` для команд с большим выводом.
