---
name: secure-ssh-server
description: Harden SSH access on Debian or Ubuntu VPS and dedicated servers after initial setup. Use when Codex or Claude is asked to protect SSH, disable password or root login, create or install ED25519 keys, change the SSH port, restrict AllowUsers, configure UFW, iptables, nftables, fail2ban, port knocking with knockd, verify SSH access, or prepare rollback from SSH lockout.
---

# Secure SSH Server

## Core Rule

Never risk locking out the server. Keep the current SSH session open, confirm provider console or snapshot access, and verify a new key-based login in a second session before disabling password login, root login, port 22, or any firewall path.

Use the user's language. For live server work, audit first and change only after the access path is understood.

Ask for missing high-risk inputs before writing commands that modify SSH or firewall state:

- server OS/version and whether it is Debian or Ubuntu
- SSH host, current user, current port, desired SSH port
- admin users allowed to log in, for example `www` or `deploy`
- public SSH key to install, or permission to help generate/find one
- provider firewall/security group state
- whether there is rescue console, snapshot, or an existing root session
- whether the server is fresh, shared, or already managed by another firewall policy

## Workflow

1. Audit the current access path.
   - Read `references/ubuntu-debian-ssh-hardening.md` for command patterns.
   - Inspect OS, current sshd configuration, included config directories, listening ports, users, firewall, fail2ban, provider firewall notes, and existing knockd/nftables/iptables state.
   - Distinguish an open TCP port from a healthy SSH service. If SSH banner exchange hangs, investigate service or host health before changing firewall rules.

2. Establish key-based non-root access.
   - Prefer ED25519 keys.
   - Install the public key for the intended admin/deploy user.
   - Verify `ssh -p <port> -o PasswordAuthentication=no <user>@<host>` works before changing login policy.
   - Restrict `AllowUsers` only to real human or deploy login users. Do not accidentally block automation, backups, or CI users that still need SSH.

3. Harden sshd with a staged config.
   - Prefer a drop-in such as `/etc/ssh/sshd_config.d/99-hardening.conf` when supported.
   - Validate with `sshd -t` before reload.
   - Prefer `systemctl reload ssh` over restart. Restart only when reload is unavailable or insufficient.
   - Disable root and password login only after key login succeeds.
   - Change the SSH port only after the new port is allowed in the host firewall and provider firewall.

4. Choose a firewall model.
   - For normal VPS hardening, prefer UFW: default deny inbound, allow the active SSH port, HTTP/HTTPS when needed, and only explicit app ports.
   - For port knocking, avoid mixing opaque UFW rules with manual iptables unless the existing host already does so intentionally. Audit first and document the rule order.
   - If using knockd, treat it as an advanced layer: configure knockd, keep established sessions allowed, temporarily allow rescue access while testing, then reject the SSH port until the knock opens a short-lived rule.

5. Add brute-force protection.
   - Install and configure fail2ban for the actual SSH port unless another managed protection exists.
   - Verify bans/logging after changing ports.

6. Verify from outside.
   - Test a new key-only login on the final port.
   - Confirm root login fails.
   - Confirm password login fails.
   - Confirm the old SSH port is closed only after the final path works.
   - If knockd is enabled, confirm the knock opens access and that access closes after `cmd_timeout`.

7. Hand off recovery details.
   - Report changed files, final SSH command, allowed users, final port, firewall model, knock sequence if used, fail2ban jail, and exact rollback commands.
   - Do not reveal private keys. Do not print secrets.

## Port Knocking Guidance

Use port knocking only when the user explicitly asks for it or accepts the operational tradeoff. It reduces unsolicited SSH exposure, but it can break access for teams, CI, uptime monitors, or users behind restrictive networks.

When configuring knockd:

- detect the active network interface instead of hardcoding `enp3s0`
- use a user-specific knock sequence, not a public example sequence, when possible
- keep `cmd_timeout` short, commonly 30-120 seconds
- persist firewall rules and document how to recover through provider console
- test with `journalctl -u knockd` and an external knock client

## Output Shape

For planning-only requests, return:

- assumptions and missing inputs
- access safety checklist
- staged hardening plan
- command blocks grouped by stage
- verification checklist
- rollback path

For hands-on server work, update the user before each risky phase and summarize every server-side change immediately after it is made.

## References

- Use `references/ubuntu-debian-ssh-hardening.md` for Debian/Ubuntu commands, config snippets, knockd setup, firewall patterns, verification, and rollback.
