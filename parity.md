# iOS/Android Plugin Parity Analysis

**Last Updated:** 2026-02-10
**Status:** Initial comprehensive review completed

This document tracks parity between the iOS and Android plugins, identifying gaps, inconsistencies, and maintaining an implementation plan to bring both plugins to feature parity where appropriate.

## Executive Summary

| Category | Android Status | iOS Status | Priority |
|----------|---------------|-----------|----------|
| Documentation | ✅ Comprehensive (25KB+) | ⚠️ Minimal (12KB) | HIGH |
| Test Coverage | ✅ 4 test suites + docs | ⚠️ 2 suites, no docs | HIGH |
| Plugin Architecture | ✅ Complete | ✅ Complete | ✅ GOOD |
| User Commands | ✅ 6 command groups | ✅ 7 command groups | ✅ GOOD |
| Example Projects | ✅ Comprehensive | ⚠️ Minimal | MEDIUM |
| Lock File Location | ✅ User project | ❌ Plugin config | HIGH |
| Init Hook Structure | ✅ Dual-mode single file | ⚠️ Separate files | LOW |
| Device Schema | ✅ 5 fields | ✅ 2 fields | ✅ GOOD (platform-appropriate) |

---

## Critical Issues (Must Fix)

### 1. Lock File Location Inconsistency ❌ BLOCKER

**Android:** `examples/android/devbox.d/android/devices/devices.lock` (user project)
**iOS:** `plugins/ios/config/devices/devices.lock` (plugin config)

**Problem:** iOS has a pre-generated lock file in the plugin config directory, which is wrong. Lock files should be generated per-project based on the user's device definitions.

**Impact:** HIGH - Users cannot generate their own lock files properly

**Fix Required:**
- Remove `plugins/ios/config/devices/devices.lock`
- Ensure `ios.sh devices eval` generates lock file in user project directory
- Update iOS example to include generated lock file
- Update documentation

---

## Documentation Gaps

### Missing from iOS

| Document | Android | iOS | Priority |
|----------|---------|-----|----------|
| SCRIPTS.md | ✅ 16KB detailed | ❌ Missing | HIGH |
| README.md examples | ✅ 102 lines | ⚠️ 15 lines | MEDIUM |
| Test README | ✅ 150+ lines | ❌ Missing | MEDIUM |
| Test suite docs | ✅ examples/android/tests/README.md | ❌ Missing | MEDIUM |

**SCRIPTS.md Content Needed:**
- Layer architecture explanation
- Script dependency flow
- How to extend the plugin
- Debugging guide
- Common patterns

**README Expansion Needed:**
- Quick start examples
- Common workflows
- Troubleshooting section
- Links to REFERENCE.md sections

**Test Documentation Needed:**
- What each test validates
- How to run tests
- How to debug test failures
- Test architecture explanation

---

## Test Coverage Gaps

### iOS Missing Tests

| Test Suite | Android | iOS | Priority |
|------------|---------|-----|----------|
| Simulator detection/matching | ✅ test-emulator-detection.sh | ❌ Missing | HIGH |
| Pure vs normal mode behavior | ✅ test-emulator-modes.sh | ❌ Missing | MEDIUM |
| Test documentation | ✅ README.md | ❌ Missing | MEDIUM |
| Test suite variants | ✅ 2 variants (main + emulator-only) | ⚠️ 1 variant | LOW |

**Simulator Detection Tests Needed:**
- Device name resolution
- Runtime availability checking
- UDID lookup and matching
- Simulator state detection (booted/shutdown/etc)
- Multiple simulator handling

**Pure Mode Tests Needed:**
- Clean simulator creation in pure mode
- Simulator reuse in normal mode
- Cleanup behavior verification
- `IOS_SIMULATOR_PURE` flag testing

---

## Plugin Configuration Analysis

### Environment Variables

**Android:** 27 variables (SDK-focused)
**iOS:** 9 variables (Xcode-focused)

### Android-Only Variables (Not Applicable to iOS)
- `ANDROID_COMPILE_SDK`, `ANDROID_TARGET_SDK`
- `ANDROID_BUILD_TOOLS_VERSION`, `ANDROID_CMDLINE_TOOLS_VERSION`
- `ANDROID_INCLUDE_NDK`, `ANDROID_NDK_VERSION`
- `ANDROID_INCLUDE_CMAKE`, `ANDROID_CMAKE_VERSION`
- `ANDROID_SYSTEM_IMAGE_TAG`
- **Reason:** Android requires explicit SDK version configuration; iOS uses Xcode

