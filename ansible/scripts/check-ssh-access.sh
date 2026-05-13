#!/usr/bin/env bash
# Check VPS SSH reachability through the normal path and, optionally, through
# the router bastion break-glass path. Does not print secret host/user values.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "== direct SSH =="
if "${SCRIPT_DIR}/ssh-vps.sh" 'echo DIRECT_OK' >/tmp/vps-direct-ssh-check.$$ 2>&1; then
  cat /tmp/vps-direct-ssh-check.$$
  rm -f /tmp/vps-direct-ssh-check.$$
  exit 0
fi
direct_rc=$?
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
if "${SCRIPT_DIR}/ssh-vps-via-bastion.sh" 'echo BASTION_OK' >/tmp/vps-bastion-ssh-check.$$ 2>&1; then
  cat /tmp/vps-bastion-ssh-check.$$
  rm -f /tmp/vps-bastion-ssh-check.$$
  exit 0
fi
bastion_rc=$?
cat /tmp/vps-bastion-ssh-check.$$ || true
rm -f /tmp/vps-bastion-ssh-check.$$
exit "${bastion_rc}"
