# Stack Profiles

Use this file after the user selects target components. Combine profiles; do not force a one-size-fits-all stack.

## Base Hardening

Include by default unless the user says the host is already managed:

- OS update and reboot window
- non-root deploy user with sudo as needed
- SSH keys, optional custom SSH port, password login policy
- firewall allowing SSH, HTTP, HTTPS, and only explicitly required app ports
- fail2ban or equivalent SSH brute-force protection
- unattended security upgrades
- hostname, timezone, locale, NTP
- swap on small VPS instances
- log rotation and disk usage checks

Avoid locking yourself out. Keep the current SSH session open and verify a new login before tightening SSH.

## Nginx and TLS

Use when selected, or when an app needs public HTTP traffic.

- Create one vhost per project or domain.
- Keep app services on loopback ports or Unix sockets.
- Use `nginx -t` before reloads.
- Prefer certbot webroot or nginx plugin depending on existing server state.
- For shared servers, prefer webroot challenges to avoid certbot rewriting unrelated vhosts.
- Add security headers only after confirming the app does not need exceptions.

Expected handoff:

- domain to vhost mapping
- app upstream port or socket
- certificate path and renewal status
- nginx config path

## Docker and Compose

Use when selected or when the project has multiple service dependencies.

- Prefer Docker's official repository on fresh hosts after verifying current vendor commands.
- Add only the deploy user to the docker group if interactive Docker access is needed.
- Use `docker compose` plugin, not legacy `docker-compose`, unless the host already standardizes on it.
- Store compose projects under `/var/www/<project>/current` or `/opt/<project>`.
- Store persistent volumes under named volumes or `/var/www/<project>/shared`.
- Put reverse proxy on nginx unless Traefik/Caddy is explicitly selected.

Expected handoff:

- compose file path
- project name
- persistent volumes
- exposed host ports
- restart policy

## Python

Use for generic Python services, Django, FastAPI, Celery, or management scripts.

- Install Python runtime, `python3-venv`, build tools, headers, and package-specific system dependencies.
- Prefer a per-project virtualenv in `/var/www/<project>/shared/venv` or inside the release directory if releases are immutable.
- Use `pip` constraints or lockfiles when present.
- Run services with systemd unless Docker is selected.
- Keep environment variables outside git.

## Django

Layer on top of Python.

- Configure Postgres by default unless the user selected another database.
- Install app dependencies, run migrations, collect static files, create media/static directories, and configure permissions.
- Serve Django through gunicorn or uvicorn workers behind nginx.
- Keep `DEBUG=False`, `ALLOWED_HOSTS`, `CSRF_TRUSTED_ORIGINS`, and static/media paths explicit.
- Add a separate worker service for Celery/RQ if queues/workers are selected.

Expected verification:

- `manage.py check --deploy`
- migrations status
- static files exist and nginx can read them
- app health endpoint or admin page responds locally and publicly

## FastAPI

Layer on top of Python.

- Prefer uvicorn or gunicorn with uvicorn workers behind nginx.
- Expose only loopback app ports.
- Configure systemd with working directory, venv path, environment file, restart policy, and journal logging.
- Add process count based on CPU and workload, not blindly.

Expected verification:

- OpenAPI or health endpoint responds on loopback
- nginx proxy returns the same health response publicly
- logs are visible in journald

## Node.js

Use when selected for SSR apps, APIs, build pipelines, or static frontend builds.

- Choose runtime source: distro package, NodeSource, nvm, pnpm via corepack, or Docker. Verify current upstream commands before external repositories.
- Respect project lockfile: npm, pnpm, yarn, or bun.
- For Next.js or SSR apps, run behind systemd or Docker and proxy through nginx.
- For static builds, build once and serve generated files from nginx.

Expected verification:

- package manager install completed from lockfile
- build/test command result
- app listens on loopback or static directory exists
- nginx route responds

## Go

Use when selected for Go APIs or services.

- Prefer distro Go only when version is sufficient. Otherwise verify current official Go install instructions.
- Build a static or self-contained binary where practical.
- Run with systemd behind nginx if public HTTP is needed.
- Store config in environment files, not compiled constants.

Expected verification:

- `go test ./...` when feasible
- binary version or health endpoint
- systemd restart and journald logs

## Postgres

Use when selected or as default for Django/FastAPI production apps unless the user chooses another DB.

- Install distro Postgres or PGDG when a specific version is required.
- Create a project-specific database and role.
- Use local socket auth or loopback TCP; do not expose Postgres publicly unless explicitly required and firewalled.
- Configure backups before launch.
- Tune only after measuring memory, CPU, storage, and connection count.

Expected handoff:

- database name
- role name
- backup command and destination
- connection string location without secret value

## MySQL or MariaDB

Use when selected or required by the project.

- Choose MySQL or MariaDB explicitly; do not conflate them.
- Run secure installation steps appropriate to the package.
- Create project-specific database and user.
- Bind to localhost unless external access is required and firewalled.
- Configure backups before launch.

## MongoDB

Use when selected or required by the project.

- Verify current MongoDB repository instructions for the OS version.
- Bind to localhost by default.
- Enable authentication before exposing beyond localhost.
- Create project-specific database/user and backup routine.
- Be careful with MongoDB version compatibility and storage engine requirements on small VPS instances.

## Redis

Use for cache, queues, sessions, or rate limiting.

- Bind to localhost or a private network.
- Enable protected mode and password only if the client configuration supports it.
- Set memory policy intentionally.
- For queues, include worker services and restart policies.

## Backups and Monitoring

Use when selected, and recommend it for production servers.

- Back up databases, uploads/media, env files, nginx configs, compose files, and systemd unit files.
- Keep backups off-host when possible.
- Add restore test instructions, not just backup commands.
- Add basic monitoring: disk, memory, CPU, service health, TLS expiry, and failed systemd units.
- For small projects, a cron backup plus uptime monitor may be enough.
