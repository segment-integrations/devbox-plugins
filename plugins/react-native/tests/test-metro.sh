#!/usr/bin/env bash
# Integration test for metro.sh CLI
# Tests port allocation, environment files, and lifecycle management

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEST_SUITE_NAME="test-metro-$$"
FAILED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test utilities
pass() {
  echo -e "${GREEN}✓${NC} $1"
}

fail() {
  echo -e "${RED}✗${NC} $1"
  FAILED=1
}

info() {
  echo -e "${YELLOW}→${NC} $1"
}

cleanup_test() {
  info "Cleaning up test suite: $TEST_SUITE_NAME"

  # Kill Metro if it's running
  if [ -f "${REACT_NATIVE_VIRTENV}/metro/env-${TEST_SUITE_NAME}.sh" ]; then
    . "${REACT_NATIVE_VIRTENV}/metro/env-${TEST_SUITE_NAME}.sh" 2>/dev/null || true
    if [ -n "${METRO_PORT:-}" ]; then
      metro_pid=$(lsof -ti:"${METRO_PORT}" 2>/dev/null || true)
      if [ -n "$metro_pid" ]; then
        kill -9 "$metro_pid" 2>/dev/null || true
      fi
    fi
  fi

  # Clean up state files
  metro.sh clean "$TEST_SUITE_NAME" 2>/dev/null || true
}

# Trap cleanup on exit
trap cleanup_test EXIT

echo "========================================"
echo "Metro.sh Integration Test"
echo "========================================"
echo ""

# Clean up any previous test state before starting
metro.sh clean "$TEST_SUITE_NAME" 2>/dev/null || true

# Test 1: Port Allocation
info "Test 1: Port allocation"
status_output=$(metro.sh status "$TEST_SUITE_NAME" 2>&1 || true)
if echo "$status_output" | grep -q "No Metro configuration"; then
  pass "Status correctly reports no configuration"
else
  fail "Status should report no configuration before allocation"
fi

# Source lib to use internal functions
. "${REACT_NATIVE_VIRTENV}/scripts/lib/lib.sh"

# Allocate a port
allocated_port=$(rn_allocate_metro_port "$TEST_SUITE_NAME")
if [ -n "$allocated_port" ] && [ "$allocated_port" -ge 8091 ] && [ "$allocated_port" -le 8199 ]; then
  pass "Port allocated in correct range: $allocated_port"
else
  fail "Port allocation failed or out of range: $allocated_port"
fi

# Test 2: Environment File Creation
info "Test 2: Environment file creation"
env_file=$(rn_save_metro_env "$TEST_SUITE_NAME" "$allocated_port")
if [ -f "$env_file" ]; then
  pass "Environment file created: $env_file"

  # Verify symlink
  symlink="${REACT_NATIVE_VIRTENV}/metro/env-${TEST_SUITE_NAME}.sh"
  if [ -L "$symlink" ]; then
    pass "Symlink created: $symlink"
  else
    fail "Symlink not created"
  fi

  # Verify content
  . "$env_file"
  if [ "$METRO_PORT" = "$allocated_port" ]; then
    pass "Environment file has correct port: $METRO_PORT"
  else
    fail "Environment file has wrong port: $METRO_PORT (expected $allocated_port)"
  fi
else
  fail "Environment file not created"
fi

# Test 3: Unique Run IDs
info "Test 3: Unique run ID generation"
run_id=$(rn_get_run_id "$TEST_SUITE_NAME")
if [[ "$run_id" =~ ^[0-9]+-[0-9]+$ ]]; then
  pass "Run ID has correct format: $run_id"
else
  fail "Run ID has wrong format: $run_id"
fi

# Verify unique file naming
port_file="${REACT_NATIVE_VIRTENV}/metro/port-${TEST_SUITE_NAME}-${run_id}.txt"
if [ -f "$port_file" ]; then
  pass "Port file uses unique ID: $(basename "$port_file")"
