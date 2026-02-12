#!/usr/bin/env bash
# External wrapper script to run iOS tests with Android SDK evaluation skipped
# Run this from the react-native example directory: ./tests/run-ios-tests.sh

set -e

cd "$(dirname "$0")/.."

# Skip Android SDK downloads/evaluation for iOS-only testing
export ANDROID_SKIP_DOWNLOADS=1

# Run devbox with the iOS test suite - the env var is now set before devbox init hooks run
exec devbox run --pure bash -c 'process-compose -f tests/test-suite-ios.yaml --no-server --tui="${TEST_TUI:-false}"'
