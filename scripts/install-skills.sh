#!/usr/bin/env bash
set -euo pipefail

target="Both"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
source_dir="${repo_root}/skills"
destination_root="${HOME}"

usage() {
  cat <<'EOF'
Usage: scripts/install-skills.sh [--target Codex|Claude|Both] [--source PATH] [--destination-root PATH]

Installs skill folders from the repository into local Codex and/or Claude skill directories.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -t|--target)
      target="${2:-}"
      shift 2
      ;;
    -s|--source)
      source_dir="${2:-}"
      shift 2
      ;;
    -d|--destination-root)
      destination_root="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    Codex|Claude|Both)
      target="$1"
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "$target" in
  Codex|Claude|Both) ;;
  *)
    echo "Invalid target: ${target}. Use Codex, Claude, or Both." >&2
    exit 2
    ;;
esac

if [ ! -d "$source_dir" ]; then
  echo "Skills source folder not found: ${source_dir}" >&2
  exit 1
fi

copy_skills() {
  destination="$1"
  mkdir -p "$destination"

  find "$source_dir" -mindepth 1 -maxdepth 1 -type d -print | while IFS= read -r skill_dir; do
    skill_name="$(basename "$skill_dir")"
    target_path="${destination}/${skill_name}"
    mkdir -p "$target_path"
    cp -R "${skill_dir}/." "$target_path/"
    echo "Installed ${skill_name} -> ${target_path}"
  done
}

if [ "$target" = "Codex" ] || [ "$target" = "Both" ]; then
  copy_skills "${destination_root}/.codex/skills"
fi

if [ "$target" = "Claude" ] || [ "$target" = "Both" ]; then
  copy_skills "${destination_root}/.claude/skills"
fi
