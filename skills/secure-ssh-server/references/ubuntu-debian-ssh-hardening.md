# Ubuntu and Debian SSH Hardening Playbook

Use these as command patterns. Adjust users, ports, interface names, domains, provider firewall rules, and existing host policies before execution.

## Read-Only Audit

Run before modifying a live server:

```bash
whoami
hostnamectl
cat /etc/os-release
ip -br addr
ip -o -4 route show to default
ss -tulpn | grep -E ':(22|[0-9]+).*sshd|ssh'
sudo systemctl status ssh --no-pager
sudo sshd -T | grep -Ei '^(port|permitrootlogin|passwordauthentication|kbdinteractiveauthentication|pubkeyauthentication|allowusers|include) '
sudo ls -la /etc/ssh /etc/ssh/sshd_config.d 2>/dev/null
sudo ufw status verbose 2>/dev/null || true
sudo iptables -S 2>/dev/null || true
sudo nft list ruleset 2>/dev/null | sed -n '1,180p' || true
systemctl status fail2ban --no-pager 2>/dev/null || true
systemctl status knockd --no-pager 2>/dev/null || true
```

Detect the default interface:

```bash
ip -o -4 route show to default | awk '{print $5; exit}'
```

## Local Key Generation

Prefer ED25519:

```bash
ssh-keygen -t ed25519 -a 100 -C "admin@server-$(date +%Y%m%d)"
```

Copy the public key from the local machine:

```bash
# macOS
pbcopy < ~/.ssh/id_ed25519.pub

# Linux with wl-clipboard
wl-copy < ~/.ssh/id_ed25519.pub

# Linux with xclip
xclip -selection clipboard < ~/.ssh/id_ed25519.pub

# Windows PowerShell
Get-Content $env:USERPROFILE\.ssh\id_ed25519.pub | Set-Clipboard

# Portable fallback
cat ~/.ssh/id_ed25519.pub
```

Never copy or paste the private key.

## Install Public Key on the Server

Replace `www` with the real login user:

```bash
sudo id www
home_dir="$(getent passwd www | cut -d: -f6)"
sudo install -d -m 700 -o www -g www "${home_dir}/.ssh"
printf '%s\n' '<public-ssh-key>' | sudo tee -a "${home_dir}/.ssh/authorized_keys" >/dev/null
sudo chown www:www "${home_dir}/.ssh/authorized_keys"
sudo chmod 600 "${home_dir}/.ssh/authorized_keys"
sudo chmod 700 "${home_dir}/.ssh"
```

Avoid duplicate key lines when idempotence matters:

```bash
key='<public-ssh-key>'
home_dir="$(getent passwd www | cut -d: -f6)"
sudo grep -qxF "$key" "${home_dir}/.ssh/authorized_keys" || printf '%s\n' "$key" | sudo tee -a "${home_dir}/.ssh/authorized_keys" >/dev/null
```

Verify key-only login from a second terminal:

```bash
ssh -p 22 -o PasswordAuthentication=no www@<server-host>
```

## Harden sshd

On Debian/Ubuntu the service is normally named `ssh`, not `sshd`.

Back up the main config:

```bash
sudo cp -a /etc/ssh/sshd_config "/etc/ssh/sshd_config.bak.$(date +%Y%m%d%H%M%S)"
```

Prefer a drop-in file:

```bash
sudo install -d /etc/ssh/sshd_config.d
grep -E '^[[:space:]]*Include[[:space:]]+/etc/ssh/sshd_config.d/\*.conf' /etc/ssh/sshd_config
sudo tee /etc/ssh/sshd_config.d/99-hardening.conf >/dev/null <<'EOF'
Port 45916
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
AllowUsers www
MaxAuthTries 3
LoginGraceTime 30
X11Forwarding no
EOF
sudo sshd -t
sudo systemctl reload ssh
```

If the main config does not include `/etc/ssh/sshd_config.d/*.conf`, add the `Include` line carefully or edit `/etc/ssh/sshd_config` directly with a timestamped backup.

Only add stricter options such as `AllowTcpForwarding no` when SSH tunnels are not required by deploy workflows, backups, or diagnostics.

Verify effective settings:

```bash
sudo sshd -T | grep -Ei '^(port|permitrootlogin|passwordauthentication|kbdinteractiveauthentication|pubkeyauthentication|allowusers|maxauthtries|logingracetime|x11forwarding) '
ss -tulpn | grep ssh
```

Test the final port from a second terminal before closing the first session:

```bash
ssh -p 45916 -o PasswordAuthentication=no www@<server-host>
```

## UFW Firewall Pattern

Use this for ordinary VPS SSH hardening without port knocking. Update provider firewall rules before enabling or changing host firewall rules.

If changing the SSH port, allow the new port before reloading sshd with the new `Port` value.

```bash
sudo apt update
sudo apt install -y ufw
sudo ufw allow 45916/tcp comment 'SSH'
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw enable
sudo ufw status verbose
```

Remove port 22 only after the new port works:

