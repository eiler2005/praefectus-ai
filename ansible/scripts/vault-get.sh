#!/usr/bin/env bash
# Print one scalar key from ansible/group_vars/all/vault.yml.
# Used by inventory/production.yml so connection params stay out of plaintext.

set -euo pipefail

ANSIBLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VAULT_FILE="${ANSIBLE_DIR}/group_vars/all/vault.yml"
KEY="${1:?usage: vault-get.sh <key>}"
VAULT_PASS="${VAULT_PASS_FILE:-${HOME}/.vault_pass.txt}"

VAULT_ARGS=(view)
if [[ -f "${VAULT_PASS}" ]]; then
  VAULT_ARGS+=(--vault-password-file "${VAULT_PASS}")
fi
VAULT_ARGS+=("${VAULT_FILE}")

ansible-vault "${VAULT_ARGS[@]}" \
  | awk -v key="${KEY}" '
      $0 ~ "^" key ":" {
        sub("^" key ":[[:space:]]*", "")
        gsub(/^"/, "")
        gsub(/"$/, "")
        print
        found = 1
        exit
      }
      END { if (!found) exit 1 }
    '
