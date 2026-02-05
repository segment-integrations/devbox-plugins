#!/usr/bin/env bash
set -euo pipefail

if ! (return 0 2>/dev/null); then
  echo "ERROR: validate.sh must be sourced" >&2
  exit 1
fi

if [ "${IOS_VALIDATE_LOADED:-}" = "1" ] && [ "${IOS_VALIDATE_LOADED_PID:-}" = "$$" ]; then
  return 0 2>/dev/null || exit 0
fi
IOS_VALIDATE_LOADED=1
IOS_VALIDATE_LOADED_PID="$$"

# Source dependencies
script_dir="$(cd "$(dirname "$0")" && pwd)"
if [ -n "${IOS_SCRIPTS_DIR:-}" ] && [ -d "${IOS_SCRIPTS_DIR}" ]; then
  script_dir="${IOS_SCRIPTS_DIR}"
fi

# shellcheck disable=SC1090
. "$script_dir/lib.sh"

ios_validate_xcode() {
  # Only validate on macOS
  if [ "$(uname -s)" != "Darwin" ]; then
    return 0
  fi

  # Check if Xcode exists
  if ! command -v xcode-select >/dev/null 2>&1; then
    echo "Warning: xcode-select not found. Install Xcode from the App Store." >&2
    return 0
  fi

  local dev_dir
  dev_dir=$(xcode-select -p 2>/dev/null || true)

  if [ -z "$dev_dir" ] || [ ! -d "$dev_dir" ]; then
    echo "Warning: Xcode developer directory not found. Run 'xcode-select --install' or install Xcode from the App Store." >&2
  fi
}

ios_validate_lock_file() {
  local lock_path="${IOS_CONFIG_DIR}/devices.lock.json"
  local devices_dir="${IOS_DEVICES_DIR}"

  # Lock file is optional for iOS
  if [ ! -f "$lock_path" ]; then
    return 0
  fi

  # Compute checksum of device files using lib.sh function
  local current_checksum
  current_checksum=$(ios_compute_devices_checksum "$devices_dir" 2>/dev/null || echo "")
  if [ -z "$current_checksum" ]; then
    # No checksum tool available, skip validation
    return 0
  fi

  # Read checksum from lock file
  local lock_checksum
  lock_checksum=$(jq -r '.checksum // ""' "$lock_path" 2>/dev/null || echo "")

  if [ "$current_checksum" != "$lock_checksum" ]; then
    echo "Warning: devices.lock.json may be stale. Run 'devbox run ios.sh devices eval' to update." >&2
  fi
}
