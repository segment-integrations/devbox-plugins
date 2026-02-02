#!/usr/bin/env bash
set -euo pipefail

android_validate_lock_file() {
  local lock_path="${ANDROID_CONFIG_DIR}/devices.lock.json"
  local devices_dir="${ANDROID_DEVICES_DIR}"

  # Check if lock file exists
  if [ ! -f "$lock_path" ]; then
    echo "Warning: devices.lock.json not found. Run 'devbox run android.sh devices eval' to generate." >&2
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
    echo "Warning: devices.lock.json may be stale (device definitions changed). Run 'devbox run android.sh devices eval' to update." >&2
  fi
}

android_validate_sdk() {
  if [ -n "${ANDROID_SDK_ROOT:-}" ] && [ ! -d "$ANDROID_SDK_ROOT" ]; then
    echo "Warning: ANDROID_SDK_ROOT points to non-existent directory: $ANDROID_SDK_ROOT" >&2
  fi
}
