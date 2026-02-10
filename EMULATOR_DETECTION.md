# Emulator Detection & Management Improvements

## Overview

This document summarizes the improvements made to emulator detection, matching logic, and testing capabilities for the Android plugin.

## Why Serial (emulator-5554)?

The emulator serial is the **best way** to identify and reference Android emulators:

### ✓ Advantages
- **Standard**: Used by all Android tooling (adb, Android Studio, etc.)
- **Unique**: Each running emulator has a unique serial (emulator-5554, emulator-5556, etc.)
- **Stable**: Remains constant for the emulator's lifetime
- **Required**: All adb commands need it: `adb -s emulator-5554 shell ...`
- **Discoverable**: Listed by `adb devices`

### ✗ Why Not PID?
- PIDs can be reused by the OS after process termination
- Not recognized by adb or Android tooling
- Not portable across systems
- Requires additional mapping from PID to serial for adb commands

### Serial Format
- Format: `emulator-{PORT}`
- Port is always even: 5554, 5556, 5558, etc.
- Derived from the console port the emulator listens on

## Improved Detection Logic

### 1. Enhanced `android_find_running_emulator()`

**What it does**: Finds a running emulator by AVD name

**Improvements**:
```bash
# Before: Only checked if serial matched pattern
for emulator_serial in $(adb devices | awk 'NR>1 && $1 ~ /^emulator-/{print $1}')

# After: Filters for 'device' state and verifies responsiveness
for emulator_serial in $(adb devices | awk 'NR>1 && $1 ~ /^emulator-/ && $2=="device" {print $1}')
  # ...
  if adb -s "$emulator_serial" shell echo "ping" >/dev/null 2>&1; then
    # Emulator is responsive, use it
  fi
```

**Benefits**:
- Ignores offline/unresponsive emulators
- Ensures adb server is started before checking
- Verifies emulator responds before returning it
- More reliable detection in edge cases

### 2. New `android_list_running_emulators()`

**What it does**: Lists all running emulators with their AVD names

**Usage**:
```bash
$ android_list_running_emulators
emulator-5554:pixel_api30
emulator-5556:medium_phone_api36
```

**Benefits**:
- Quick overview of all running emulators
- Helpful for debugging and development
- Used by test suites to verify state

### 3. New `android_is_emulator_running()`

**What it does**: Checks if a specific serial is running and responsive

**Usage**:
```bash
if android_is_emulator_running "emulator-5554"; then
  echo "Emulator is ready"
fi
```

**Benefits**:
- Single source of truth for emulator state
- Used throughout codebase consistently
- Checks both presence and responsiveness

### 4. Improved `android_cleanup_offline_emulators()`

**What it does**: Cleans up stale and unresponsive emulators

**Improvements**:
```bash
# Before: Only killed offline emulators
adb devices | awk '$2=="offline"' | while read serial; do
  adb -s "$serial" emu kill
done

# After: Also checks for unresponsive "device" state emulators
adb devices | awk '$2=="device"' | while read serial; do
  if ! adb -s "$serial" shell echo "ping" >/dev/null 2>&1; then
    echo "Cleaning up unresponsive emulator: $serial"
    adb -s "$serial" emu kill
  fi
done
```

**Benefits**:
- Catches more edge cases
- Prevents zombie emulators from blocking ports
- Better cleanup before starting new emulators

## AVD Matching Logic

### Normal Mode (Reuse Existing)

When `android.sh emulator start max` is called:

1. **Resolve target AVD name**: Determine which AVD to use (from config or device name)
2. **Clean up stale emulators**: Run `android_cleanup_offline_emulators()`
3. **Check for running emulator**:
   ```bash
   existing_serial=$(android_find_running_emulator "$avd_name")
   if [ -n "$existing_serial" ]; then
     # Reuse this emulator
     return 0
   fi
   ```
4. **If no match, start new emulator** with available port
5. **Wait for boot**: Poll for `sys.boot_completed == 1`
6. **Write serial**: Save to `/tmp/android-emulator-serial.txt`

### Pure Mode (Fresh Instance)

When `ANDROID_EMULATOR_PURE=1` is set:

1. **Skip reuse check**: Always start fresh
2. **Start with `--wipe-data`**: Clean state every time
3. **Wait for boot**: Same as normal mode
4. **Cleanup after test**: Emulator killed when test completes

## Serial File Tracking

### Location
`/tmp/android-emulator-serial.txt`