else
  fail "Port file not found: $port_file"
fi

# Test 4: Status Command
info "Test 4: Status command (without Metro running)"
status_output=$(metro.sh status "$TEST_SUITE_NAME" 2>&1 || true)
if echo "$status_output" | grep -q "Status: Not running"; then
  pass "Status correctly reports Metro not running"
else
  fail "Status should report Metro not running"
fi

# Test 5: Metro Start/Stop (requires Node.js and React Native)
info "Test 5: Metro lifecycle (background mode)"

# Start Metro in background with a timeout
info "  Starting Metro in background..."
timeout 10s metro.sh start "$TEST_SUITE_NAME" >/dev/null 2>&1 &
METRO_PID=$!

# Wait for Metro to be ready (or timeout)
sleep 3

# Check if Metro is running on the allocated port
if lsof -ti:"$allocated_port" >/dev/null 2>&1; then
  pass "Metro started successfully on port $allocated_port"

  # Test status command with Metro running
  status_output=$(metro.sh status "$TEST_SUITE_NAME" 2>&1)
  if echo "$status_output" | grep -q "Status: Running"; then
    pass "Status correctly reports Metro running"
  else
    fail "Status should report Metro running"
  fi
else
  fail "Metro did not start on port $allocated_port"
fi

# Test 6: Stop Command
info "Test 6: Stop command"
metro.sh stop "$TEST_SUITE_NAME"
sleep 2

if ! lsof -ti:"$allocated_port" >/dev/null 2>&1; then
  pass "Metro stopped successfully"
else
  fail "Metro still running after stop command"
fi

# Ensure background process is killed
kill -9 $METRO_PID 2>/dev/null || true

# Test 7: Parallel Test Isolation (before cleanup)
info "Test 7: Parallel test isolation"
TEST_SUITE_2="test-metro-parallel-$$"

# Start Metro for first suite again (to hold the port)
info "  Starting Metro for first suite on port $allocated_port..."
timeout 10s metro.sh start "$TEST_SUITE_NAME" >/dev/null 2>&1 &
METRO_PID_1=$!
sleep 3

# Allocate and start Metro for second suite
port2=$(rn_allocate_metro_port "$TEST_SUITE_2")
rn_save_metro_env "$TEST_SUITE_2" "$port2"

info "  Starting Metro for second suite on port $port2..."
timeout 10s metro.sh start "$TEST_SUITE_2" >/dev/null 2>&1 &
METRO_PID_2=$!
sleep 3

if [ "$allocated_port" != "$port2" ]; then
  pass "Different suites get different ports: $allocated_port vs $port2"

  # Verify both Metros are actually running
  if lsof -ti:"$allocated_port" >/dev/null 2>&1 && lsof -ti:"$port2" >/dev/null 2>&1; then
    pass "Both Metro instances running simultaneously"
  else
    fail "Not all Metro instances started"
  fi
else
  fail "Different suites got same port: $allocated_port"
fi

# Stop both Metros
kill -9 $METRO_PID_1 $METRO_PID_2 2>/dev/null || true
metro.sh stop "$TEST_SUITE_NAME" 2>/dev/null || true
metro.sh stop "$TEST_SUITE_2" 2>/dev/null || true
sleep 2

# Clean up second suite
metro.sh clean "$TEST_SUITE_2"

# Test 8: Clean Command
info "Test 8: Clean command"
metro.sh clean "$TEST_SUITE_NAME"

# Verify all files removed
if [ ! -f "$env_file" ] && [ ! -L "$symlink" ]; then
  pass "All state files cleaned up"
else
  fail "State files not cleaned up properly"
fi

echo ""
echo "========================================"
if [ $FAILED -eq 0 ]; then
  echo -e "${GREEN}All tests passed!${NC}"
  echo "========================================"
  exit 0
else
  echo -e "${RED}Some tests failed!${NC}"
  echo "========================================"
  exit 1
fi
