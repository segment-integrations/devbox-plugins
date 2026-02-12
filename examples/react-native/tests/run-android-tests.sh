#!/usr/bin/env bash
# External wrapper script to run Android tests with iOS setup skipped
# Run this from the react-native example directory: ./tests/run-android-tests.sh

set -e

cd "$(dirname "$0")/.."

# Skip iOS setup for Android-only testing
export IOS_SKIP_SETUP=1

# Run devbox with the Android test suite - the env var is now set before devbox init hooks run
exec devbox run --pure bash -c 'process-compose -f tests/test-suite-android.yaml --no-server --tui="${TEST_TUI:-false}"'
