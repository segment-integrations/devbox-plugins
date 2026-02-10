#!/usr/bin/env bash
# Sync plugin scripts to example projects
# Run this after modifying plugin scripts during development

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Syncing Android plugin scripts to examples..."

# Sync to android example
if [ -d "$REPO_ROOT/examples/android/.devbox/virtenv/android/scripts" ]; then
  echo "  → examples/android"
  cp -r "$REPO_ROOT/plugins/android/scripts/"* "$REPO_ROOT/examples/android/.devbox/virtenv/android/scripts/"
fi

# Sync to react-native example
if [ -d "$REPO_ROOT/examples/react-native/.devbox/virtenv/android/scripts" ]; then
  echo "  → examples/react-native (android)"
  cp -r "$REPO_ROOT/plugins/android/scripts/"* "$REPO_ROOT/examples/react-native/.devbox/virtenv/android/scripts/"
fi

echo "✓ Plugin scripts synced"
echo ""
echo "Note: This is a development-only helper. In production, devbox"
echo "      automatically installs plugin scripts during 'devbox shell'."
