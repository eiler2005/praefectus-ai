# Runbook: SSH MaxSessions limit

## Symptom

SSH port is open (`nc -z <vps_ip> 22` succeeds), ping works, but:

```
Connection timed out during banner exchange
```

## Cause

`MaxSessions` in `/etc/ssh/sshd_config.d/99-hardening.conf` is set too low (e.g. `2`). When parallel or unclosed SSH attempts (Ansible + interactive SSH + background commands) exceed the cap, the `MaxStartups` queue fills and `sshd` stops accepting new connections.

## Immediate workaround

Wait for slots to free (old sessions close in 30–60 s):

```bash
until ssh -o ControlMaster=no -o ConnectTimeout=10 deploy@<vps_ip> 'echo ok' 2>/dev/null; do
  sleep 15
done
```

## Permanent fix

Raise `MaxSessions` from 2 to 6 (enough for Ansible + interactive SSH + monitoring):

```bash
# Check current value
ssh deploy@<vps> 'sudo grep -r MaxSessions /etc/ssh/'

# Change it
ssh deploy@<vps> 'sudo sed -i "s/MaxSessions 2/MaxSessions 6/" /etc/ssh/sshd_config.d/99-hardening.conf && sudo sshd -t && sudo systemctl reload sshd'
```

Or via the `40-security.yml` playbook (which already enforces this).

## SSH discipline rules for this VPS

1. Never run background SSH (`run_in_background=true`) — those connections do not close cleanly.
2. Ansible: always `ControlMaster=no` in `ansible.cfg` (already configured).
3. Minimise SSH session count — combine commands into a single session.
4. When Ansible hangs, wait 60 s before retrying — back-to-back retries make `MaxStartups` worse.
