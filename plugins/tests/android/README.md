# Android Plugin Tests

Unit tests for the Android plugin functionality.

## Running Tests

From the repository root:

```bash
# Run standard Android plugin tests (fast, no emulators)
devbox run test:plugin:android

# Run all tests including emulator tests
devbox run test:plugin:android:all

# Run specific test suites
devbox run test:plugin:android:lib                    # Utility function tests
devbox run test:plugin:android:devices                # Device management tests
devbox run test:plugin:android:emulator-detection     # Emulator detection logic
devbox run test:plugin:android:emulator-modes         # Pure vs normal mode behavior
```

## Test Suites

### test-lib.sh
Tests utility functions from `scripts/lib/lib.sh`:
- JSON parsing
- Path manipulation
- String operations
- Checksum validation

### test-devices.sh
Tests device management from `scripts/user/devices.sh`:
- Device CRUD operations
- Lock file generation
- Device validation
- Configuration management

### test-emulator-detection.sh
Tests emulator detection and matching logic from `scripts/domain/emulator.sh`:
- Finding running emulators by AVD name
- Listing all running emulators
- Checking emulator responsiveness
- Port availability detection
- Cleanup of offline emulators

**Key functions tested:**
- `android_find_running_emulator()` - Find emulator by AVD name
- `android_list_running_emulators()` - List all running emulators
- `android_is_emulator_running()` - Check if serial is running
- `android_cleanup_offline_emulators()` - Clean up stale emulators
- `android_find_available_port()` - Find free port for new emulator

### test-emulator-modes.sh
Demonstrates and tests the behavioral differences between:

**Normal Mode** (default):
- Reuses existing emulator if AVD matches
- Fast iteration for development
- Emulator persists between runs
- May have state from previous runs

**Pure Mode** (TEST_PURE=1):
- Always starts fresh emulator with clean state
- Deterministic testing for CI/CD
- Slower (full boot each time)
- Emulator stopped after test completes

## Emulator Detection

### Why Serial (emulator-5554)?

The emulator serial is the standard identifier because:
- **Unique**: Each emulator instance has a unique serial
- **Required**: All adb commands require it: `adb -s emulator-5554 shell ...`
- **Stable**: Remains constant for the emulator's lifetime
- **Standard**: Used throughout Android tooling

**Not PID because:**
- PIDs can be reused by the OS
- Not portable across systems
- Not recognized by adb

### Detection Flow

```bash
# 1. List running emulators
adb devices
# Output: emulator-5554  device

# 2. Get AVD name from emulator
adb -s emulator-5554 shell getprop ro.boot.qemu.avd_name
# Output: pixel_api30

# 3. Match AVD to find running emulator
android_find_running_emulator "pixel_api30"
# Output: emulator-5554

# 4. Check emulator is responsive
adb -s emulator-5554 shell echo "ping"
# Output: ping
```

### AVD Matching Logic

When starting an emulator in normal mode:

1. **Resolve target AVD**: Determine which AVD to use (from config or default)
2. **Check running emulators**: Query all emulator serials from `adb devices`
3. **Match by AVD name**: For each serial, get its AVD name and compare
4. **Verify responsiveness**: Ensure matched emulator responds to commands
5. **Reuse or start new**: If match found, reuse it; otherwise start new

In pure mode, this matching is skipped and a fresh emulator always starts.

## Test Output

All tests use colored output:
- 🟢 **Green ✓**: Test passed
- 🔴 **Red ✗**: Test failed
- 🟡 **Yellow ⚠**: Warning or skipped test
- 🔵 **Blue**: Informational output

Example:
```
========================================
TEST: Find running emulator
========================================
✓ android_find_running_emulator function exists
✓ Detects running emulator by serial
✓ Finds emulator by AVD name
```

## Integration with E2E Tests

These unit tests complement the E2E tests in `examples/android/tests/`:

**Unit tests** (these files):
- Test individual functions in isolation
- Fast execution (< 1 minute)
- No app building required
- Can run with or without emulators

**E2E tests** (`examples/android/tests/test-suite.yaml`):
- Test complete workflow
- Includes build, emulator, deploy, verify
- Slower (3-5 minutes)
- Requires full Android environment

Run unit tests frequently during development. Run E2E tests before commits/PRs.
