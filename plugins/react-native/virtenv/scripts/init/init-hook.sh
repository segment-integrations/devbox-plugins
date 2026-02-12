#!/usr/bin/env bash
# React Native Plugin - Initialization Hook
# Adds React Native scripts to PATH

set -e

# Add React Native scripts to PATH if not already present
if [ -n "${REACT_NATIVE_SCRIPTS_DIR:-}" ] && [ -d "${REACT_NATIVE_SCRIPTS_DIR}" ]; then
  # Add user-facing scripts (rn.sh, metro.sh) to PATH
  USER_SCRIPTS_DIR="${REACT_NATIVE_SCRIPTS_DIR}/user"
  if [ -d "$USER_SCRIPTS_DIR" ]; then
    # Make scripts executable
    chmod +x "$USER_SCRIPTS_DIR"/*.sh 2>/dev/null || true

    # Add to PATH if not already present
    if [[ ":$PATH:" != *":$USER_SCRIPTS_DIR:"* ]]; then
      export PATH="$USER_SCRIPTS_DIR:$PATH"
    fi
  fi
fi