### Purpose
- Communicates emulator serial between processes
- Used by test suites to reference the emulator
- Written by `android_start_emulator()`
- Read by test-suite.yaml processes

### Lifecycle
1. **Created**: When emulator starts successfully
2. **Contains**: Just the serial, e.g., `emulator-5554`
3. **Used**: By deploy-app and other processes
4. **Cleaned**: When emulator stops (pure mode only)

### Error Handling
The improved test-suite.yaml now:
- Checks if the file exists before reading
- Validates the emulator is still running
- Provides clear error messages if serial is stale

## Test Suites

### New Tests

#### test-emulator-detection.sh
**Purpose**: Unit tests for detection functions

**Tests**:
- `android_find_running_emulator()` - Find by AVD name
- `android_list_running_emulators()` - List all
- `android_is_emulator_running()` - Check serial
- `android_find_available_port()` - Port allocation
- `android_cleanup_offline_emulators()` - Cleanup logic

**Run**: `devbox run test:plugin:android:emulator-detection`

#### test-emulator-modes.sh
**Purpose**: Demonstrate pure vs normal mode behavior

**Shows**:
- When emulators are reused vs created fresh
- How AVD matching works
- Why serial is used for identification
- Cleanup behavior differences
- When to use each mode

**Run**: `devbox run test:plugin:android:emulator-modes`

### Benefits
- **Fast feedback**: Tests run in < 1 minute
- **Isolated**: Can run without full e2e setup
- **Educational**: Documents expected behavior
- **Regression prevention**: Catches detection bugs early

## Usage Examples

### Check Running Emulators
```bash
# List all with AVD names
android_list_running_emulators

# Check specific serial
if android_is_emulator_running "emulator-5554"; then
  echo "Ready"
fi

# Find by AVD name
serial=$(android_find_running_emulator "pixel_api30")
if [ -n "$serial" ]; then
  echo "Found: $serial"
fi
```

### Start Emulator (Normal Mode)
```bash
# Reuses existing if AVD matches
devbox run start:emu max
```

### Start Emulator (Pure Mode)
```bash
# Always creates fresh instance
ANDROID_EMULATOR_PURE=1 devbox run start:emu max
```

### E2E Tests
```bash
# Development (fast, reuses emulator)
devbox run test:e2e

# CI/CD (deterministic, clean state)
TEST_PURE=1 devbox run test:e2e
```

## Error Handling Improvements

### Before
```bash
# Could fail silently if serial file missing
export ANDROID_SERIAL=$(cat /tmp/android-emulator-serial.txt)
```

### After
```bash
if android.sh emulator start --pure max; then
  if [ -f /tmp/android-emulator-serial.txt ]; then
    export ANDROID_SERIAL=$(cat /tmp/android-emulator-serial.txt)
  else
    echo "ERROR: Emulator start succeeded but serial file not found"
    exit 1
  fi
else
  echo "ERROR: Failed to start Android emulator"
  exit 1
fi
```

### Device Wait Timeout
```bash
# Before: Could hang indefinitely
adb -s "$emulator_serial" wait-for-device

# After: Times out after 3 minutes
device_wait_seconds=0
while ! adb -s "$emulator_serial" get-state >/dev/null 2>&1; do
  if [ "$device_wait_seconds" -ge 180 ]; then
    echo "ERROR: Device did not appear"
    return 1
  fi
  sleep 2
  device_wait_seconds=$((device_wait_seconds + 2))
done
```

## Summary

### Key Improvements
1. ✅ Serial-based identification confirmed as best practice
2. ✅ Robust detection logic with responsiveness checks
3. ✅ Better cleanup of stale/offline emulators
4. ✅ Clear AVD matching algorithm
5. ✅ Comprehensive unit tests for detection logic
6. ✅ Educational test demonstrating mode differences
7. ✅ Improved error handling and timeouts
8. ✅ Better documentation of behavior

### When to Use Each Mode

**Normal Mode** - Development:
- Fast iteration
- Reuses running emulator
- Good for local testing
- `devbox run test:e2e`

**Pure Mode** - CI/CD:
- Deterministic results
- Clean state guarantee
- Slower but reliable
- `TEST_PURE=1 devbox run test:e2e`

### Testing
```bash
# Run all Android plugin tests
devbox run test:plugin:android

# Run specific detection tests
devbox run test:plugin:android:emulator-detection
devbox run test:plugin:android:emulator-modes
```
