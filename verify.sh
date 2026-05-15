#!/usr/bin/env bash
# Read-only health gate. Runs ansible/playbooks/99-verify.yml.
# No mutations on the VPS — safe to call at any time.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${PROJECT_ROOT}/ansible"

exec ansible-playbook playbooks/99-verify.yml "$@"
