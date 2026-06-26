# Custom AI Skills

Source of truth for personal skills used with Codex and Claude Code.

## Layout

```text
skills/
  setup-web-server/
    SKILL.md
    agents/openai.yaml
    references/
  secure-ssh-server/
    SKILL.md
    agents/openai.yaml
    references/
scripts/
  install-skills.ps1
  install-skills.sh
```

Keep each skill in `skills/<skill-name>`. Codex and Claude Code both use `SKILL.md`-based skill folders, while Codex can also use `agents/openai.yaml` for UI metadata.

## Install Locally

From this repository:

Windows PowerShell:

```powershell
.\scripts\install-skills.ps1 -Target Both
```

Linux or macOS:

```bash
bash ./scripts/install-skills.sh --target Both
```

Targets:

- `Codex` copies skills to `%USERPROFILE%\.codex\skills`
- `Claude` copies skills to `%USERPROFILE%\.claude\skills`
- `Both` copies to both locations

On Linux/macOS the same targets copy to `$HOME/.codex/skills` and `$HOME/.claude/skills`.

The scripts overwrite files with the same names but do not delete extra files in the target folders.
Use `-DestinationRoot <path>` on Windows or `--destination-root <path>` on Linux/macOS to test or install into another profile root.

## Skills

- `setup-web-server` - prepares production Debian/Ubuntu web servers through a stack-selection workflow covering base hardening, nginx/TLS, Docker, Python/Django/FastAPI, Node.js, Go, Postgres, MySQL/MariaDB, MongoDB, Redis, backups, and monitoring.
- `secure-ssh-server` - hardens SSH access on Debian/Ubuntu VPS hosts with key-only login, non-root users, sshd policy, UFW/fail2ban, optional knockd port knocking, iptables persistence, verification, and rollback.
