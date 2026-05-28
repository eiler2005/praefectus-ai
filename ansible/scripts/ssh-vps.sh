#!/usr/bin/env bash
# SSH into a VPS using credentials from the vault.
# No args  → interactive session.
# With args → run the command and return its output.
#
# Examples:
#   ./ansible/scripts/ssh-vps.sh
#   ./ansible/scripts/ssh-vps.sh --host vps-hostkey-hermes
#   ./ansible/scripts/ssh-vps.sh 'df -h /'
#   ./ansible/scripts/ssh-vps.sh --print-host    # print host only (for embedding)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
VAULT_FILE="${ANSIBLE_DIR}/group_vars/all/vault.yml"
HOST_ALIAS="${VPS_TARGET:-vps-prod}"

if [[ "${1:-}" == "--host" ]]; then
  HOST_ALIAS="${2:?usage: ssh-vps.sh [--host <inventory-host>] [--print-host|command...]}"
  shift 2
fi

if [[ ! -f "${VAULT_FILE}" ]]; then
  echo "ERROR: vault not found at ${VAULT_FILE}" >&2
  exit 2
fi

VPS_HOST=$("${SCRIPT_DIR}/vault-get.sh" --host "${HOST_ALIAS}" ssh_host)
VPS_USER=$("${SCRIPT_DIR}/vault-get.sh" --host "${HOST_ALIAS}" ssh_user)
VPS_PORT=$("${SCRIPT_DIR}/vault-get.sh" --host "${HOST_ALIAS}" ssh_port)
VPS_KEY=$("${SCRIPT_DIR}/vault-get.sh" --host "${HOST_ALIAS}" ssh_key)

if [[ -z "${VPS_HOST}" || -z "${VPS_USER}" ]]; then
  echo "ERROR: SSH host/user for ${HOST_ALIAS} not set in vault" >&2
  exit 2
fi

if [[ "${1:-}" == "--print-host" ]]; then
  echo "${VPS_HOST}"
  exit 0
fi

SSH_OPTS=(-p "${VPS_PORT:-22}" -o ConnectTimeout=10 -o ServerAliveInterval=15)
if [[ -n "${VPS_KEY}" ]]; then
  VPS_KEY="${VPS_KEY/#\~/${HOME}}"
  if [[ -f "${VPS_KEY}" ]]; then
    SSH_OPTS+=(-i "${VPS_KEY}")
  fi
fi

if [[ $# -eq 0 ]]; then
  exec ssh "${SSH_OPTS[@]}" "${VPS_USER}@${VPS_HOST}"
else
  exec ssh "${SSH_OPTS[@]}" "${VPS_USER}@${VPS_HOST}" "$@"
fi
