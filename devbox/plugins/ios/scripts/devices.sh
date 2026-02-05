#!/usr/bin/env sh
set -eu

# devices.sh is a CLI script and can be executed directly
# Source dependencies
script_dir="$(cd "$(dirname "$0")" && pwd)"
if [ -n "${IOS_SCRIPTS_DIR:-}" ] && [ -d "${IOS_SCRIPTS_DIR}" ]; then
  script_dir="${IOS_SCRIPTS_DIR}"
fi

# shellcheck disable=SC1090
. "$script_dir/lib.sh"

usage() {
  cat >&2 <<'USAGE'
Usage: devices.sh <command> [args]
       DEVICES_CMD="list" devices.sh

Commands:
  list
  show <name>
  create <name> --runtime <version>
  update <name> [--name <new>] [--runtime <version>]
  delete <name>
  select <name...>
  reset
  eval

Runtime values: run `xcrun simctl list runtimes` and use the iOS version (e.g. 17.5).
Device names: run `xcrun simctl list devicetypes` and use the exact name.
USAGE
  exit 1
}

if [ -z "${1-}" ] && [ -n "${DEVICES_CMD:-}" ]; then
  set -- $DEVICES_CMD
fi

command_name="${1-}"
if [ -z "$command_name" ] || [ "$command_name" = "help" ]; then
  usage
fi
shift || true

# Use lib.sh functions for path resolution
config_path="$(ios_config_path 2>/dev/null || echo "./devbox.d/ios/ios.json")"
devices_dir="$(ios_devices_dir 2>/dev/null || echo "./devbox.d/ios/devices")"

# Ensure jq is available
ios_require_jq

resolve_device_file() {
  selection="$1"
  if [ -z "$selection" ]; then
    return 1
  fi
  if [ -f "$devices_dir/${selection}.json" ]; then
    printf '%s\n' "$devices_dir/${selection}.json"
    return 0
  fi
  for file in "$devices_dir"/*.json; do
    [ -f "$file" ] || continue
    name="$(jq -r '.name // empty' "$file")"
    if [ "$name" = "$selection" ]; then
      printf '%s\n' "$file"
      return 0
    fi
  done
  return 1
}

validate_runtime() {
  value="$1"
  case "$value" in
    ''|*[!0-9.]*|.*.|*..*)
      echo "Invalid runtime: $value" >&2
      exit 1
      ;;
  esac
}

case "$command_name" in
  list)
    for file in "$devices_dir"/*.json; do
      [ -f "$file" ] || continue
      jq -r '"\(.name // "")\t\(.runtime // "")\t\(. | @json)"' "$file"
    done
    ;;
  show)
    name="${1-}"
    [ -n "$name" ] || usage
    file="$(resolve_device_file "$name")" || { echo "Device not found: $name" >&2; exit 1; }
    cat "$file"
    ;;
  create)
    name="${1-}"
    [ -n "$name" ] || usage
    shift || true
    runtime=""
    while [ "${1-}" != "" ]; do
      case "$1" in
        --runtime) runtime="$2"; shift 2 ;;
        *) usage ;;
      esac
    done
    [ -n "$runtime" ] || { echo "--runtime is required" >&2; exit 1; }
    validate_runtime "$runtime"
    mkdir -p "$devices_dir"
    jq -n --arg name "$name" --arg runtime "$runtime" '{name:$name, runtime:$runtime}' >"$devices_dir/${name}.json"
    ;;
  update)
    name="${1-}"
    [ -n "$name" ] || usage
    shift || true
    file="$(resolve_device_file "$name")" || { echo "Device not found: $name" >&2; exit 1; }
    new_name=""
    runtime=""
    while [ "${1-}" != "" ]; do
      case "$1" in
        --name) new_name="$2"; shift 2 ;;
        --runtime) runtime="$2"; shift 2 ;;
        *) usage ;;
      esac
    done
    if [ -n "$runtime" ]; then
      validate_runtime "$runtime"
    fi
    tmp="${file}.tmp"
    jq \
      --arg name "$new_name" \
      --arg runtime "$runtime" \
      '(
        if $name != "" then .name=$name else . end
      ) | (
        if $runtime != "" then .runtime=$runtime else . end
      )' "$file" >"$tmp"
    mv "$tmp" "$file"
    if [ -n "$new_name" ]; then
      mv "$file" "$devices_dir/${new_name}.json"
    fi
    ;;
  delete)
    name="${1-}"
    [ -n "$name" ] || usage
    file="$(resolve_device_file "$name")" || { echo "Device not found: $name" >&2; exit 1; }
    rm -f "$file"
    ;;
  select)
    # Inline select-device.sh functionality
    [ "${1-}" != "" ] || usage
    if [ ! -f "$config_path" ]; then
      echo "iOS config not found: $config_path" >&2
      exit 1
    fi
    tmp="${config_path}.tmp"
    jq --argjson selections "$(printf '%s\n' "$@" | jq -R . | jq -s .)" '.EVALUATE_DEVICES = $selections' "$config_path" >"$tmp"
    mv "$tmp" "$config_path"
    echo "Selected iOS devices: $*"
    ;;
  reset)
    tmp="${config_path}.tmp"
    jq '.EVALUATE_DEVICES = []' "$config_path" >"$tmp"
    mv "$tmp" "$config_path"
    echo "Selected iOS devices: all"
    ;;
  eval)
    # Get selected devices
    selected=$(jq -r '.EVALUATE_DEVICES // []' "$config_path")

    # Generate lock file
    config_dir="$(dirname "$config_path")"
    lock_path="${config_dir%/}/devices.lock.json"

    # Compute checksum using lib.sh function
    checksum="$(ios_compute_devices_checksum "$devices_dir" 2>/dev/null || echo "")"

    # Determine device names for output
    if [ "$selected" = "[]" ]; then
      device_names="all"
    else
      device_names=$(echo "$selected" | jq -r 'join(",")')
    fi

    # Write lock file with devices array, checksum, and timestamp
    temp_lock="${lock_path}.tmp"
    echo "$selected" | jq --arg cs "$checksum" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)" \
      '{devices: ., checksum: $cs, generated_at: $ts}' > "$temp_lock"
    mv "$temp_lock" "$lock_path"

    echo "$device_names"
    ;;
  *)
    usage
    ;;
esac
