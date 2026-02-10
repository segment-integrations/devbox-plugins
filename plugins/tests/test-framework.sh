#!/usr/bin/env bash
set -euo pipefail

TEST_PASS=0
TEST_FAIL=0

assert_equal() {
  local expected="$1"
  local actual="$2"
  local message="${3:-}"

  if [ "$expected" = "$actual" ]; then
    TEST_PASS=$((TEST_PASS + 1))
    echo "✓ ${message}"
  else
    TEST_FAIL=$((TEST_FAIL + 1))
    echo "✗ ${message}"
    echo "  Expected: $expected"
    echo "  Actual: $actual"
  fi
}

assert_file_exists() {
  local file="$1"
  local message="${2:-File exists: $file}"

  if [ -f "$file" ]; then
    TEST_PASS=$((TEST_PASS + 1))
    echo "✓ ${message}"
  else
    TEST_FAIL=$((TEST_FAIL + 1))
    echo "✗ ${message}"
  fi
}

assert_file_contains() {
  local file="$1"
  local pattern="$2"
  local message="${3:-File contains pattern: $pattern}"

  if [ -f "$file" ] && grep -q "$pattern" "$file"; then
    TEST_PASS=$((TEST_PASS + 1))
    echo "✓ ${message}"
  else
    TEST_FAIL=$((TEST_FAIL + 1))
    echo "✗ ${message}"
  fi
}

assert_command_success() {
  local message="$1"
  shift

  if "$@" >/dev/null 2>&1; then
    TEST_PASS=$((TEST_PASS + 1))
    echo "✓ ${message}"
  else
    TEST_FAIL=$((TEST_FAIL + 1))
    echo "✗ ${message}"
    echo "  Command failed: $*"
  fi
}

test_summary() {
  local suite_name="${1:-unknown}"
  local total=$((TEST_PASS + TEST_FAIL))

  echo ""
  echo "===================================="
  echo "Test Results:"
  echo "  Passed: $TEST_PASS"
  echo "  Failed: $TEST_FAIL"
  echo "===================================="

  # Write results file for summary aggregation
  # Find repo root first
  # Use BASH_SOURCE[0] instead of $0 to work correctly when sourced
  local repo_root="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && while [ ! -f "devbox.json" ] && [ "$(pwd)" != "/" ]; do cd ..; done; pwd)}"

  # If TEST_RESULTS_DIR is set, use it; otherwise default to repo_root/reports/results
  local results_dir="${TEST_RESULTS_DIR:-$repo_root/reports/results}"

  # If results_dir is relative, make it absolute by prepending repo_root
  if [[ ! "$results_dir" = /* ]]; then
    results_dir="$repo_root/$results_dir"
  fi

  mkdir -p "$results_dir" || {
    echo "Warning: Could not create results directory: $results_dir" >&2
    return 0
  }

  cat > "$results_dir/${suite_name}.json" << EOF
{
  "suite": "${suite_name}",
  "passed": ${TEST_PASS},
  "failed": ${TEST_FAIL},
  "total": ${total}
}
EOF

  if [ "$TEST_FAIL" -gt 0 ]; then
    exit 1
  fi
}