### iOS-Only Variables (Not Applicable to Android)
- `IOS_DEVELOPER_DIR` (Xcode path)
- `IOS_XCODE_ENV_PATH` (cached Xcode environment)
- `IOS_DOWNLOAD_RUNTIME` (auto-download runtimes)
- **Reason:** iOS requires Xcode discovery; Android uses Nix-provided SDK

### Shared Patterns
Both have:
- Device filtering: `ANDROID_DEVICES` / `IOS_DEVICES`
- Default device: `ANDROID_DEFAULT_DEVICE` / `IOS_DEFAULT_DEVICE`
- App configuration: `*_APP_*` variables
- Pure mode flags: `ANDROID_EMULATOR_PURE` / `IOS_SIMULATOR_PURE`

**Assessment:** ✅ Variable counts are different but appropriately reflect platform needs

---

## Script Organization Comparison

### Domain Layer (Layer 3) Differences

| Concern | Android Scripts | iOS Scripts | Notes |
|---------|----------------|-------------|-------|
| Device Management | `avd.sh` | `device_manager.sh` | ✅ Different names, same purpose |
| Device Reset | `avd-reset.sh` | *(part of simulator.sh)* | ⚠️ Android has dedicated script |
| Emulator/Simulator | `emulator.sh` | `simulator.sh` | ✅ Equivalent |
| Deployment | `run.sh` | `deploy.sh` | ✅ Equivalent |
| Validation | `validate.sh` | `validate.sh` | ✅ Same |

**Android Advantage:** Dedicated `avd-reset.sh` for state management
**iOS Advantage:** Combined device management reduces script count

### User Layer (Layer 4) Differences

| Script | Android | iOS | Notes |
|--------|---------|-----|-------|
| Main CLI | `android.sh` | `ios.sh` | ✅ Equivalent |
| Device CLI | `devices.sh` | `devices.sh` | ✅ Equivalent |
| Config CLI | ❌ Missing | ✅ `config.sh` | ⚠️ iOS has explicit config mgmt |

**iOS Advantage:** Explicit configuration management commands

---

## User-Facing Commands

### Android (`android.sh`)
```bash
android.sh devices <command>     # Device management
android.sh info                  # Show SDK info
android.sh emulator start        # Start emulator
android.sh emulator stop         # Stop emulator
android.sh emulator reset        # Reset all AVDs
android.sh run [apk] [device]    # Build, install, launch
```

### iOS (`ios.sh`)
```bash
ios.sh devices <command>         # Device management
ios.sh info                      # Show configuration
ios.sh simulator start [device]  # Start simulator
ios.sh simulator stop            # Stop simulator
ios.sh config show               # Show configuration
ios.sh config set key=value      # Set config value
ios.sh config reset              # Reset configuration
```

### Comparison

| Feature | Android | iOS | Recommendation |
|---------|---------|-----|----------------|
| Device mgmt | ✅ | ✅ | ✅ Equivalent |
| Info/config display | ✅ `info` | ✅ `info` + `config show` | Consider adding `config` to Android |
| Start emulator/sim | ✅ | ✅ | ✅ Equivalent |
| Stop emulator/sim | ✅ | ✅ | ✅ Equivalent |
| Reset/clean state | ✅ `emulator reset` | ⚠️ (manual) | Consider adding `simulator reset` to iOS |
| Build+deploy | ✅ `run` | ❌ (use devbox scripts) | ⚠️ iOS missing convenience command |
| Config management | ❌ | ✅ `config set/reset` | Consider adding to Android |

---

## Initialization Differences

### Android: Single Dual-Mode Script
**File:** `virtenv/scripts/init/setup.sh`

**Execution Mode:** Generates config files
- Creates `android.json` (SDK configuration for Nix flake)
- Generates `devices.lock` (device checksum file)

**Sourced Mode:** Environment initialization
- Sets `ANDROID_SDK_ROOT`, `ANDROID_HOME`, etc.
- Validates SDK availability

### iOS: Separate Hook Scripts
**Files:**
- `virtenv/scripts/init/init-hook.sh` (config generation)
- `virtenv/scripts/init/setup.sh` (environment initialization)

**init-hook.sh:**
- Generates `devices.lock` from `IOS_DEVICES` env var
- Pre-init hook (runs before shell)

**setup.sh:**
- Environment initialization
- Xcode path discovery and caching
- Sets `DEVELOPER_DIR`, `SDKROOT`, etc.

### Assessment

