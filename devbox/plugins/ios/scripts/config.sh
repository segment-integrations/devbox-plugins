#!/usr/bin/env sh
# iOS Plugin - Configuration Management
# See REFERENCE.md for detailed documentation

set -eu

if ! (return 0 2>/dev/null); then
  echo "ERROR: config.sh must be sourced" >&2
  exit 1
fi

if [ "${IOS_CONFIG_LOADED:-}" = "1" ] && [ "${IOS_CONFIG_LOADED_PID:-}" = "$$" ]; then
  return 0 2>/dev/null || exit 0
fi
IOS_CONFIG_LOADED=1
IOS_CONFIG_LOADED_PID="$$"

# Source dependencies
script_dir="$(cd "$(dirname "$0")" && pwd)"
if [ -n "${IOS_SCRIPTS_DIR:-}" ] && [ -d "${IOS_SCRIPTS_DIR}" ]; then
  script_dir="${IOS_SCRIPTS_DIR}"
fi

# shellcheck disable=SC1090
. "$script_dir/lib.sh"

ios_debug_log "config.sh loaded"

# ============================================================================
# Config Management Functions
# ============================================================================

# Show current configuration
ios_config_show() {
  config_path="$(ios_config_path 2>/dev/null || true)"
  if [ -z "$config_path" ] || [ ! -f "$config_path" ]; then
    echo "ERROR: Config file not found" >&2
    return 1
  fi
  cat "$config_path"
}

# Set configuration values
# Args: key=value pairs
ios_config_set() {
  ios_require_jq
  config_path="$(ios_config_path 2>/dev/null || true)"
  if [ -z "$config_path" ] || [ ! -f "$config_path" ]; then
    echo "ERROR: Config file not found" >&2
    return 1
  fi

  if [ -z "${1-}" ]; then
    echo "ERROR: No key=value pairs provided" >&2
    return 1
  fi

  tmp="${config_path}.tmp"
  filter='.'
  while [ "${1-}" != "" ]; do
    pair="$1"
    key="${pair%%=*}"
    value="${pair#*=}"
    if [ -z "$key" ] || [ "$key" = "$value" ]; then
      echo "ERROR: Invalid key=value: $pair" >&2
      return 1
    fi
    if ! jq -e --arg key "$key" 'has($key)' "$config_path" >/dev/null 2>&1; then
      echo "ERROR: Unknown config key: $key" >&2
      return 1
    fi
    filter="$filter | .${key} = \"${value}\""
    shift
  done
  jq "$filter" "$config_path" >"$tmp"
  mv "$tmp" "$config_path"
}

# Reset configuration to defaults
ios_config_reset() {
  config_path="$(ios_config_path 2>/dev/null || true)"
  if [ -z "$config_path" ]; then
    echo "ERROR: Config file not found" >&2
    return 1
  fi

  default_config=""
  if [ -n "${IOS_SCRIPTS_DIR:-}" ]; then
    candidate="${IOS_SCRIPTS_DIR%/}/../config/ios.json"
    if [ -f "$candidate" ]; then
      default_config="$candidate"
    fi
  fi
  if [ -z "$default_config" ]; then
    echo "ERROR: Default iOS config not found; reinstall the plugin to restore defaults." >&2
    return 1
  fi
  cp "$default_config" "$config_path"
  echo "Config reset to defaults"
}
