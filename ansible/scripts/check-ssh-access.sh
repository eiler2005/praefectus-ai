#!/usr/bin/env bash
# Check VPS SSH reachability through the normal path and, optionally, through
# the router bastion break-glass path. Does not print secret host/user values.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST_ARGS=()

if [[ "${1:-}" == "--host" ]]; then
  HOST_ARGS=(--host "${2:?usage: check-ssh-access.sh [--host <inventory-host>]}")
fi

echo "== direct SSH =="
set +e
"${SCRIPT_DIR}/ssh-vps.sh" "${HOST_ARGS[@]}" 'echo DIRECT_OK' >/tmp/vps-direct-ssh-check.$$ 2>&1
direct_rc=$?
set -e
if [[ "${direct_rc}" -eq 0 ]]; then
  cat /tmp/vps-direct-ssh-check.$$
  rm -f /tmp/vps-direct-ssh-check.$$
  exit 0
fi
cat /tmp/vps-direct-ssh-check.$$ || true
rm -f /tmp/vps-direct-ssh-check.$$

if [[ -z "${VPS_BASTION_HOST:-}" || -z "${VPS_BASTION_USER:-}" ]]; then
  echo
  echo "direct SSH failed; bastion env is not set"
  echo "set VPS_BASTION_HOST and VPS_BASTION_USER to test break-glass access"
  exit "${direct_rc}"
fi

echo
echo "== bastion SSH =="
set +e
"${SCRIPT_DIR}/ssh-vps-via-bastion.sh" "${HOST_ARGS[@]}" 'echo BASTION_OK' >/tmp/vps-bastion-ssh-check.$$ 2>&1
bastion_rc=$?
set -e
if [[ "${bastion_rc}" -eq 0 ]]; then
  cat /tmp/vps-bastion-ssh-check.$$
  rm -f /tmp/vps-bastion-ssh-check.$$
  exit 0
fi
cat /tmp/vps-bastion-ssh-check.$$ || true
rm -f /tmp/vps-bastion-ssh-check.$$
exit "${bastion_rc}"