```bash
sudo ufw status numbered
# Delete the exact old SSH rule by number, or remove the default rule when present:
sudo ufw delete allow OpenSSH
sudo ufw delete allow 22/tcp
```

## fail2ban Pattern

```bash
sudo apt update
sudo apt install -y fail2ban
sudo tee /etc/fail2ban/jail.d/sshd.local >/dev/null <<'EOF'
[sshd]
enabled = true
port = 45916
filter = sshd
logpath = %(sshd_log)s
maxretry = 5
findtime = 10m
bantime = 1h
EOF
sudo systemctl enable --now fail2ban
sudo systemctl restart fail2ban
sudo fail2ban-client status sshd
```

## Port Knocking with knockd and iptables

Use this only after key-based SSH on the final port works. Keep provider console or another recovery path available.
If a cloud/provider firewall is enabled, it must allow the knock ports to reach the host, otherwise knockd cannot observe the sequence.

Install packages:

```bash
sudo apt update
sudo apt install -y knockd iptables-persistent netfilter-persistent
```

Detect interface:

```bash
iface="$(ip -o -4 route show to default | awk '{print $5; exit}')"
echo "$iface"
```

Configure knockd. Replace `7000,8000,9000` with a user-specific sequence when possible:

```bash
sudo tee /etc/knockd.conf >/dev/null <<EOF
[options]
 UseSyslog
 Interface = ${iface}

[SSH]
 sequence    = 7000,8000,9000
 seq_timeout = 5
 tcpflags    = syn
 start_command = /sbin/iptables -I INPUT 1 -s %IP% -p tcp --dport 45916 -m conntrack --ctstate NEW -j ACCEPT
 stop_command  = /sbin/iptables -D INPUT -s %IP% -p tcp --dport 45916 -m conntrack --ctstate NEW -j ACCEPT
 cmd_timeout   = 60
EOF
```

Enable knockd startup:

```bash
sudo tee /etc/default/knockd >/dev/null <<EOF
START_KNOCKD=1
KNOCKD_OPTS="-i ${iface}"
EOF
sudo systemctl enable --now knockd
sudo systemctl status knockd --no-pager
```

Add the SSH deny rule after established traffic is accepted. Preserve other required rules such as HTTP/HTTPS.

```bash
sudo iptables -C INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || sudo iptables -I INPUT 1 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
sudo iptables -C INPUT -i lo -j ACCEPT 2>/dev/null || sudo iptables -I INPUT 1 -i lo -j ACCEPT
sudo iptables -C INPUT -p tcp --dport 45916 -j REJECT 2>/dev/null || sudo iptables -A INPUT -p tcp --dport 45916 -j REJECT
sudo netfilter-persistent save
sudo iptables -L --line-numbers -n -v
```

Knock from the client:

```bash
for port in 7000 8000 9000; do
  nmap -Pn --max-retries 0 -p "$port" <server-ip-or-host>
done
ssh -p 45916 www@<server-ip-or-host>
```

Alternative client if `knock` is available:

```bash
knock <server-ip-or-host> 7000 8000 9000
ssh -p 45916 www@<server-ip-or-host>
```

Watch logs while testing:

```bash
sudo journalctl -u knockd -f
```

Alternative client if only netcat is available:

```bash
for port in 7000 8000 9000; do
  nc -z -w1 <server-ip-or-host> "$port" || true
done
ssh -p 45916 www@<server-ip-or-host>
```

## nftables Note

On newer Debian/Ubuntu systems, `iptables` may be backed by nftables. That is normal. If the host already uses a native nftables ruleset, do not add parallel iptables rules blindly. Audit `nft list ruleset`, choose one firewall model, and document the final rule order.

## Optional Ping Policy

Do not block ICMP by default; it is useful for diagnostics. If the user explicitly wants to hide ping:

```bash
sudo iptables -A INPUT -p icmp --icmp-type echo-request -j DROP
sudo netfilter-persistent save
```

Remove that rule:

```bash
sudo iptables -D INPUT -p icmp --icmp-type echo-request -j DROP
sudo netfilter-persistent save
```

## Rollback and Recovery

Open SSH immediately:

```bash
sudo iptables -I INPUT 1 -p tcp --dport 45916 -j ACCEPT
sudo netfilter-persistent save
```

Remove the hardening drop-in and reload ssh:

```bash
sudo rm -f /etc/ssh/sshd_config.d/99-hardening.conf
sudo sshd -t
sudo systemctl reload ssh
```

Stop knockd:

```bash
sudo systemctl disable --now knockd
```

Emergency firewall flush only when you have console access and understand the impact:

```bash
sudo iptables -F
sudo netfilter-persistent save
```

## Verification Checklist

- current SSH session stayed open through the change
- provider firewall allows the final SSH port
- key-only login works for each allowed user
- root SSH login fails
- password SSH login fails
- old SSH port is closed only after final access works
- UFW or iptables rules show only expected inbound ports
- fail2ban watches the actual SSH port
- knockd opens SSH only after the sequence and closes after timeout
- rollback commands and changed files are documented
