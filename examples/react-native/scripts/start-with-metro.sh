#!/usr/bin/env bash
# Helper script to start Metro and deploy React Native app
# Usage: start-with-metro.sh <platform> [device]
# Platform: android, ios, web
# Device: optional device name (for android/ios)

set -euo pipefail

PLATFORM="${1:-}"
DEVICE="${2:-}"

if [ -z "$PLATFORM" ]; then
  echo "Usage: start-with-metro.sh <platform> [device]"
  echo "Platform: android, ios, web"
  exit 1
fi

# Source React Native lib
. "${REACT_NATIVE_VIRTENV}/scripts/lib/lib.sh"

echo "🚀 Starting React Native for $PLATFORM..."

# Check if Metro is already running for this platform
if metro.sh status "$PLATFORM" 2>&1 | grep -q "Running"; then
  echo "✓ Metro already running for $PLATFORM"
else
  # Allocate port and start Metro
  echo "📡 Allocating Metro port..."
  metro_port=$(rn_allocate_metro_port "$PLATFORM")
  rn_save_metro_env "$PLATFORM" "$metro_port"

  echo "🎬 Starting Metro bundler on port $metro_port..."
  metro.sh start "$PLATFORM" &
  METRO_PID=$!

  # Wait for Metro to be healthy
  echo "⏳ Waiting for Metro to be ready..."
  max_attempts=30
  attempt=0
  while [ $attempt -lt $max_attempts ]; do
    if metro.sh health "$PLATFORM" "$PLATFORM" 2>/dev/null; then
      echo "✓ Metro is ready"
      break
    fi
    attempt=$((attempt + 1))
    sleep 2
  done

  if [ $attempt -ge $max_attempts ]; then
    echo "✗ Metro failed to start within timeout"
    kill $METRO_PID 2>/dev/null || true
    exit 1
  fi
fi

# Source Metro environment
. "${REACT_NATIVE_VIRTENV}/metro/env-${PLATFORM}.sh"

# Deploy based on platform
case "$PLATFORM" in
  android)
    echo "📲 Deploying to Android..."
    if [ -n "$DEVICE" ]; then
      # Start specific device
      android.sh emulator start "$DEVICE"
    fi
    npx react-native run-android --no-packager
    echo "✓ Android app deployed on port $METRO_PORT"
    ;;

  ios)
    echo "📲 Deploying to iOS..."
    if [ -n "$DEVICE" ]; then
      # Start specific device
      ios.sh simulator start "$DEVICE"
    fi
    npx react-native run-ios --no-packager
    echo "✓ iOS app deployed on port $METRO_PORT"
    ;;

  web)
    echo "🌐 Opening web browser..."
    # Create web build directory
    mkdir -p web/build

    # Open default browser
    if command -v open >/dev/null 2>&1; then
      open "http://localhost:$METRO_PORT"
    elif command -v xdg-open >/dev/null 2>&1; then
      xdg-open "http://localhost:$METRO_PORT"
    elif command -v start >/dev/null 2>&1; then
      start "http://localhost:$METRO_PORT"
    else
      echo "⚠ Could not detect browser launcher"
      echo "   Please open: http://localhost:$METRO_PORT"
    fi
    echo "✓ Browser opened to http://localhost:$METRO_PORT"
    ;;

  *)
    echo "✗ Unknown platform: $PLATFORM"
    echo "   Supported: android, ios, web"
    exit 1
    ;;
esac

echo ""
echo "✓ React Native $PLATFORM is running!"
echo "  Metro port: $METRO_PORT"
echo ""
echo "To stop Metro:"
echo "  metro.sh stop $PLATFORM"
