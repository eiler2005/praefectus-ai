#!/usr/bin/env bash
# Print one scalar key from ansible/group_vars/all/vault.yml.
# Used by inventory/production.yml and local helpers so connection params stay
# out of plaintext.
#
# Usage:
#   vault-get.sh vault_vps_ssh_host              # legacy root scalar
#   vault-get.sh --host vps-hetzner-prod ssh_host
#
# Host-scoped keys fall back to the legacy root keys for the Hetzner prod
# alias so older vaults keep working while the repo moves to a multi-VPS schema.

set -euo pipefail

ANSIBLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VAULT_FILE="${ANSIBLE_DIR}/group_vars/all/vault.yml"
HOST_NAME=""
if [[ "${1:-}" == "--host" ]]; then
  HOST_NAME="${2:?usage: vault-get.sh [--host <inventory-host>] <key>}"
  shift 2
else
  HOST_NAME="${VPS_TARGET:-}"
fi

KEY="${1:?usage: vault-get.sh [--host <inventory-host>] <key>}"
VAULT_PASS="${VAULT_PASS_FILE:-${HOME}/.vault_pass.txt}"

VAULT_ARGS=(view)
if [[ -f "${VAULT_PASS}" ]]; then
  VAULT_ARGS+=(--vault-password-file "${VAULT_PASS}")
fi
VAULT_ARGS+=("${VAULT_FILE}")

VAULT_CONTENT="$(ansible-vault "${VAULT_ARGS[@]}")"

VAULT_CONTENT="${VAULT_CONTENT}" python3 - "${HOST_NAME}" "${KEY}" <<'PY'
import os
import re
import sys

host = sys.argv[1]
key = sys.argv[2]
text = os.environ["VAULT_CONTENT"]

LEGACY = {
    "ssh_host": "vault_vps_ssh_host",
    "ssh_user": "vault_vps_ssh_user",
    "ssh_port": "vault_vps_ssh_port",
    "ssh_key": "vault_vps_ssh_key",
}

DEFAULTS = {
    "ssh_port": "22",
    "ssh_key": "~/.ssh/id_rsa",
}


def clean_value(raw: str) -> str:
    raw = raw.strip()
    if not raw:
        return ""

    quote = None
    out = []
    for ch in raw:
        if ch in ("'", '"'):
            if quote is None:
                quote = ch
            elif quote == ch:
                quote = None
        if ch == "#" and quote is None:
            break
        out.append(ch)

    value = "".join(out).strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in ("'", '"'):
        value = value[1:-1]
    return value


def root_scalar(name: str) -> str:
    pattern = re.compile(rf"^{re.escape(name)}:\s*(.*?)\s*$", re.MULTILINE)
    match = pattern.search(text)
    return clean_value(match.group(1)) if match else ""


def host_scalar(host_name: str, field: str) -> str:
    in_hosts = False
    current_host = None

    for line in text.splitlines():
        if re.match(r"^vault_vps_hosts:\s*$", line):
            in_hosts = True
            current_host = None
            continue

        if not in_hosts:
            continue

        if line and not line.startswith(" "):
            break

        host_match = re.match(r"^  ([A-Za-z0-9_.-]+):\s*$", line)
        if host_match:
            current_host = host_match.group(1)
            continue

        if current_host != host_name:
            continue

        key_match = re.match(rf"^    {re.escape(field)}:\s*(.*?)\s*$", line)
        if key_match:
            return clean_value(key_match.group(1))

    return ""


value = ""
if host:
    value = host_scalar(host, key)

if not value and (not host or host in {"vps-hetzner-prod", "vps-prod"}):
    legacy_key = LEGACY.get(key, key)
    value = root_scalar(legacy_key)

if not value:
    value = DEFAULTS.get(key, "")

if not value:
    sys.exit(1)

print(value)
PY
