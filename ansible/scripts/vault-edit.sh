#!/usr/bin/env bash
# Convenience wrapper for editing the vault.
# Uses $EDITOR (defaults to vim).

set -euo pipefail

ANSIBLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ANSIBLE_DIR}"

VAULT_FILE="secrets/vault.yml"

if [[ ! -f "${VAULT_FILE}" ]]; then
  echo "ERROR: ${VAULT_FILE} does not exist."
  echo
  echo "Create it from template:"
  echo "  cp secrets/vault.yml.example secrets/vault.yml"
  echo "  # edit values"
  echo "  ansible-vault encrypt secrets/vault.yml"
  exit 1
fi

EDITOR="${EDITOR:-vim}" exec ansible-vault edit "${VAULT_FILE}"