| Aspect | Android | iOS | Recommendation |
|--------|---------|-----|----------------|
| Separation of concerns | ⚠️ Mixed in one file | ✅ Clear separation | iOS pattern is cleaner |
| Maintainability | ⚠️ Harder to understand | ✅ Easier to understand | Adopt iOS pattern |
| Execution flow | ⚠️ Mode detection required | ✅ Clear file purposes | Adopt iOS pattern |

**Recommendation:** Android should adopt iOS's two-file pattern for clarity

---

## Device Schema Differences

### Android Device Definition (5 fields)
```json
{
  "name": "medium_phone_api36",
  "api": 36,
  "device": "medium_phone",
  "tag": "google_apis",
  "preferred_abi": "x86_64"
}
```

**Fields:**
- `name`: User-friendly display name
- `api`: Android API level (required)
- `device`: AVD device profile ID (required)
- `tag`: System image tag (optional, default: "google_apis")
- `preferred_abi`: CPU architecture (optional, default: "x86_64")

### iOS Device Definition (2 fields)
```json
{
  "name": "iPhone 17",
  "runtime": "26.2"
}
```

**Fields:**
- `name`: Simulator device type (required)
- `runtime`: iOS version (required)

### Assessment

✅ **Appropriately Different** - Android requires more granular configuration due to AVD system complexity. iOS simulator configuration is simpler by design.

**No action needed** - schemas reflect platform differences appropriately.

---

## Example Project Comparison

### Android Example Features
```
examples/android/
├── tests/
│   ├── README.md                   ✅ 50+ lines of documentation
│   ├── test-suite.yaml            ✅ Main E2E test
│   ├── test-emulator-only.yaml    ✅ Emulator-only variant
│   └── test-summary.sh            ✅ Test results formatter
├── devbox.json                     ✅ 37 lines with multiple scripts
├── app/                            ✅ Minimal Android app
└── devbox.d/android/devices/
    ├── min.json                    ✅ API 21 device
    ├── max.json                    ✅ API 36 device
    └── devices.lock                ✅ Generated lock file
```

### iOS Example Features
```
examples/ios/
├── tests/
│   ├── test-suite.yaml            ✅ Main E2E test
│   ├── test-summary.sh            ✅ Test results formatter
│   └── (NO README.md)              ❌ Missing documentation
├── devbox.json                     ✅ 42 lines
├── Sources/                        ✅ Swift package
└── devbox.d/ios/devices/
    ├── min.json                    ✅ iOS 15.4 device
    ├── max.json                    ✅ iOS 26.2 device
    └── devices.lock                ✅ Generated lock file
```

### Gaps in iOS Example

| Feature | Android | iOS | Priority |
|---------|---------|-----|----------|
| Test documentation | ✅ README.md | ❌ Missing | MEDIUM |
| Multiple test variants | ✅ 2 YAML files | ⚠️ 1 YAML file | LOW |
| Convenience scripts in devbox.json | ✅ Many aliases | ⚠️ Fewer | LOW |

---

## Dead Code & Variable Analysis

### Potentially Dead Variables

#### Android
**To Investigate:**
- `ANDROID_EMULATOR_FOREGROUND` - Used only in process-compose? Check if needed
- `EVALUATE_DEVICES` - Seems to overlap with `ANDROID_DEVICES`
- `ANDROID_SKIP_CLEANUP` - Documented but verify usage

#### iOS
**To Investigate:**
- `IOS_XCODE_ENV_PATH` - Used for caching? Verify necessity
- `IOS_APP_DERIVED_DATA` - Is this used or should users set it manually?

### Inconsistent Naming

| Concept | Android Naming | iOS Naming | Recommendation |
|---------|---------------|-----------|----------------|
| Device list filter | `ANDROID_DEVICES` | `IOS_DEVICES` | ✅ Consistent |
| Default device | `ANDROID_DEFAULT_DEVICE` | `IOS_DEFAULT_DEVICE` | ✅ Consistent |
| Pure mode flag | `ANDROID_EMULATOR_PURE` | `IOS_SIMULATOR_PURE` | ✅ Consistent |
| Platform term | "emulator" | "simulator" | ✅ Platform-appropriate |
| Device manager script | `avd.sh` | `device_manager.sh` | ⚠️ Consider renaming |
| Deployment script | `run.sh` | `deploy.sh` | ⚠️ Consider standardizing |

**Recommendation:**
- Rename Android's `run.sh` to `deploy.sh` OR
- Rename iOS's `deploy.sh` to `run.sh`
- **Preference:** `deploy.sh` is more descriptive

---

## Unique Platform-Specific Features

