# E2E Tests - Use CLI Commands Instead of Internal Functions ✅

**Date:** February 9, 2026
**Status:** ✅ FIXED
**Issue:** Android E2E tests were calling internal functions instead of CLI commands

## Issue Found

**Problem:** Android E2E test process-compose file was trying to:
1. Source internal script files that had been moved/renamed
2. Call internal shell functions directly
3. Use internal implementation details instead of public CLI

**Error Messages:**
```
[cleanup] bash: line 3: .devbox/virtenv/android/scripts/env.sh: No such file or directory
[cleanup] bash: line 6: android_stop_emulator: command not found
```

**Root Cause:** After the layered architecture refactor:
- `env.sh` was renamed to `init/setup.sh`
- Internal functions like `android_start_emulator`, `android_stop_emulator`, `android_deploy_app` aren't meant to be called directly from E2E tests
- Tests should use the public CLI commands exposed in plugin.json

## Fix Applied

Updated Android E2E process-compose to use CLI commands:

### 1. Start Emulator

**Before (BROKEN):**
```yaml
android-emulator:
  command: |
    cd examples/android
    echo "Starting Android emulator..."
    . .devbox/virtenv/android/scripts/env.sh
    android_start_emulator
    while pkill -0 qemu-system 2>/dev/null || pgrep -f emulator 2>/dev/null; do
      sleep 5
    done
```

**After (FIXED):**
```yaml
android-emulator:
  command: |
    cd examples/android
    echo "Starting Android emulator..."
    devbox run start:emu
    while pkill -0 qemu-system 2>/dev/null || pgrep -f emulator 2>/dev/null; do
      sleep 5
    done
```

**Change:** Use `devbox run start:emu` CLI command instead of sourcing env.sh and calling internal function.

---

### 2. Deploy App

**Before (BROKEN):**
```yaml
deploy-app:
  command: |
    cd examples/android
    echo "Deploying app to emulator..."
    . .devbox/virtenv/android/scripts/env.sh
    android_deploy_app
```

**After (FIXED):**
```yaml
deploy-app:
  command: |
    cd examples/android
    echo "Deploying app to emulator..."
    devbox run android.sh deploy
```

**Change:** Use `devbox run android.sh deploy` CLI command instead of internal function.

---

### 3. Stop Emulator (Cleanup)

**Before (BROKEN):**
```yaml
cleanup:
  command: |
    cd examples/android
    echo "Cleaning up..."
    . .devbox/virtenv/android/scripts/env.sh || true
    android_stop_emulator || true
    pkill -9 qemu-system 2>/dev/null || true
    pkill -9 emulator 2>/dev/null || true
    adb kill-server 2>/dev/null || true
    echo "✓ Cleanup complete"
```

**After (FIXED):**
```yaml
cleanup:
  command: |
    cd examples/android
    echo "Cleaning up..."
    devbox run stop:emu || true
    pkill -9 qemu-system 2>/dev/null || true
    pkill -9 emulator 2>/dev/null || true
    adb kill-server 2>/dev/null || true
    echo "✓ Cleanup complete"
```

**Change:** Use `devbox run stop:emu` CLI command instead of internal function.

---

### 4. Readiness Probes

**Before (BROKEN):**
```yaml
readiness_probe:
  exec:
    command: "cd examples/android && . .devbox/virtenv/android/scripts/env.sh && adb wait-for-device shell 'getprop sys.boot_completed 2>/dev/null' | grep -q 1"
```

**After (FIXED):**
```yaml
readiness_probe:
  exec:
    command: "adb wait-for-device shell 'getprop sys.boot_completed 2>/dev/null' | grep -q 1"
```

**Change:** Removed unnecessary sourcing of env.sh - adb is already in PATH from devbox environment.

---

### 5. Verify App Section

**Before (BROKEN):**
```yaml
verify-app:
  command: |
    cd examples/android
    echo "Verifying app is running..."
    . .devbox/virtenv/android/scripts/env.sh
    if adb shell pm list packages | grep -q ${ANDROID_APP_ID}; then
      ...
```

**After (FIXED):**
```yaml
verify-app:
  command: |
    cd examples/android
    echo "Verifying app is running..."
    if adb shell pm list packages | grep -q ${ANDROID_APP_ID}; then
      ...
```

