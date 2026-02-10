#!/usr/bin/env bash
# Utility to write test results in a standard format

write_test_result() {
  local suite_name="$1"
  local passed="$2"
  local failed="$3"
  local details="${4:-}"

  local test_results_dir="${TEST_RESULTS_DIR:-reports/results}"
  mkdir -p "$test_results_dir"

  cat > "$test_results_dir/${suite_name}.json" << JSONEOF
{
  "suite": "${suite_name}",
  "passed": ${passed},
  "failed": ${failed},
  "details": "${details}",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
JSONEOF
}