### Android-Only (Appropriate)
✅ `flake.nix` - SDK composition via Nix (iOS uses native Xcode)
✅ `ANDROID_INCLUDE_NDK`, `ANDROID_INCLUDE_CMAKE` - SDK build tool options
✅ `ANDROID_BUILD_TOOLS_VERSION` - Explicit version control
✅ `ANDROID_SYSTEM_IMAGE_TAG` - System image selection
✅ Emulator port detection and management
✅ AVD device profile specification

### iOS-Only (Appropriate)
✅ `IOS_DEVELOPER_DIR` - Xcode path discovery
✅ `IOS_DOWNLOAD_RUNTIME` - Auto-download missing runtimes
✅ `config.sh` - Runtime configuration management
✅ Xcode environment caching (`.xcode_dev_dir.cache`)
✅ CocoaPods integration

### iOS-Only (Could Benefit Android)
⚠️ `config show/set/reset` commands - Would be useful for Android
⚠️ Separate init hooks - Clearer architecture

### Android-Only (Could Benefit iOS)
⚠️ `avd-reset.sh` - Dedicated state reset script
⚠️ `emulator reset` command - Convenient cleanup
⚠️ `run` command - Single command for build+deploy+launch
⚠️ Comprehensive emulator detection tests
⚠️ Multiple test suite variants

---

## Implementation Plan

### Phase 1: Critical Fixes (HIGH Priority)

#### 1.1 Fix iOS Lock File Location ❌ BLOCKER
**Files to modify:**
- Remove: `plugins/ios/config/devices/devices.lock`
- Update: `plugins/ios/virtenv/scripts/init/init-hook.sh` (ensure correct path)
- Update: `plugins/ios/virtenv/scripts/user/devices.sh` (eval command)
- Verify: `examples/ios/devbox.d/ios/devices/devices.lock` generation

**Acceptance Criteria:**
- Lock file is NOT in plugin config
- Lock file IS generated in user project `devbox.d/ios/devices/`
- `ios.sh devices eval` works correctly
- Lock file format matches Android pattern

#### 1.2 Add iOS SCRIPTS.md Documentation
**Create:** `plugins/ios/SCRIPTS.md`

**Content:**
- Layer architecture (1-5)
- Script dependencies and flow
- How to extend the plugin
- Debugging guide
- Common patterns

**Reference:** Copy structure from `plugins/android/SCRIPTS.md`

#### 1.3 Add iOS Test Documentation
**Create:** `examples/ios/tests/README.md`

**Content:**
- Test suite overview
- What each test validates
- How to run tests
- Debugging test failures
- Test architecture

**Reference:** Copy structure from `examples/android/tests/README.md`

### Phase 2: Test Coverage (HIGH Priority)

#### 2.1 Add iOS Simulator Detection Tests
**Create:** `plugins/tests/ios/test-simulator-detection.sh`

**Tests:**
- Device name resolution
- Runtime availability checking
- UDID lookup and matching
- Simulator state detection
- Multiple simulator handling

**Reference:** `plugins/tests/android/test-emulator-detection.sh`

#### 2.2 Add iOS Pure Mode Tests
**Create:** `plugins/tests/ios/test-simulator-modes.sh`

**Tests:**
- Clean simulator creation in pure mode
- Simulator reuse in normal mode
- Cleanup behavior
- `IOS_SIMULATOR_PURE` flag behavior

**Reference:** `plugins/tests/android/test-emulator-modes.sh`

### Phase 3: Documentation Improvements (MEDIUM Priority)

#### 3.1 Expand iOS README.md
**Update:** `plugins/ios/README.md`

**Add:**
- Quick start examples
- Common workflows
- Device management examples
- Troubleshooting section
- Links to REFERENCE.md sections

**Target:** Expand from 15 lines to ~100 lines (match Android)

#### 3.2 Add iOS Test Suite Variants
**Create:** `examples/ios/tests/test-simulator-only.yaml`

**Purpose:**
- Test simulator lifecycle without app building
- Faster smoke testing
- Match Android's variant pattern

### Phase 4: Architectural Improvements (MEDIUM Priority)

#### 4.1 Consider Adding config.sh to Android
**Create:** `plugins/android/virtenv/scripts/user/config.sh`

**Commands:**
- `android.sh config show` - Display all configuration
- `android.sh config set KEY=VALUE` - Set config value
- `android.sh config reset` - Reset to defaults

**Benefit:** Explicit configuration management (matches iOS)

#### 4.2 Consider Adding simulator reset to iOS
**Update:** `plugins/ios/virtenv/scripts/user/ios.sh`

**Add command:**
- `ios.sh simulator reset` - Delete all simulators and recreate defaults

