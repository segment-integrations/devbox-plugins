#!/usr/bin/env bash
set -euo pipefail

echo "iOS Device Management Integration Tests"
echo "========================================"
echo ""

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$SCRIPT_DIR/../../.."

# Source test framework
. "$REPO_ROOT/plugins/tests/test-framework.sh"

# Setup test environment
TEST_ROOT="/tmp/ios-integration-test-$$"
mkdir -p "$TEST_ROOT/devbox.d/ios/devices"
mkdir -p "$TEST_ROOT/devbox.d/ios/scripts"

# Copy fixtures
cp "$SCRIPT_DIR/../../fixtures/ios/devices/"*.json "$TEST_ROOT/devbox.d/ios/devices/"

# Copy plugin scripts (layered structure)
cp -r "$REPO_ROOT/plugins/ios/scripts/"* "$TEST_ROOT/devbox.d/ios/scripts/"
find "$TEST_ROOT/devbox.d/ios/scripts" -name "*.sh" -type f -exec chmod +x {} \;

# Set environment for tests
export IOS_CONFIG_DIR="$TEST_ROOT/devbox.d/ios"
export IOS_DEVICES_DIR="$TEST_ROOT/devbox.d/ios/devices"
export IOS_SCRIPTS_DIR="$TEST_ROOT/devbox.d/ios/scripts"
export IOS_DEVICES=""  # All devices

cd "$TEST_ROOT"

# Test 1: Device list command
echo "Test: Device listing..."
if sh "$IOS_SCRIPTS_DIR/user/devices.sh" list >/dev/null 2>&1; then
  TEST_PASS=$((TEST_PASS + 1))
  echo "✓ Device list command succeeds"
else
  TEST_FAIL=$((TEST_FAIL + 1))
  echo "✗ Device list command failed"
fi

# Test 2: Lock file evaluation
echo "Test: Lock file evaluation..."
if sh "$IOS_SCRIPTS_DIR/user/devices.sh" eval >/dev/null 2>&1; then
  assert_file_exists "$IOS_DEVICES_DIR/devices.lock" "Lock file created after eval"
else
  echo "✗ Device eval command failed"
  TEST_FAIL=$((TEST_FAIL + 1))
fi

# Test 3: Lock file structure
echo "Test: Lock file structure..."
if [ -f "$IOS_DEVICES_DIR/devices.lock" ]; then
  # Lock file should be valid JSON with devices array
  if jq -e '.devices' "$IOS_DEVICES_DIR/devices.lock" >/dev/null 2>&1; then
    TEST_PASS=$((TEST_PASS + 1))
    echo "✓ Lock file has valid structure"
  else
    TEST_FAIL=$((TEST_FAIL + 1))
    echo "✗ Lock file has invalid format"
  fi
else
  TEST_FAIL=$((TEST_FAIL + 1))
  echo "✗ Lock file not found"
fi

# Test 4: Device count matches fixture count
echo "Test: Device count validation..."
device_count=$(jq '.devices | length' "$IOS_DEVICES_DIR/devices.lock")
expected_count=$(ls -1 "$IOS_DEVICES_DIR"/*.json | wc -l | tr -d ' ')
if [ "$device_count" = "$expected_count" ]; then
  TEST_PASS=$((TEST_PASS + 1))
  echo "✓ All devices included in lock file ($device_count devices)"
else
  TEST_FAIL=$((TEST_FAIL + 1))
  echo "✗ Device count mismatch (expected $expected_count, got $device_count)"
fi

# Cleanup
cd /
rm -rf "$TEST_ROOT"

test_summary
