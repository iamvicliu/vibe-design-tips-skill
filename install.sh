#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_NAME="vibe-design-tips"

install_to() {
  local target_base="$1"
  local target_dir="${target_base}/${SKILL_NAME}"
  mkdir -p "${target_dir}/issues"
  cp "${REPO_DIR}/SKILL.md" "${target_dir}/SKILL.md"
  cp "${REPO_DIR}/issues/"*.md "${target_dir}/issues/"
  echo "Installed ${SKILL_NAME} -> ${target_dir}"
}

if [[ $# -gt 0 ]]; then
  for custom_base in "$@"; do
    install_to "${custom_base}"
  done
  exit 0
fi

installed=0
for base in "${HOME}/.claude/skills" "${HOME}/.codex/skills" "${HOME}/.gemini/config/skills"; do
  if [[ -d "${base}" ]]; then
    install_to "${base}"
    installed=1
  fi
done

if [[ ${installed} -eq 0 ]]; then
  install_to "${HOME}/.claude/skills"
fi

echo "Done! Restart or reload your AI coding agent to pick up the updated ${SKILL_NAME} skill."