**Change:** Removed unnecessary sourcing of env.sh - adb is already available.

---

## CLI Commands Used

All commands are defined in `plugins/android/plugin.json`:

| CLI Command | Purpose | Maps To |
|-------------|---------|---------|
| `devbox run start:emu` | Start Android emulator | `android.sh emulator start` |
| `devbox run stop:emu` | Stop Android emulator | `android.sh emulator stop` |
| `devbox run android.sh deploy` | Deploy app to emulator | Internal deploy script |

**Why These Work:**
- Commands are defined in plugin.json shell.scripts section
- They properly source all required dependencies internally
- They provide stable public API that won't break with refactoring
- They work from any devbox shell context

## Why This Pattern Is Better

### Before (Internal Functions)
❌ **Fragile:**
- Tests break when internal scripts are moved/renamed
- Tests need to know internal file structure
- Tests depend on internal implementation details
- Sourcing env.sh may not load all required dependencies

### After (CLI Commands)
✅ **Robust:**
- Tests use stable public API
- Tests don't care about internal structure
- Plugin can refactor internals without breaking tests
- CLI commands handle all dependency loading

## Files Modified

**Modified (1 file):**
1. `tests/e2e/process-compose-android.yaml` - Updated 5 sections to use CLI commands:
   - android-emulator (line 76)
   - android-emulator readiness probe (line 92)
   - deploy-app (line 103)
   - deploy-app readiness probe (line 114)
   - verify-app (removed env.sh sourcing, line 125)
   - cleanup (line 154)

**Other E2E Files:**
- ✅ `tests/e2e/process-compose-ios.yaml` - Already using CLI commands
- ✅ `tests/e2e/process-compose-react-native.yaml` - Already using CLI commands (fixed earlier)

**Created (1 file):**
1. `summaries/e2e-cli-command-fixes.md` - This document

## Verification

### Quick Test
```bash
# Verify CLI commands are available
cd examples/android
devbox run --list | grep -E "start:emu|stop:emu|deploy"

# Should show:
# - start:emu
# - stop:emu
# - android.sh deploy (via main script)
```

### Full E2E Test
```bash
# Run Android E2E test
devbox run test:e2e:android

# Expected behavior:
# - Starts emulator using CLI command
# - Builds and deploys app using CLI command
# - Verifies app installation
# - Stops emulator using CLI command
```

## Pattern for Future E2E Tests

**Always use CLI commands in E2E tests:**

✅ **DO:**
```yaml
command: |
  cd examples/platform
  devbox run start:emu
  devbox run android.sh deploy
  devbox run stop:emu
```

❌ **DON'T:**
```yaml
command: |
  cd examples/platform
  . .devbox/virtenv/android/scripts/env.sh
  android_start_emulator
  android_deploy_app
  android_stop_emulator
```

**Why:**
- CLI commands are the stable public API
- Internal functions/scripts can change during refactoring
- CLI commands handle all dependency loading
- Tests remain decoupled from implementation

## Breaking Changes

**None.** This fix restores E2E test functionality that was broken by the layered architecture refactor.

## Related Documents

**E2E Test Fixes:**
- `summaries/e2e-test-fixes.md` - Working directory and sequential execution fixes
- `summaries/e2e-cli-command-fixes.md` - This document (CLI command usage)

**Phase 1 Complete:**
- `summaries/phase1-final-summary.md` - Complete Phase 1 overview
- `summaries/final-test-fixes.md` - Lint and unit test fixes
- `summaries/react-native-compatibility-fixes.md` - RN compatibility

## Summary

✅ **Android E2E Tests Now Use CLI Commands**

**Changes:**
1. ✅ Replaced internal function calls with CLI commands
2. ✅ Removed references to moved/renamed script files
3. ✅ Simplified readiness probes (adb already in PATH)
4. ✅ Made tests resilient to internal refactoring

**Test Stability:**
- E2E tests now use stable public API
- Tests won't break with future internal refactoring
- Consistent pattern across all E2E tests (Android, iOS, React Native)

**Status:** Android E2E tests ready for execution.
