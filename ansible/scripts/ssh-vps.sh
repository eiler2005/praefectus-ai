#!/usr/bin/env bash
# SSH into the VPS using credentials from the vault.
# No args  → interactive session.
# With args → run the command and return its output.
#
# Examples:
#   ./ansible/scripts/ssh-vps.sh
#   ./ansible/scripts/ssh-vps.sh 'df -h /'
#   ./ansible/scripts/ssh-vps.sh --print-host    # print host only (for embedding)

set -euo pipefail

ANSIBLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VAULT_FILE="${ANSIBLE_DIR}/group_vars/all/vault.yml"

if [[ ! -f "${VAULT_FILE}" ]]; then
  echo "ERROR: vault not found at ${VAULT_FILE}" >&2
  exit 2
fi

VAULT_CONTENT=$(ansible-vault view "${VAULT_FILE}")
VPS_HOST=$(echo "${VAULT_CONTENT}" | awk -F'"' '/^vault_vps_ssh_host:/ {print $2; exit}')
VPS_USER=$(echo "${VAULT_CONTENT}" | awk -F'"' '/^vault_vps_ssh_user:/ {print $2; exit}')
VPS_PORT=$(echo "${VAULT_CONTENT}" | awk '/^vault_vps_ssh_port:/ {print $2; exit}')
VPS_PORT="${VPS_PORT:-22}"

if [[ -z "${VPS_HOST}" || -z "${VPS_USER}" ]]; then
  echo "ERROR: vault_vps_ssh_host or vault_vps_ssh_user not set in vault" >&2
  exit 2
fi

if [[ "${1:-}" == "--print-host" ]]; then
  echo "${VPS_HOST}"
  exit 0
fi

SSH_OPTS=(-p "${VPS_PORT}" -o ConnectTimeout=10 -o ServerAliveInterval=15)

if [[ $# -eq 0 ]]; then
  exec ssh "${SSH_OPTS[@]}" "${VPS_USER}@${VPS_HOST}"
else
  exec ssh "${SSH_OPTS[@]}" "${VPS_USER}@${VPS_HOST}" "$@"
fi
