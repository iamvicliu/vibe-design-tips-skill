#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL_NAME="vibe-design-tips"

MODE="auto"
BRANCH="main"
FORCE=0
CUSTOM_TARGETS=()

usage() {
  cat <<'EOF'
Usage: scripts/auto_sync.sh [options]

Pull the latest upstream commits for vibe-design-tips-skill and refresh
installed local agent skill directories only when HEAD changes.

Options:
  --mode <auto|copy|link>  Sync strategy (default: auto)
  --branch <name>          Git branch to pull from origin (default: main)
  --target <dir>           Custom skills base directory (repeatable)
  --force                  Re-apply installation even if HEAD is unchanged
  -h, --help               Show this help message
EOF
}

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')" "$*"
}

resolve_path() {
  local target="$1"
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$target"
  elif [[ -d "$target" ]]; then
    (cd -P "$target" && pwd)
  else
    printf '%s\n' "$target"
  fi
}

is_repo_symlink() {
  local skill_dir="$1"
  local repo_real target_real
  [[ -L "${skill_dir}" ]] || return 1
  repo_real="$(resolve_path "${REPO_DIR}")"
  target_real="$(resolve_path "${skill_dir}")"
  [[ "${repo_real}" == "${target_real}" ]]
}

all_installed_are_repo_symlinks() {
  local -a bases=()
  local found=0
  local base skill_dir

  if [[ ${#CUSTOM_TARGETS[@]} -gt 0 ]]; then
    bases=("${CUSTOM_TARGETS[@]}")
  else
    bases=(
      "${HOME}/.claude/skills"
      "${HOME}/.codex/skills"
      "${HOME}/.gemini/config/skills"
      "${HOME}/.agents/skills"
    )
  fi

  for base in "${bases[@]}"; do
    skill_dir="${base}/${SKILL_NAME}"
    if [[ -e "${skill_dir}" || -L "${skill_dir}" ]]; then
      found=1
      if ! is_repo_symlink "${skill_dir}"; then
        return 1
      fi
    fi
  done

  [[ ${found} -eq 1 ]]
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      [[ $# -ge 2 ]] || { echo "Error: --mode requires an argument." >&2; exit 2; }
      MODE="$2"
      shift 2
      ;;
    --branch)
      [[ $# -ge 2 ]] || { echo "Error: --branch requires an argument." >&2; exit 2; }
      BRANCH="$2"
      shift 2
      ;;
    --target)
      [[ $# -ge 2 ]] || { echo "Error: --target requires an argument." >&2; exit 2; }
      CUSTOM_TARGETS+=("$2")
      shift 2
      ;;
    --force)
      FORCE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "${MODE}" in
  auto|copy|link) ;;
  *)
    echo "Invalid --mode '${MODE}': expected auto, copy, or link." >&2
    exit 2
    ;;
esac

if [[ ! -d "${REPO_DIR}/.git" ]]; then
  log "Error: ${REPO_DIR} is not a git repository."
  exit 1
fi

cd "${REPO_DIR}"
export GIT_TERMINAL_PROMPT=0

if [[ -n "$(git status --porcelain)" ]]; then
  log "Warning: local uncommitted changes detected in ${REPO_DIR}; skipping git pull."
  exit 0
fi

OLD_HEAD="$(git rev-parse HEAD)"

pull_ok=0
for attempt in 1 2; do
  if git pull --ff-only origin "${BRANCH}"; then
    pull_ok=1
    break
  fi
  if [[ ${attempt} -eq 1 ]]; then
    log "Warning: git pull failed (attempt 1/2); retrying in 10s ..."
    sleep 10
  fi
done

if [[ ${pull_ok} -ne 1 ]]; then
  log "Warning: git pull failed after 2 attempts (offline or network error); keeping existing installation."
  exit 0
fi

NEW_HEAD="$(git rev-parse HEAD)"
SHORT_HEAD="$(git rev-parse --short HEAD)"

if [[ "${OLD_HEAD}" == "${NEW_HEAD}" && ${FORCE} -eq 0 ]]; then
  log "Already up to date (${SHORT_HEAD}); no skill files modified."
  exit 0
fi

if [[ "${MODE}" == "link" ]] || { [[ "${MODE}" == "auto" ]] && all_installed_are_repo_symlinks; }; then
  log "Repository updated (${OLD_HEAD:0:7} -> ${SHORT_HEAD}); symlinked skill directories are live immediately."
  exit 0
fi

INSTALL_ARGS=()
if [[ "${MODE}" == "link" ]]; then
  INSTALL_ARGS+=(--link)
fi
if [[ ${#CUSTOM_TARGETS[@]} -gt 0 ]]; then
  INSTALL_ARGS+=("${CUSTOM_TARGETS[@]}")
fi

"${REPO_DIR}/install.sh" "${INSTALL_ARGS[@]}"
log "Sync completed: ${OLD_HEAD:0:7} -> ${SHORT_HEAD}"
