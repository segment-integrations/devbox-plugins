#!/usr/bin/env sh
set -eu

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

config_dir="${IOS_CONFIG_DIR:-./devbox.d/ios}"
config_path="${config_dir%/}/ios.json"
devices_dir="${IOS_DEVICES_DIR:-${config_dir%/}/devices}"
scripts_dir="${IOS_SCRIPTS_DIR:-${config_dir%/}/scripts}"

require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required." >&2
    exit 1
  fi
}

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

require_jq

validate_runtime() {
  value="$1"
  case "$value" in
    ''|*[^0-9.]*|.*.|*..*)
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
    [ "${1-}" != "" ] || usage
    "${scripts_dir%/}/select-device.sh" "$@"
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
    lock_path="${config_dir%/}/devices.lock.json"

    # Compute checksum of device files
    checksum=""
    if command -v sha256sum >/dev/null 2>&1; then
      checksum=$(find "$devices_dir" -name "*.json" -type f -exec cat {} \; 2>/dev/null | sha256sum | cut -d' ' -f1)
    elif command -v shasum >/dev/null 2>&1; then
      checksum=$(find "$devices_dir" -name "*.json" -type f -exec cat {} \; 2>/dev/null | shasum -a 256 | cut -d' ' -f1)
    fi

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
