# Runbook: SSH break-glass via bastion

Use this path when direct VPS SSH accepts TCP but does not return an SSH banner:

```
Connection timed out during banner exchange
```

This is a backup route to the same VPS `sshd`, reached through an operator-controlled bastion (typically a home router or a separately-administered jump host). It does not bypass host SSH policy, keys, or `AllowUsers` — it only changes the network path.

## When to use

- Direct `./ansible/scripts/ssh-vps.sh 'true'` fails before authentication.
- `nc -vz <vps_host> 22` succeeds, but SSH never returns the remote banner.
- The bastion is reachable from the current operator network.

Do not use this for normal maintenance. Prefer the direct vault-backed SSH path.

## Recovery ladder

Use the smallest working step. Avoid opening many parallel SSH attempts while debugging — they make banner / `MaxStartups` symptoms worse.

1. Check direct access:

   ```bash
   ./ansible/scripts/check-ssh-access.sh
   ```

2. If direct SSH fails, confirm the server is externally alive:

   ```bash
   ping -c 3 <vps_host>
   nc -vz -w 5 <vps_host> 22
   nc -vz -w 5 <vps_host> 443
   ```

   `22/tcp open` plus `Connection timed out during banner exchange` means TCP reaches something, but SSH did not finish pre-auth banner exchange.

3. Check whether your current egress IP is allowed by VPS firewall / provider rules. This matters when switching to a third-party VPN, mobile hotspot, office network, or a new home ISP IP.

4. If the bastion is reachable, use the break-glass path below and inspect `sshd`, disk, memory, failed units, and recent SSH logs.

5. If neither direct nor bastion access works, use the cloud provider's web console / rescue mode.

## VPN and firewall requirement

The VPS SSH port is intentionally allowlisted. When you use a third-party VPN or another new client network, the VPS may see a new source IP. Before relying on that path, add the new source IP to the VPS SSH allowlist and any provider firewall allowlist, then verify:

```bash
./ansible/scripts/ssh-vps.sh 'echo OK'
```

Do not weaken SSH to `Anywhere` for convenience. Keep a second working route (bastion, provider console) before editing firewall rules.

## Required local environment

Set these only in your local shell or a gitignored local env file:

```bash
export VPS_BASTION_HOST="<bastion_host>"
export VPS_BASTION_USER="<bastion_ssh_user>"
# optional:
export VPS_BASTION_PORT="22"
```

Never commit a real bastion host, user, or key material.

`VPS_BASTION_HOST` can be a LAN address when you are on the trusted LAN, or a remote SSH endpoint managed outside this repo. The bastion must be an operator-controlled host with SSH and forwarding support.

## Quick checks

Check the bastion first:

```bash
ssh -o BatchMode=yes -o ConnectTimeout=8 \
  "${VPS_BASTION_USER}@${VPS_BASTION_HOST}" 'echo BASTION_OK'
```

Then check both direct and bastion access:

```bash
./ansible/scripts/check-ssh-access.sh
```

Or check the VPS through the bastion:

```bash
./ansible/scripts/ssh-vps-via-bastion.sh 'echo OK; uptime; df -h /; free -h'
```

Interactive shell:

```bash
./ansible/scripts/ssh-vps-via-bastion.sh
```

Equivalent raw SSH form:

```bash
ssh \
  -o ControlMaster=no \
  -o ControlPath=none \
  -o BatchMode=yes \
  -o "ProxyCommand=ssh ${VPS_BASTION_USER}@${VPS_BASTION_HOST} -W %h:%p" \
  deploy@<vps_host>
```

Prefer `ssh -W %h:%p` over `nc` in `ProxyCommand`. In practice, a bastion `nc` relay can close the stream after the first short command; `ssh -W` keeps a stable SSH transport.

## Recovery checks after login

Once in, collect host-side state before mutating anything:

```bash
df -h /
free -h
uptime
sudo systemctl status ssh --no-pager --lines=40
sudo journalctl -u ssh -n 120 --no-pager
sudo systemctl --failed --no-pager
```

If `sshd` is alive but direct SSH still hangs before banner, check firewall / provider rules and recent host load. If `sshd` itself is wedged, restart only SSH first:

```bash
sudo sshd -t && sudo systemctl restart ssh
```

Then re-test the direct path:

```bash
./ansible/scripts/ssh-vps.sh 'echo OK'
```

If direct SSH recovers, run the normal health gate:

```bash
./verify.sh
./modules/disk-observatory/bin/disk-report --no-save
```
