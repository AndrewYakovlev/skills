# Custom AI Skills

Source of truth for personal skills used with Codex and Claude Code.

## Layout

```text
skills/
  setup-web-server/
    SKILL.md
    agents/openai.yaml
    references/
scripts/
  install-skills.ps1
```

Keep each skill in `skills/<skill-name>`. Codex and Claude Code both use `SKILL.md`-based skill folders, while Codex can also use `agents/openai.yaml` for UI metadata.

## Install Locally

From this repository:

```powershell
.\scripts\install-skills.ps1 -Target Both
```

Targets:

- `Codex` copies skills to `%USERPROFILE%\.codex\skills`
- `Claude` copies skills to `%USERPROFILE%\.claude\skills`
- `Both` copies to both locations

The script overwrites files with the same names but does not delete extra files in the target folders.
Use `-DestinationRoot <path>` to test or install into another profile root.

## Skills

- `setup-web-server` - prepares production Debian/Ubuntu web servers through a stack-selection workflow covering base hardening, nginx/TLS, Docker, Python/Django/FastAPI, Node.js, Go, Postgres, MySQL/MariaDB, MongoDB, Redis, backups, and monitoring.