**Benefit:** Convenient cleanup (matches Android's `emulator reset`)

#### 4.3 Standardize Script Naming
**Options:**
1. Rename Android `run.sh` → `deploy.sh`
2. Rename iOS `deploy.sh` → `run.sh`

**Recommendation:** Option 1 (`deploy.sh` is more descriptive)

**Files to rename:**
- `plugins/android/virtenv/scripts/domain/run.sh` → `deploy.sh`
- Update all references in `android.sh`
- Update documentation

### Phase 5: Refactoring (LOW Priority)

#### 5.1 Adopt iOS Init Hook Pattern in Android
**Goal:** Separate config generation from environment initialization

**Refactor:**
- Split `plugins/android/virtenv/scripts/init/setup.sh` into:
  - `init-hook.sh` (config generation)
  - `setup.sh` (environment initialization)

**Benefit:** Clearer separation of concerns (matches iOS)

#### 5.2 Add iOS Test Suite Variant
**Create:** Additional test YAML for specific scenarios

**Examples:**
- Headless vs UI testing
- Different device sizes
- Different iOS versions

---

## Progress Tracking

### Completed Items
- ✅ Initial parity analysis (2026-02-11)
- ✅ Comprehensive comparison document created (parity.md)
- ✅ **Phase 1.1**: Fixed iOS lock file location - Removed `plugins/ios/config/devices/devices.lock`
- ✅ **Phase 1.2**: Added `plugins/ios/SCRIPTS.md` - Comprehensive 16KB+ script documentation
- ✅ **Phase 1.3**: Added `examples/ios/tests/README.md` - Complete test documentation with troubleshooting
- ✅ **Phase 2.1**: Added `plugins/tests/ios/test-simulator-detection.sh` - Simulator detection tests (23 assertions)
- ✅ **Phase 2.2**: Added `plugins/tests/ios/test-simulator-modes.sh` - Pure vs normal mode behavior tests
- ✅ **Phase 3.1**: Expanded `plugins/ios/README.md` from 15 to 181 lines - Added quickstart, commands, troubleshooting
- ✅ **Phase 4.1**: Added `plugins/android/virtenv/scripts/user/config.sh` - Explicit configuration management matching iOS pattern
- ✅ **Phase 4.2**: Added `simulator reset` command to iOS - Stops simulators and deletes those matching device definitions
- ✅ **Phase 4.3**: Renamed Android `run.sh` to `deploy.sh` - Standardized naming to match iOS pattern
- ✅ **Phase 5.1**: Split Android `setup.sh` into `init-hook.sh` (config generation) and `setup.sh` (env init) - Clearer separation matching iOS
- ✅ **Phase 5.2**: Added `test-simulator-only.yaml` for iOS - Faster smoke testing matching Android's test-emulator-only.yaml
- ✅ **Phase 5.2 (bonus)**: Fixed ios.sh device name resolution and return/exit statements for proper script execution

### All Phases Complete
- ✅ **Phase 1**: Critical Fixes (3/3 complete)
- ✅ **Phase 2**: Test Coverage (2/2 complete)
- ✅ **Phase 3**: Documentation (1/1 complete)
- ✅ **Phase 4**: Architectural Improvements (3/3 complete)
- ✅ **Phase 5**: Refactoring (2/2 complete)

### Blocked
- ❌ None

---

## Notes

### Platform-Appropriate Differences (Keep As-Is)
- Device schema complexity (Android: 5 fields, iOS: 2 fields)
- SDK management approach (Android: Nix flake, iOS: Xcode native)
- Environment variable counts (Android: 27, iOS: 9)
- Toolchain discovery (Android: Nix-provided, iOS: Xcode discovery)

### Questions for Review
1. Should Android adopt iOS's two-file init pattern?
2. Should we standardize on `deploy.sh` vs `run.sh`?
3. Should both platforms have explicit config management commands?
4. Are the test suite variants necessary for iOS?

---

## File Path Reference

### Android Plugin
- Root: `/Users/abueide/code/devbox-plugins/plugins/android/`
- Scripts: `/Users/abueide/code/devbox-plugins/plugins/android/virtenv/scripts/`
- Tests: `/Users/abueide/code/devbox-plugins/plugins/tests/android/`
- Example: `/Users/abueide/code/devbox-plugins/examples/android/`

### iOS Plugin
- Root: `/Users/abueide/code/devbox-plugins/plugins/ios/`
- Scripts: `/Users/abueide/code/devbox-plugins/plugins/ios/virtenv/scripts/`
- Tests: `/Users/abueide/code/devbox-plugins/plugins/tests/ios/`
- Example: `/Users/abueide/code/devbox-plugins/examples/ios/`
