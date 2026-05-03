#!/usr/bin/env bash
# Read-only health gate. Запускает ansible/playbooks/99-verify.yml.
# Никаких изменений на VPS, безопасно вызывать в любой момент.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${PROJECT_ROOT}/ansible"

exec ansible-playbook playbooks/99-verify.yml "$@"
