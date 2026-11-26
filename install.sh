#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_NAME="vibe-design-tips"
LAUNCHD_LABEL="com.vibe-design-tips.auto-sync"
CRON_TAG="# vibe-design-tips-auto-sync"

SYNC_FIRST=0
LINK_MODE=0
FORCE=0
ENABLE_AUTO_UPDATE=0
DISABLE_AUTO_UPDATE=0
DRY_RUN=0
INTERVAL_HOURS=4
CUSTOM_TARGETS=()

usage() {
  cat <<'EOF'
Usage: ./install.sh [options] [target_base_dir...]

Install vibe-design-tips into local AI coding agent skill directories
(defaults: ~/.claude/skills, ~/.codex/skills, ~/.gemini/config/skills).

Options:
  --sync                   Fetch latest tips from https://vibedesign.tips/ before installing
  --link                   Symlink <target>/vibe-design-tips -> this repo instead of copying files
  --clean                  Ensure stale issue files are removed in copy mode (default with rsync)
  --force                  Replace existing directories/symlinks when switching modes
  --enable-auto-update     Register a background job (launchd on macOS, cron on Linux)
  --disable-auto-update    Remove the registered background auto-update job
  --interval <hours>       Auto-update interval in hours (positive integer, default: 4)
  --dry-run                Preview installation and auto-update changes without writing system files
  -h, --help               Show this help message

Examples:
  ./install.sh
  ./install.sh --link --enable-auto-update
  ./install.sh --enable-auto-update --interval 6 --dry-run
  ./install.sh ~/.claude/skills
EOF
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

install_copy_to() {
  local target_base="$1"
  local target_dir="${target_base}/${SKILL_NAME}"

  if [[ -L "${target_dir}" ]]; then
    if [[ ${FORCE} -ne 1 ]]; then
      echo "Error: ${target_dir} is a symlink. Re-run with --link or pass --force to replace it with a copy." >&2
      return 1
    fi
    if [[ ${DRY_RUN} -eq 1 ]]; then
      echo "[dry-run] rm -f ${target_dir}"
    else
      rm -f "${target_dir}"
    fi
  fi

  if [[ ${DRY_RUN} -eq 1 ]]; then
    echo "[dry-run] Sync files -> ${target_dir}"
    return 0
  fi

  mkdir -p "${target_dir}/issues"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a "${REPO_DIR}/SKILL.md" "${target_dir}/SKILL.md"
    rsync -a --delete --include='*.md' --exclude='*' "${REPO_DIR}/issues/" "${target_dir}/issues/"
  else
    rm -f "${target_dir}/issues/"*.md
    cp "${REPO_DIR}/SKILL.md" "${target_dir}/SKILL.md"
    cp "${REPO_DIR}/issues/"*.md "${target_dir}/issues/"
  fi
  echo "Installed ${SKILL_NAME} -> ${target_dir}"
}

install_link_to() {
  local target_base="$1"
  local target_dir="${target_base}/${SKILL_NAME}"

  if is_repo_symlink "${target_dir}"; then
    echo "Already linked ${SKILL_NAME} -> ${target_dir} -> ${REPO_DIR}"
    return 0
  fi

  if [[ -e "${target_dir}" || -L "${target_dir}" ]]; then
    if [[ ${FORCE} -ne 1 ]]; then
      echo "Error: ${target_dir} already exists and does not point to ${REPO_DIR}. Re-run with --force to replace it." >&2
      return 1
    fi
    if [[ ${DRY_RUN} -eq 1 ]]; then
      echo "[dry-run] rm -rf ${target_dir}"
    else
      rm -rf "${target_dir}"
    fi
  fi

  if [[ ${DRY_RUN} -eq 1 ]]; then
    echo "[dry-run] ln -s ${REPO_DIR} ${target_dir}"
    return 0
  fi

  mkdir -p "${target_base}"
  ln -s "${REPO_DIR}" "${target_dir}"
  echo "Linked ${SKILL_NAME} -> ${target_dir} -> ${REPO_DIR}"
}

install_to() {
  local target_base="$1"
  if [[ ${LINK_MODE} -eq 1 ]]; then
    install_link_to "${target_base}"
  else
    install_copy_to "${target_base}"
  fi
}

render_launchd_plist() {
  local interval_seconds=$((INTERVAL_HOURS * 3600))
  local sync_mode="auto"
  local log_path="${HOME}/Library/Logs/vibe-design-tips-sync.log"
  local target_xml=""
  local t

  if [[ ${LINK_MODE} -eq 1 ]]; then
    sync_mode="link"
  fi

  for t in "${CUSTOM_TARGETS[@]}"; do
    target_xml="${target_xml}
        <string>--target</string>
        <string>${t}</string>"
  done

  cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${LAUNCHD_LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${REPO_DIR}/scripts/auto_sync.sh</string>
        <string>--mode</string>
        <string>${sync_mode}</string>${target_xml}
    </array>
    <key>WorkingDirectory</key>
    <string>${REPO_DIR}</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>HOME</key>
        <string>${HOME}</string>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/local/bin:${HOME}/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>StartInterval</key>
    <integer>${interval_seconds}</integer>
    <key>ProcessType</key>
    <string>Background</string>
    <key>StandardOutPath</key>
    <string>${log_path}</string>
    <key>StandardErrorPath</key>
    <string>${log_path}</string>
</dict>
</plist>
EOF
}

build_cron_line() {
  local sync_mode="auto"
  local log_path="${HOME}/.cache/vibe-design-tips-sync.log"
  local schedule="0 */${INTERVAL_HOURS} * * *"
  local cmd="/bin/bash \"${REPO_DIR}/scripts/auto_sync.sh\" --mode ${sync_mode}"
  local t

  if [[ ${LINK_MODE} -eq 1 ]]; then
    sync_mode="link"
    cmd="/bin/bash \"${REPO_DIR}/scripts/auto_sync.sh\" --mode ${sync_mode}"
  fi
  if [[ ${INTERVAL_HOURS} -eq 24 ]]; then
    schedule="0 4 * * *"
  elif [[ ${INTERVAL_HOURS} -gt 24 ]]; then
    schedule="0 4 */$((INTERVAL_HOURS / 24)) * *"
  fi

  for t in "${CUSTOM_TARGETS[@]}"; do
    cmd="${cmd} --target \"${t}\""
  done

  printf '%s mkdir -p "%s" && %s >> "%s" 2>&1 %s\n' \
    "${schedule}" "$(dirname "${log_path}")" "${cmd}" "${log_path}" "${CRON_TAG}"
}

enable_auto_update() {
  local os_name
  os_name="$(uname -s)"

  if [[ "${os_name}" == "Darwin" ]]; then
    local agents_dir="${HOME}/Library/LaunchAgents"
    local plist_path="${agents_dir}/${LAUNCHD_LABEL}.plist"
    local uid_num
    uid_num="$(id -u)"

    if [[ ${DRY_RUN} -eq 1 ]]; then
      echo "[dry-run] Would write LaunchAgent plist to: ${plist_path}"
      render_launchd_plist
      echo "[dry-run] Would run: launchctl bootout gui/${uid_num}/${LAUNCHD_LABEL} (if loaded) && launchctl bootstrap gui/${uid_num} ${plist_path}"
      return 0
    fi

    mkdir -p "${agents_dir}" "${HOME}/Library/Logs"
    render_launchd_plist > "${plist_path}"
    if command -v plutil >/dev/null 2>&1; then
      plutil -lint "${plist_path}" >/dev/null
    fi
    launchctl bootout "gui/${uid_num}/${LAUNCHD_LABEL}" 2>/dev/null || true
    launchctl bootstrap "gui/${uid_num}" "${plist_path}"
    echo "Enabled macOS LaunchAgent auto-update (every ${INTERVAL_HOURS}h) -> ${plist_path}"
  elif [[ "${os_name}" == "Linux" ]]; then
    local cron_line
    cron_line="$(build_cron_line)"
    if [[ ${DRY_RUN} -eq 1 ]]; then
      echo "[dry-run] Would install crontab entry:"
      echo "${cron_line}"
      return 0
    fi
    local current_cron
    current_cron="$(crontab -l 2>/dev/null || true)"
    {
      printf '%s\n' "${current_cron}" | grep -vF "${CRON_TAG}" || true
      printf '%s\n' "${cron_line}"
    } | awk 'NF' | crontab -
    echo "Enabled Linux cron auto-update (every ${INTERVAL_HOURS}h)."
  else
    echo "Auto-update scheduler setup is only supported on macOS (launchd) and Linux (cron). Current OS: ${os_name}" >&2
    return 1
  fi
}

disable_auto_update() {
  local os_name
  os_name="$(uname -s)"

  if [[ "${os_name}" == "Darwin" ]]; then
    local plist_path="${HOME}/Library/LaunchAgents/${LAUNCHD_LABEL}.plist"
    local uid_num
    uid_num="$(id -u)"
    if [[ ${DRY_RUN} -eq 1 ]]; then
      echo "[dry-run] Would bootout gui/${uid_num}/${LAUNCHD_LABEL} and remove ${plist_path}"
      return 0
    fi
    launchctl bootout "gui/${uid_num}/${LAUNCHD_LABEL}" 2>/dev/null || true
    if [[ -f "${plist_path}" ]]; then
      rm -f "${plist_path}"
      echo "Disabled and removed LaunchAgent: ${plist_path}"
    else
      echo "No LaunchAgent found at ${plist_path}."
    fi
  elif [[ "${os_name}" == "Linux" ]]; then
    if [[ ${DRY_RUN} -eq 1 ]]; then
      echo "[dry-run] Would remove crontab entries tagged with ${CRON_TAG}"
      return 0
    fi
    local current_cron
    current_cron="$(crontab -l 2>/dev/null || true)"
    printf '%s\n' "${current_cron}" | grep -vF "${CRON_TAG}" | crontab - || true
    echo "Disabled Linux cron auto-update."
  else
    echo "Auto-update scheduler removal is only supported on macOS and Linux. Current OS: ${os_name}" >&2
    return 1
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sync)
      SYNC_FIRST=1
      shift
      ;;
    --link)
      LINK_MODE=1
      shift
      ;;
    --clean)
      shift
      ;;
    --force)
      FORCE=1
      shift
      ;;
    --enable-auto-update)
      ENABLE_AUTO_UPDATE=1
      shift
      ;;
    --disable-auto-update)
      DISABLE_AUTO_UPDATE=1
      shift
      ;;
    --interval)
      [[ $# -ge 2 ]] || { echo "Error: --interval requires an integer (hours)." >&2; exit 2; }
      INTERVAL_HOURS="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      CUSTOM_TARGETS+=("$1")
      shift
      ;;
  esac
done

if [[ ! "${INTERVAL_HOURS}" =~ ^[1-9][0-9]*$ ]]; then
  echo "Error: --interval must be a positive integer (got '${INTERVAL_HOURS}')." >&2
  exit 2
fi

if [[ ${ENABLE_AUTO_UPDATE} -eq 1 && ${DISABLE_AUTO_UPDATE} -eq 1 ]]; then
  echo "Error: --enable-auto-update and --disable-auto-update cannot be used together." >&2
  exit 2
fi

if [[ ${DISABLE_AUTO_UPDATE} -eq 1 ]]; then
  disable_auto_update
  exit 0
fi

if [[ ${SYNC_FIRST} -eq 1 ]]; then
  echo "Syncing latest official tips from https://vibedesign.tips/ ..."
  if [[ ${DRY_RUN} -eq 1 ]]; then
    python3 "${REPO_DIR}/scripts/sync_official.py" --dry-run
  else
    python3 "${REPO_DIR}/scripts/sync_official.py"
  fi
fi

run_install=1
# 若仅执行 --enable-auto-update 且本机已有指向本仓库的软链，保留原软链状态不报错
if [[ ${ENABLE_AUTO_UPDATE} -eq 1 && ${LINK_MODE} -eq 0 && ${FORCE} -eq 0 && ${#CUSTOM_TARGETS[@]} -eq 0 ]]; then
  for base in "${HOME}/.claude/skills" "${HOME}/.codex/skills" "${HOME}/.gemini/config/skills"; do
    if is_repo_symlink "${base}/${SKILL_NAME}"; then
      run_install=0
      break
    fi
  done
fi

if [[ ${run_install} -eq 1 ]]; then
  if [[ ${#CUSTOM_TARGETS[@]} -gt 0 ]]; then
    for custom_base in "${CUSTOM_TARGETS[@]}"; do
      install_to "${custom_base}"
    done
  else
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
  fi
fi

if [[ ${ENABLE_AUTO_UPDATE} -eq 1 ]]; then
  enable_auto_update
fi

echo "Done! Restart or reload your AI coding agent to pick up the updated ${SKILL_NAME} skill."
