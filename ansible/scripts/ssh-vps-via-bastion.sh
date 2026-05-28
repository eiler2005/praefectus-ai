#!/usr/bin/env bash
# Break-glass SSH into the VPS through an operator-controlled router bastion.
# VPS coordinates come from Ansible Vault; bastion coordinates must be provided
# via local environment variables and must never be committed.
#
# Required local env:
#   VPS_BASTION_HOST=<router_lan_or_remote_host>
#   VPS_BASTION_USER=<router_ssh_user>
#
# Optional local env:
#   VPS_BASTION_PORT=22
#   VPS_BASTION_CONNECT_TIMEOUT=8
#
# Examples:
#   VPS_BASTION_HOST=<router_host> VPS_BASTION_USER=<router_user> \
#     ./ansible/scripts/ssh-vps-via-bastion.sh 'df -h /'
#   VPS_BASTION_HOST=<router_host> VPS_BASTION_USER=<router_user> \
#     ./ansible/scripts/ssh-vps-via-bastion.sh --host vps-hostkey-hermes
#   VPS_BASTION_HOST=<router_host> VPS_BASTION_USER=<router_user> \
#     ./ansible/scripts/ssh-vps-via-bastion.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
VAULT_FILE="${ANSIBLE_DIR}/group_vars/all/vault.yml"
HOST_ALIAS="${VPS_TARGET:-vps-prod}"

if [[ "${1:-}" == "--host" ]]; then
  HOST_ALIAS="${2:?usage: ssh-vps-via-bastion.sh [--host <inventory-host>] [command...]}"
  shift 2
fi

if [[ ! -f "${VAULT_FILE}" ]]; then
  echo "ERROR: vault not found at ${VAULT_FILE}" >&2
  exit 2
fi

: "${VPS_BASTION_HOST:?Set VPS_BASTION_HOST in your local shell}"
: "${VPS_BASTION_USER:?Set VPS_BASTION_USER in your local shell}"

VPS_BASTION_PORT="${VPS_BASTION_PORT:-22}"
VPS_BASTION_CONNECT_TIMEOUT="${VPS_BASTION_CONNECT_TIMEOUT:-8}"

VPS_HOST=$("${SCRIPT_DIR}/vault-get.sh" --host "${HOST_ALIAS}" ssh_host)
VPS_USER=$("${SCRIPT_DIR}/vault-get.sh" --host "${HOST_ALIAS}" ssh_user)
VPS_PORT=$("${SCRIPT_DIR}/vault-get.sh" --host "${HOST_ALIAS}" ssh_port)
VPS_KEY=$("${SCRIPT_DIR}/vault-get.sh" --host "${HOST_ALIAS}" ssh_key)

if [[ -z "${VPS_HOST}" || -z "${VPS_USER}" ]]; then
  echo "ERROR: SSH host/user for ${HOST_ALIAS} not set in vault" >&2
  exit 2
fi

SSH_OPTS=(
  -p "${VPS_PORT:-22}"
  -o ControlMaster=no
  -o ControlPath=none
  -o BatchMode=yes
  -o ConnectTimeout=20
  -o ConnectionAttempts=1
  -o ServerAliveInterval=15
  -o "ProxyCommand=ssh -p ${VPS_BASTION_PORT} -o BatchMode=yes -o ConnectTimeout=${VPS_BASTION_CONNECT_TIMEOUT} -W %h:%p ${VPS_BASTION_USER}@${VPS_BASTION_HOST}"
)

if [[ -n "${VPS_KEY}" ]]; then
  VPS_KEY="${VPS_KEY/#\~/${HOME}}"
  if [[ -f "${VPS_KEY}" ]]; then
    SSH_OPTS+=(-i "${VPS_KEY}" -o IdentitiesOnly=yes)
  fi
fi

if [[ $# -eq 0 ]]; then
  exec ssh "${SSH_OPTS[@]}" "${VPS_USER}@${VPS_HOST}"
else
  exec ssh "${SSH_OPTS[@]}" "${VPS_USER}@${VPS_HOST}" "$@"
fi
