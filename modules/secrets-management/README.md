# secrets-management

Secret-leak scanner. Greps the entire repo for known sensitive patterns: real public IPs, SSH private keys, hardcoded `api_key=` / `token=`. Ignores `vault.yml` (encrypted) and `reports/` (local artefacts).

## Usage

```bash
./bin/secret-scan
```

Exit codes:

- `0` — clean
- non-zero — leak detected (with a per-finding report)

## What it catches

- Public IPv4 addresses outside RFC 1918, RFC 5737 (TEST-NET), loopback, and Docker bridge ranges.
- SSH private keys (PEM-style key headers — OpenSSH, RSA, DSA, ECDSA).
- Hardcoded `api_key=`, `token=`, `password=` patterns with non-empty values.
- Cloud-provider tokens (Hetzner, AWS access keys, etc.) — pattern-based.

## When to run

- **Before every commit.** Wired into `.pre-commit-config.yaml`.
- In CI on push (`.github/workflows/ci.yml`).
- Before opening a PR.

## Output sample

See [`examples/sample-secret-scan.txt`](../../examples/sample-secret-scan.txt).
