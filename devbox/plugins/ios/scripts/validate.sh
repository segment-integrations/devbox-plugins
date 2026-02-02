#!/usr/bin/env bash
set -euo pipefail

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

  # Compute checksum of device files
  local current_checksum
  if command -v sha256sum >/dev/null 2>&1; then
    current_checksum=$(find "$devices_dir" -name "*.json" -type f -exec cat {} \; 2>/dev/null | sha256sum | cut -d' ' -f1)
  elif command -v shasum >/dev/null 2>&1; then
    current_checksum=$(find "$devices_dir" -name "*.json" -type f -exec cat {} \; 2>/dev/null | shasum -a 256 | cut -d' ' -f1)
  else
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
