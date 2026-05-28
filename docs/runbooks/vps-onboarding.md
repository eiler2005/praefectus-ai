# VPS onboarding

Use this runbook when adding a new VPS to the PraefectusAI fleet.

## Model

Inventory aliases are safe to commit. Real endpoints are secrets and live only in the encrypted vault.

- `vps` — ready managed hosts.
- `vps_bootstrap` — fresh hosts that still need baseline setup.
- `vault_vps_hosts.<alias>` — encrypted SSH connection data for each host.

## 1. Add inventory alias

Add the host to `ansible/inventory/production.yml` under `vps_bootstrap`:

```yaml
vps_bootstrap:
  hosts:
    vps-example:
      expected_app_dirs: []
      expected_containers: []
```

Do not put a real IP, SSH user, port, or key path in inventory.

## 2. Add encrypted SSH values

Edit the vault:

```bash
cd ansible
ansible-vault edit group_vars/all/vault.yml
```

Add:

```yaml
vault_vps_hosts:
  vps-example:
    ssh_host: "<vps_ip_or_dns>"
    ssh_user: "root"
    ssh_port: 22
    ssh_key: "~/.ssh/id_rsa"
```

For a fresh provider image, `ssh_user` is often `root`. After bootstrap, change it to `deploy`.

## 3. Seed root SSH access

If the provider has not installed your key, add it through provider console or a one-time password flow:

```bash
ssh-copy-id -i ~/.ssh/id_rsa.pub -p <port> root@<vps_ip_or_dns>
```

Then verify without printing secrets:

```bash
./ansible/scripts/check-ssh-access.sh --host vps-example
```

Expected:

```text
DIRECT_OK
```

## 4. Dry-run bootstrap

Bootstrap is mutating, so dry-run first:

```bash
cd ansible
ansible-playbook playbooks/00-bootstrap.yml --limit vps-example --check --diff
```

Review the plan. Expected changes on a fresh VPS:

- Docker apt key/source
- Docker Engine + Compose plugin
- `deploy` user
- `deploy` authorized key
- passwordless sudo for `deploy`

## 5. Apply bootstrap

Apply only after the dry-run is reviewed:

```bash
ansible-playbook playbooks/00-bootstrap.yml --limit vps-example
```

## 6. Switch to deploy

Edit encrypted `vault_vps_hosts.<alias>.ssh_user` from `root` to `deploy`.

Move the host from `vps_bootstrap` to `vps` in inventory.

Verify:

```bash
./ansible/scripts/check-ssh-access.sh --host vps-example
cd ansible
ansible -i inventory/production.yml vps-example -m ping
```

## 7. Run read-only health check

```bash
./verify.sh --limit vps-example
```

Warnings are allowed during initial onboarding. Failures must be diagnosed before running further mutating playbooks.

## 8. Follow-up hardening

After bootstrap, run security hardening with the normal safety workflow:

```bash
cd ansible
ansible-playbook playbooks/40-security.yml --limit vps-example --check --diff
# review
ansible-playbook playbooks/40-security.yml --limit vps-example
```

Never run fleet-wide mutating playbooks casually. Use `--limit <host>` for onboarding and host-specific rollout.
