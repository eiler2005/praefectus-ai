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
#     ./ansible/scripts/ssh-vps-via-bastion.sh

set -euo pipefail

ANSIBLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VAULT_FILE="${ANSIBLE_DIR}/group_vars/all/vault.yml"

if [[ ! -f "${VAULT_FILE}" ]]; then
  echo "ERROR: vault not found at ${VAULT_FILE}" >&2
  exit 2
fi

: "${VPS_BASTION_HOST:?Set VPS_BASTION_HOST in your local shell}"
: "${VPS_BASTION_USER:?Set VPS_BASTION_USER in your local shell}"

VPS_BASTION_PORT="${VPS_BASTION_PORT:-22}"
VPS_BASTION_CONNECT_TIMEOUT="${VPS_BASTION_CONNECT_TIMEOUT:-8}"

VAULT_CONTENT=$(ansible-vault view "${VAULT_FILE}")
VPS_HOST=$(echo "${VAULT_CONTENT}" | awk -F'"' '/^vault_vps_ssh_host:/ {print $2; exit}')
VPS_USER=$(echo "${VAULT_CONTENT}" | awk -F'"' '/^vault_vps_ssh_user:/ {print $2; exit}')
VPS_PORT=$(echo "${VAULT_CONTENT}" | awk '/^vault_vps_ssh_port:/ {print $2; exit}')
VPS_KEY=$(echo "${VAULT_CONTENT}" | awk -F'"' '/^vault_vps_ssh_key:/ {print $2; exit}')
VPS_PORT="${VPS_PORT:-22}"

if [[ -z "${VPS_HOST}" || -z "${VPS_USER}" ]]; then
  echo "ERROR: vault_vps_ssh_host or vault_vps_ssh_user not set in vault" >&2
  exit 2
fi

SSH_OPTS=(
  -p "${VPS_PORT}"
  -o ControlMaster=no
  -o ControlPath=none
  -o BatchMode=yes
  -o ConnectTimeout=20
  -o ConnectionAttempts=1
  -o ServerAliveInterval=15
  -o "ProxyCommand=ssh -p ${VPS_BASTION_PORT} -o BatchMode=yes -o ConnectTimeout=${VPS_BASTION_CONNECT_TIMEOUT} -W %h:%p ${VPS_BASTION_USER}@${VPS_BASTION_HOST}"
)

if [[ -n "${VPS_KEY}" ]]; then
  SSH_OPTS+=(-i "${VPS_KEY}" -o IdentitiesOnly=yes)
fi

if [[ $# -eq 0 ]]; then
  exec ssh "${SSH_OPTS[@]}" "${VPS_USER}@${VPS_HOST}"
else
  exec ssh "${SSH_OPTS[@]}" "${VPS_USER}@${VPS_HOST}" "$@"
fi
