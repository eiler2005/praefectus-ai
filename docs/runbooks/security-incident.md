# Runbook: security incident

What to do when you suspect VPS compromise.

---

## Symptoms

- Unknown processes in `ps aux` or new containers in `docker ps`.
- New open ports (`./modules/port-audit/bin/port-audit`).
- Unfamiliar lines in `~/.ssh/authorized_keys`.
- Anomalous outbound traffic (high load with no clear cause).
- Repeated `sudo: N incorrect password attempts` in `/var/log/auth.log`.
- OOM kills with no traffic spike.
- Modifications to `/etc/crontab`, `/etc/cron.d/`, `~/.bashrc`, `~/.profile`.

---

## Step 1 — initial assessment (without losing SSH)

```bash
# Anomalous processes
ssh deploy@<vps> 'ps aux --sort=-%cpu | head -20'
ssh deploy@<vps> 'ps aux --sort=-%mem | head -20'

# Unexpected outbound connections
ssh deploy@<vps> 'ss -tnp | grep ESTABLISHED'

# Logged-in users
ssh deploy@<vps> 'who; last | head -20'

# Newly modified files in last 24h (excluding /proc, /sys, /dev)
ssh deploy@<vps> 'find /usr /etc /tmp /var/tmp -newer /etc/passwd -type f 2>/dev/null | head -30'

# Cron entries
ssh deploy@<vps> 'cat /etc/crontab; ls /etc/cron.d/; crontab -l 2>/dev/null'

# authorized_keys
ssh deploy@<vps> 'cat ~/.ssh/authorized_keys'

# OOM events in last 24h
ssh deploy@<vps> 'dmesg --since "24h ago" | grep -i oom | tail -20'
```

---

## Step 2 — immediate actions (when confirmed)

### Isolate (only if you have a working rescue path)

```bash
# DO NOT run this without a rescue path — you may lose SSH.
# Block all outbound traffic except to your IP:
ssh deploy@<vps> 'sudo ufw default deny outgoing && sudo ufw allow out to <your_ip>'
```

### Rotate SSH keys

```bash
# On the control machine: generate a new key
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_vps_new -C "vps-recovery-$(date +%Y%m%d)"

# Open the cloud provider's web console (e.g. Hetzner Cloud Console / AWS EC2 Console / DigitalOcean web terminal)
cat ~/.ssh/id_ed25519_vps_new.pub  # paste into authorized_keys via the console

# Remove the compromised key from authorized_keys
```

### Stop suspect processes

```bash
ssh deploy@<vps> 'ps aux | grep <suspect>'
ssh deploy@<vps> 'sudo kill -9 <pid>'
```

---

## Step 3 — forensics (after stabilisation)

```bash
# Command history
ssh deploy@<vps> 'cat ~/.bash_history | tail -100'

# Recent changes in /etc
ssh deploy@<vps> 'find /etc -newer /etc/passwd -type f 2>/dev/null'

# fail2ban (who tried to brute-force?)
ssh deploy@<vps> 'sudo fail2ban-client status sshd'
ssh deploy@<vps> 'sudo grep "Ban" /var/log/fail2ban.log | tail -30'

# auth log
ssh deploy@<vps> 'sudo grep -E "(Failed|Accepted|Invalid)" /var/log/auth.log | tail -50'
```

---

## Step 4 — recovery

1. **Snapshot** — take a snapshot in the cloud provider's console BEFORE any changes (forensic copy).
2. **Identify the vector** — how did they get in? Weak key? Application vulnerability?
3. **Close the vector.**
4. **Audit every service** — verify configs, data, and credentials are intact.
5. **Rotate every secret**: vault.yml entries, Telegram tokens, API keys, restic password (last one: backups become unreadable — only do if vault is compromised).
6. **Recreate `authorized_keys`** with clean keys only.
7. **Run a full verify**: `./verify.sh`.
8. **Document** in `docs/journal/YYYY-MM.md`.

---

## Contacts / escalation

- Cloud provider support — request IP-level blocking if needed (e.g. Hetzner Support, AWS abuse team, DigitalOcean support).
- Cloud provider web console — rescue access without SSH.

---

## Preventive measures already applied

- `fail2ban`: sshd jail — 3 attempts / 600 s → 24 h ban (`40-security.yml`).
- UFW: only required ports open.
- `PasswordAuthentication`: must be `no` (verify: `grep PasswordAuthentication /etc/ssh/sshd_config`).
- Key-only SSH.
- `unattended-upgrades`: security patches applied automatically.
