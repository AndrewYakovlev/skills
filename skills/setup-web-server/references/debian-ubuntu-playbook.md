# Debian and Ubuntu Playbook

Use these as command patterns. Confirm package names and vendor repository instructions against the target OS version before execution.

## Read-Only Audit

Run before modifying a live or shared server:

```bash
whoami
hostnamectl
lsb_release -a || cat /etc/os-release
uname -a
ip -br addr
df -h
free -h
uptime
ss -tulpn
systemctl --failed
systemctl list-units --type=service --state=running
nginx -T 2>/dev/null | sed -n '1,220p'
ls -la /etc/nginx/sites-enabled /etc/nginx/sites-available 2>/dev/null
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Ports}}' 2>/dev/null
ufw status verbose 2>/dev/null || true
```

## Base Packages

```bash
sudo apt update
sudo apt upgrade -y
sudo apt install -y ca-certificates curl wget git unzip htop nano vim jq lsb-release gnupg ufw fail2ban unattended-upgrades logrotate
```

Add build tools only when needed:

```bash
sudo apt install -y build-essential pkg-config
```

## Deploy User

Use a project-specific deploy user on shared hosts when isolation matters.
Ask for the public SSH key to install, or help the user generate or locate one before running these commands.

```bash
sudo adduser deploy
sudo usermod -aG sudo deploy
sudo install -d -m 700 -o deploy -g deploy /home/deploy/.ssh
sudo install -m 600 -o deploy -g deploy /tmp/authorized_keys /home/deploy/.ssh/authorized_keys
```

To append one public key without replacing existing keys:

```bash
printf '%s\n' '<public-ssh-key>' | sudo tee -a /home/deploy/.ssh/authorized_keys >/dev/null
sudo chown deploy:deploy /home/deploy/.ssh/authorized_keys
sudo chmod 600 /home/deploy/.ssh/authorized_keys
sudo chmod 700 /home/deploy/.ssh
```

Verify key-based login in a second session before changing SSH policy:

```bash
ssh deploy@<server-host>
```

## SSH Hardening

Create a drop-in file instead of editing the main config where supported:

```bash
sudo install -d /etc/ssh/sshd_config.d
sudo tee /etc/ssh/sshd_config.d/99-hardening.conf >/dev/null <<'EOF'
PasswordAuthentication no
PermitRootLogin prohibit-password
PubkeyAuthentication yes
EOF
sudo sshd -t
sudo systemctl reload ssh
```

Do not disable root or password login until a new key-based session works.

## Baseline Security

Apply these controls for normal production servers unless the host is already managed by another security policy:

```bash
sudo timedatectl set-timezone UTC
sudo dpkg-reconfigure -f noninteractive unattended-upgrades
sudo systemctl enable --now fail2ban
sudo systemctl enable --now unattended-upgrades
sudo systemctl status fail2ban --no-pager
```

Use the user's timezone when they provide one. On shared hosts, audit existing policies before changing global settings.

## Firewall

Keep the active SSH port open.

```bash
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
sudo ufw status verbose
```

If SSH uses a custom port, allow it before enabling UFW:

```bash
sudo ufw allow <ssh-port>/tcp
```

On shared hosts, inspect existing rules first and add only the project-specific ports that are required.

## Nginx Site Pattern

```nginx
server {
    listen 80;
    server_name example.com www.example.com;

    location /.well-known/acme-challenge/ {
        root /var/www/_letsencrypt;
    }

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Verify before reload:

```bash
sudo nginx -t
sudo systemctl reload nginx
```

## Certbot Webroot Pattern

Useful on shared servers because it avoids rewriting unrelated vhosts.

```bash
sudo apt install -y certbot python3-certbot-nginx
sudo install -d -m 755 /var/www/_letsencrypt
sudo certbot certonly --webroot -w /var/www/_letsencrypt -d example.com -d www.example.com
sudo certbot renew --dry-run
```

## Systemd App Service Pattern

```ini
[Unit]
Description=Example web app
After=network.target

[Service]
User=deploy
Group=deploy
WorkingDirectory=/var/www/example/current
EnvironmentFile=/var/www/example/shared/.env
ExecStart=/var/www/example/shared/venv/bin/gunicorn app.wsgi:application --bind 127.0.0.1:8000
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Apply and verify:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now example.service
sudo systemctl status example.service --no-pager
journalctl -u example.service -n 100 --no-pager
curl -I http://127.0.0.1:8000
```

## Project Layout

```text
/var/www/<project>/
  current/        # checked out code or active release
  shared/
    .env
    logs/
    media/
    static/
    backups/
```

Set ownership narrowly:

```bash
sudo mkdir -p /var/www/<project>/{current,shared/logs,shared/media,shared/static,shared/backups}
sudo chown -R deploy:deploy /var/www/<project>
```

## Verification Checklist

- new SSH login works
- firewall allows only expected ports
- app binds to loopback or private interface
- nginx config validates
- local health check passes
- public HTTP/HTTPS check passes
- TLS renewal dry run passes
- database connection works from the app user
- backup command runs and restore path is documented
- no failed systemd units remain
