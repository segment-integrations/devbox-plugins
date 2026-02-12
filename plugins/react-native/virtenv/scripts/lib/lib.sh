#!/usr/bin/env sh
# React Native Plugin - Core Utilities

set -eu

if ! (return 0 2>/dev/null); then
  echo "ERROR: lib.sh must be sourced" >&2
  exit 1
fi

if [ "${RN_LIB_LOADED:-}" = "1" ] && [ "${RN_LIB_LOADED_PID:-}" = "$$" ]; then
  return 0 2>/dev/null || exit 0
fi
RN_LIB_LOADED=1
RN_LIB_LOADED_PID="$$"

# ============================================================================
# Metro Port Management
# ============================================================================

# Find available port in range
rn_find_available_port() {
  start_port="${1:-8091}"
  end_port="${2:-8199}"

  for port in $(seq "$start_port" "$end_port"); do
    # Check if port is available (works on macOS and Linux)
    if ! lsof -i ":$port" >/dev/null 2>&1; then
      echo "$port"
      return 0
    fi
  done

  return 1
}

# Allocate Metro port for a specific test suite
# Usage: rn_allocate_metro_port [suite_name]
rn_allocate_metro_port() {
  suite_name="${1:-default}"
  metro_dir="${DEVBOX_VIRTENV}/metro"
  port_file="$metro_dir/port-${suite_name}.txt"

  mkdir -p "$metro_dir"

  # Check if port already allocated and still available
  if [ -f "$port_file" ]; then
    allocated_port=$(cat "$port_file")
    # Verify port is still available
    if ! lsof -i ":$allocated_port" >/dev/null 2>&1; then
      echo "$allocated_port"
      return 0
    fi
  fi

  # Find new port
  available_port=$(rn_find_available_port 8091 8199)
  if [ -z "$available_port" ]; then
    echo "ERROR: No available ports in range 8091-8199" >&2
    return 1
  fi

  # Save port
  echo "$available_port" > "$port_file"
  echo "$available_port"
}

# Get allocated Metro port for a specific test suite
# Usage: rn_get_metro_port [suite_name]
rn_get_metro_port() {
  suite_name="${1:-default}"
  metro_dir="${DEVBOX_VIRTENV}/metro"
  port_file="$metro_dir/port-${suite_name}.txt"

  if [ -f "$port_file" ]; then
    cat "$port_file"
  else
    rn_allocate_metro_port "$suite_name"
  fi
}

# Clean Metro state for a specific test suite
# Usage: rn_clean_metro [suite_name]
rn_clean_metro() {
  suite_name="${1:-default}"
  metro_dir="${DEVBOX_VIRTENV}/metro"

  # Remove port allocation
  rm -f "$metro_dir/port-${suite_name}.txt"
  rm -f "$metro_dir/env-${suite_name}.sh"

  # Optionally clear cache
  if [ "${RN_CLEAR_CACHE:-0}" = "1" ]; then
    rm -rf "$metro_dir/cache"
  fi
}

# Export Metro environment variables for a test suite
# Usage: rn_export_metro_env [suite_name] [port_file]
rn_export_metro_env() {
  suite_name="${1:-default}"
  port_file="${2:-}"

  # Get port from file if provided, otherwise allocate
  if [ -n "$port_file" ] && [ -f "$port_file" ]; then
    metro_port=$(cat "$port_file")
  else
    metro_port=$(rn_get_metro_port "$suite_name")
  fi

  export RCT_METRO_PORT="$metro_port"
  export METRO_PORT="$metro_port"
  export REACT_NATIVE_PACKAGER_HOSTNAME="localhost"
}

# Save Metro environment to file for process-compose processes to source
# Usage: rn_save_metro_env <suite_name> <port>
rn_save_metro_env() {
  suite_name="${1:-default}"
  metro_port="$2"
  metro_dir="${DEVBOX_VIRTENV}/metro"
  env_file="$metro_dir/env-${suite_name}.sh"

  mkdir -p "$metro_dir"

  cat > "$env_file" <<EOF
# Metro environment for test suite: $suite_name
# Generated: $(date)
export RCT_METRO_PORT="$metro_port"
export METRO_PORT="$metro_port"
export REACT_NATIVE_PACKAGER_HOSTNAME="localhost"
EOF

  chmod +x "$env_file"
  echo "$env_file"
}

# Track Metro PID to ensure we only kill processes we started
# Usage: rn_track_metro_pid <suite_name> <pid>
rn_track_metro_pid() {
  suite_name="${1:-default}"
  metro_pid="$2"
  metro_dir="${DEVBOX_VIRTENV}/metro"
  pid_file="$metro_dir/pid-${suite_name}.txt"

  mkdir -p "$metro_dir"
  echo "$metro_pid" > "$pid_file"
}

# Get tracked Metro PID
# Usage: rn_get_metro_pid <suite_name>
rn_get_metro_pid() {
  suite_name="${1:-default}"
  metro_dir="${DEVBOX_VIRTENV}/metro"
  pid_file="$metro_dir/pid-${suite_name}.txt"

  if [ -f "$pid_file" ]; then
    cat "$pid_file"
  else
    return 1
  fi
}

# Stop Metro ONLY if we started it (checks our tracked PID)
# Usage: rn_stop_metro <suite_name>
rn_stop_metro() {
  suite_name="${1:-default}"
  metro_dir="${DEVBOX_VIRTENV}/metro"
  pid_file="$metro_dir/pid-${suite_name}.txt"

  if [ ! -f "$pid_file" ]; then
    echo "No Metro PID tracked for suite: $suite_name (we didn't start it)"
    return 0
  fi

  metro_pid=$(cat "$pid_file")

  # Verify process exists and is actually Metro
  if ps -p "$metro_pid" >/dev/null 2>&1; then
    process_cmd=$(ps -p "$metro_pid" -o command= 2>/dev/null || true)
    if echo "$process_cmd" | grep -q "react-native start"; then
      echo "Stopping Metro (PID: $metro_pid)..."
      kill "$metro_pid" 2>/dev/null || true
      sleep 1
      # Force kill if still running
      if ps -p "$metro_pid" >/dev/null 2>&1; then
        kill -9 "$metro_pid" 2>/dev/null || true
      fi
      echo "✓ Metro stopped"
    else
      echo "PID $metro_pid is not Metro, skipping"
    fi
  fi

  # Remove tracking file
  rm -f "$pid_file"
}
