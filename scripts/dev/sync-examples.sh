#!/usr/bin/env bash
# Sync plugin scripts to example projects
# Run this after modifying plugin scripts during development

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "Syncing plugin scripts to examples..."
echo ""

echo "Android plugin:"
# Sync to android example
if [ -d "$REPO_ROOT/examples/android/.devbox/virtenv/android/scripts" ]; then
  echo "  → examples/android"
  cp -r "$REPO_ROOT/plugins/android/virtenv/scripts/"* "$REPO_ROOT/examples/android/.devbox/virtenv/android/scripts/"
fi

# Sync to react-native example
if [ -d "$REPO_ROOT/examples/react-native/.devbox/virtenv/android/scripts" ]; then
  echo "  → examples/react-native"
  cp -r "$REPO_ROOT/plugins/android/virtenv/scripts/"* "$REPO_ROOT/examples/react-native/.devbox/virtenv/android/scripts/"
fi

echo ""
echo "iOS plugin:"
# Sync to ios example
if [ -d "$REPO_ROOT/examples/ios/.devbox/virtenv/ios/scripts" ]; then
  echo "  → examples/ios"
  cp -r "$REPO_ROOT/plugins/ios/virtenv/scripts/"* "$REPO_ROOT/examples/ios/.devbox/virtenv/ios/scripts/"
fi

# Sync to react-native example
if [ -d "$REPO_ROOT/examples/react-native/.devbox/virtenv/ios/scripts" ]; then
  echo "  → examples/react-native"
  cp -r "$REPO_ROOT/plugins/ios/virtenv/scripts/"* "$REPO_ROOT/examples/react-native/.devbox/virtenv/ios/scripts/"
fi

echo ""
echo "✓ Plugin scripts synced"
echo ""
echo "Note: This is a development-only helper. In production, devbox"
echo "      automatically installs plugin scripts during 'devbox shell'."
