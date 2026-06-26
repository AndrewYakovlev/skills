---
name: setup-web-server
description: Prepare, harden, audit, and deploy new Debian or Ubuntu web servers for production projects. Use when Codex or Claude is asked to bootstrap a VPS or dedicated server, write server setup commands, configure SSH users, firewalls, nginx, TLS, Docker, Python, Django, FastAPI, Node.js, Go, Postgres, MySQL or MariaDB, MongoDB, Redis, backups, monitoring, systemd services, or deployment runbooks.
---

# Setup Web Server

## Core Rule

Do not assume the stack. If the user has not already specified the target components, ask one compact multiple-choice question before planning or changing a server.

Use the user's language. Present the choices as a multi-select checklist and allow extra free-form components.

Suggested stack question:

```text
What should this server support? Select all that apply:
Base hardening, deploy user, SSH keys, firewall, fail2ban, nginx, TLS/certbot,
Docker/Compose, Python, Django, FastAPI, Node.js, Go, Postgres,
MySQL/MariaDB, MongoDB, Redis, queues/workers, backups, monitoring, CI deploy.

Also share: OS/version, domain names, repository URL, SSH user/host, and whether
this is a fresh server or a shared server with existing projects.
```

If the user asks for hands-on execution and gives SSH access, audit first and only then change the host.

## Workflow

1. Gather scope.
   - Confirm OS family and version. Prefer Debian or Ubuntu.
   - Confirm whether the server is fresh or shared.
   - Confirm selected stack components, domains, app name, deployment style, and expected traffic.
   - Ask for missing high-risk inputs before making live changes: SSH host/user, domain, repository, database ownership, backup destination, and whether existing sites may be touched.

2. Audit before edits.
   - On any non-fresh or shared server, run read-only diagnostics first: OS, users, ports, nginx sites, systemd units, Docker containers, database services, disk, memory, firewall, and existing certbot state.
   - Preserve existing projects by isolating directory, port, Unix user, database names, nginx vhost, systemd unit, and Docker network.

3. Build the plan.
   - Produce a staged plan with checkpoints and rollback notes.
   - Separate base hardening from stack-specific installation.
   - Prefer idempotent commands and explicit paths.
   - Never disable root/password SSH, restart shared services, replace nginx configs, remove packages, drop databases, or rotate firewall rules without a verified fallback path.

4. Apply base setup.
   - Patch packages, set timezone, configure hostname, add a deploy user, install core utilities, configure SSH, firewall, fail2ban, unattended upgrades, swap if needed, and log retention.
   - Keep SSH open while testing a new login in a second session.

5. Apply selected stack profiles.
   - Read `references/stack-profiles.md` for component-specific decisions and expected outputs.
   - Read `references/debian-ubuntu-playbook.md` for command patterns and verification checks.
   - Verify current vendor installation instructions before using external apt repositories for Docker, NodeSource, MongoDB, PostgreSQL PGDG, Go, or language runtimes.

6. Configure deployment.
   - Prefer `/var/www/<project>/current` for app code and `/var/www/<project>/shared` for uploads, env files, logs, and persistent state.
   - Bind app processes to `127.0.0.1:<port>` or a Unix socket behind nginx.
   - Use systemd for non-container services. Use Docker Compose when Docker is selected or when the stack has multiple coupled services.
   - Keep secrets in `.env` or systemd environment files outside git.

7. Verify and hand off.
   - Run service-level checks: `systemctl status`, `journalctl`, `nginx -t`, `ss -tulpn`, local `curl`, public `curl`, database connection test, and TLS renewal dry run when certbot is configured.
   - Return a short status summary, exact files changed on the server, open ports, credentials or secret locations without revealing secret values, and next operational commands.

## Output Shape

For planning-only requests, return:

- Assumptions and missing inputs
- Selected stack profile
- Staged implementation plan
- Command blocks grouped by stage
- Verification checklist
- Rollback or recovery notes

For hands-on server work, keep the user updated before each risky phase and summarize every server-side change after it is made.

## References

- Use `references/stack-profiles.md` when deciding what to install for each selected technology.
- Use `references/debian-ubuntu-playbook.md` when writing or executing Debian/Ubuntu commands.
