# Runbook: SSH break-glass via router bastion

Use this path when direct VPS SSH accepts TCP but does not return an SSH banner:

```text
Connection timed out during banner exchange
```

This is a backup route to the same VPS `sshd`, reached through an operator-controlled router bastion. It does not bypass host SSH policy, keys, or `AllowUsers`; it only changes the network path.

## When to use

- Direct `./ansible/scripts/ssh-vps.sh 'true'` fails before authentication.
- `nc -vz <vps_host> 22` succeeds, but SSH never receives the remote banner.
- The router bastion is reachable from the current operator network.

Do not use this for normal maintenance. Prefer the direct vault-backed SSH path.

## Recovery ladder

Use the smallest working step; avoid opening many parallel SSH attempts while
debugging, because that can make banner/`MaxStartups` symptoms worse.

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
   `22/tcp open` plus `Connection timed out during banner exchange` means TCP
   reaches something, but SSH did not finish pre-auth banner exchange.
3. Check whether your current egress IP is allowed by VPS firewall/provider
   rules. This matters when switching to a third-party VPN, mobile hotspot,
   office network, or a new home ISP IP.
4. If the router bastion is reachable, use the break-glass path below and check
   `sshd`, disk, memory, failed units, and recent SSH logs.
5. If neither direct nor bastion access works, use Hetzner Console/rescue.

## VPN and firewall requirement

The VPS SSH port is intentionally allowlisted. When you use a third-party VPN or
another new client network, the VPS may see a new source IP. Before relying on
that path, add the new source IP to the VPS SSH allowlist and any provider
firewall allowlist, then verify:

```bash
./ansible/scripts/ssh-vps.sh 'echo OK'
```

Do not weaken SSH to `Anywhere` for convenience. Keep a second working route
(router bastion or Hetzner Console) before editing firewall rules.

## Required local environment

Set these only in your local shell or a gitignored local env file:

```bash
export VPS_BASTION_HOST="<router_lan_or_remote_host>"
export VPS_BASTION_USER="<router_ssh_user>"
# optional:
export VPS_BASTION_PORT="22"
```

Never commit real router host/IP, router SSH user, or bastion key material.

`VPS_BASTION_HOST` can be a LAN router address when you are on the trusted LAN,
or a router remote SSH endpoint managed outside this repo. The bastion must be an
operator-controlled router with SSH access and forwarding support.

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

Or check the VPS through the bastion directly:

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

Prefer `ssh -W %h:%p` over `nc` in `ProxyCommand`. In practice the router `nc`
relay can close the stream after the first short command, while `ssh -W` keeps a
stable SSH transport.

## Recovery checks after login

Once in, collect the host-side state before mutating anything:

```bash
df -h /
free -h
uptime
sudo systemctl status ssh --no-pager --lines=40
sudo journalctl -u ssh -n 120 --no-pager
sudo systemctl --failed --no-pager
```

If `sshd` is alive but direct SSH still hangs before banner, check firewall/provider rules and recent host load. If `sshd` itself is wedged, restart only SSH first:

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
