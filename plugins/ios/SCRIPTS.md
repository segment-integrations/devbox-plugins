# iOS Plugin Scripts Reference

This document provides a detailed reference for all scripts in the iOS plugin, their purposes, dependencies, and how they interact with each other.

## Available Commands

### Simulator Commands
- `devbox run start:sim [device]` - Start iOS simulator
- `devbox run stop:sim` - Stop all running simulators
- `devbox run start:ios [device]` - Start simulator and deploy app

### Device Management
- `devbox run ios.sh devices list` - List all device definitions
- `devbox run ios.sh devices show <name>` - Show device details
- `devbox run ios.sh devices create <name> --runtime <version>` - Create device
- `devbox run ios.sh devices update <name> [options]` - Update device
- `devbox run ios.sh devices delete <name>` - Delete device
- `devbox run ios.sh devices eval` - Generate devices.lock
- `devbox run ios.sh devices sync` - Sync simulators with device definitions

### Configuration
- `devbox run ios.sh config show` - Display current configuration
- `devbox run ios.sh info` - Display Xcode and SDK information

### Build & Test
- `devbox run build` - Build iOS app
- `devbox run test` - Run tests
- `devbox run test:e2e` - Run end-to-end tests on simulator

## Scripts Directory Structure

```
devbox/plugins/ios/virtenv/scripts/
├── lib/
│   └── lib.sh                # Pure utility functions (sourced)
├── platform/
│   ├── core.sh              # Xcode discovery, environment setup (sourced)
│   └── device_config.sh     # Device configuration utilities (sourced)
├── domain/
│   ├── device_manager.sh    # Runtime resolution, device operations (sourced)
│   ├── simulator.sh         # Simulator lifecycle management (sourced)
│   ├── deploy.sh            # App building and deployment (sourced)
│   └── validate.sh          # Validation functions (sourced)
├── user/
│   ├── ios.sh               # Main CLI entry point (executable)
│   ├── devices.sh           # Device management CLI (executable)
│   └── config.sh            # Configuration display functions (sourced)
└── init/
    ├── init-hook.sh         # Lock file generation (executed pre-init)
    └── setup.sh             # Environment initialization (sourced)
```

## Script Categories

### 1. Sourced Library Scripts
These scripts must be sourced (not executed) and provide functions/environment for other scripts:
- `lib/lib.sh` - Pure utilities
- `platform/core.sh` - Xcode and environment setup
- `platform/device_config.sh` - Device configuration
- `domain/device_manager.sh` - Device and runtime management
- `domain/simulator.sh` - Simulator lifecycle
- `domain/deploy.sh` - App deployment
- `domain/validate.sh` - Environment validation
- `user/config.sh` - Configuration display

### 2. Executable CLI Scripts
These scripts are executed directly by users or other scripts:
- `user/ios.sh` - Main CLI router
- `user/devices.sh` - Device management commands
- `init/init-hook.sh` - Pre-initialization hook

### 3. Init Scripts (Dual Mode)
- `init/setup.sh` - Can be executed or sourced for environment setup

## Layered Architecture

The iOS plugin follows a strict 5-layer architecture to prevent circular dependencies:

```
Layer 1: lib/              # Pure utilities, no dependencies
  ↓
Layer 2: platform/         # Xcode discovery, environment setup
  ↓
Layer 3: domain/           # Simulator, device, app operations (atomic, independent)
  ↓
Layer 4: user/             # User-facing CLI (orchestrates layer 3)
  ↓
Layer 5: init/             # Environment initialization
```

**Critical Rule:** Scripts can only source/depend on scripts from **earlier layers**, never from the same layer or later layers.

For complete layer architecture details, see `LAYERS.md`.

## Detailed Script Documentation

---

### `lib/lib.sh` (Layer 1)

**Purpose:** Pure utility functions with no iOS-specific logic.

**Type:** Sourced library (must be sourced, not executed)

**Key Responsibilities:**
1. String sanitization and normalization
2. Path resolution for iOS directories
3. Checksum computation for device definitions
4. Tool requirement checking
5. Load-once guards

**Exported Functions:**
- `ios_sanitize_device_name(name)` - Normalize device name for safe usage
- `ios_config_path()` - Resolve iOS configuration directory path
- `ios_devices_dir()` - Resolve device definitions directory path
- `ios_compute_devices_checksum(dir)` - Calculate SHA-256 checksum of device files
- `ios_require_tool(tool, message)` - Ensure a tool is available or exit
- `ios_require_jq()` - Ensure jq is available with helpful error message

**Dependencies:** None (layer 1)

**Called By:** All other scripts that need utility functions

**Guards:**
- Uses `IOS_LIB_LOADED` flag to prevent duplicate sourcing
- Checks PID to handle subshells correctly

---

### `platform/core.sh` (Layer 2)

**Purpose:** Core environment initialization - Xcode discovery, PATH setup, and debug utilities.

**Type:** Sourced library (must be sourced, not executed)

**Key Responsibilities:**
1. Discover Xcode Developer Directory (with caching)
2. Set up iOS environment variables
3. Configure PATH to include Xcode tools and iOS scripts
4. Provide debug logging utilities
5. Display SDK summary

**Xcode Discovery Strategy:**
1. Check `IOS_DEVELOPER_DIR` environment variable
2. Check cache file (`.xcode_dev_dir.cache`, 1-hour TTL)
3. Find latest Xcode in `/Applications/Xcode*.app` by version number
4. Use `xcode-select -p` output
5. Fallback to `/Applications/Xcode.app/Contents/Developer`

**Exported Functions:**
- `ios_resolve_developer_dir()` - Find Xcode developer directory with caching
- `ios_latest_xcode_dev_dir()` - Find newest Xcode by version number
- `ios_setup_environment()` - Initialize iOS environment variables and PATH
- `ios_debug_enabled()` - Check if debug mode is enabled
- `ios_debug_log(message)` - Log debug message if enabled
- `ios_debug_dump_vars(vars...)` - Dump variable values in debug mode
- `ios_show_summary()` - Print Xcode and SDK configuration summary

**Key Environment Variables Set:**
- `DEVELOPER_DIR` - Xcode developer directory
- `IOS_DEVELOPER_DIR` - Same as DEVELOPER_DIR (explicit iOS variable)
- `SDKROOT` - iOS SDK root path
- `PATH` - Updated with Xcode tools and iOS scripts

**Caching:**
- Xcode path cached in `.devbox/virtenv/ios/.xcode_dev_dir.cache`
- Cache TTL: 1 hour
- Prevents expensive directory scans on every shell startup

**Dependencies:**
- Layer 1: `lib/lib.sh`

**Called By:**
- `init/setup.sh` - During environment initialization
- Scripts that need Xcode environment

**Guards:**
- Uses `IOS_CORE_LOADED` flag to prevent duplicate sourcing
- Checks PID to handle subshells correctly

---

### `platform/device_config.sh` (Layer 2)

**Purpose:** Device definition discovery, loading, and lock file management.

**Type:** Sourced library (must be sourced, not executed)

**Key Responsibilities:**
1. Find and load device definition files
2. Parse device JSON
3. Manage devices.lock file
4. Filter devices by `IOS_DEVICES` environment variable

**Exported Functions:**
- `ios_load_device_definitions()` - Load all device definitions from directory
- `ios_get_device_from_lock(name)` - Extract device definition from lock file
- `ios_filter_devices_by_selection(devices)` - Filter devices based on IOS_DEVICES
- `ios_validate_device_definition(json)` - Validate device JSON format

**Device Definition Format:**
```json
{
  "name": "iPhone 17",
  "runtime": "26.2"
}
```

**Lock File Format:**
```json
{
  "devices": [
    {"name": "iPhone 13", "runtime": "15.4"},
    {"name": "iPhone 17", "runtime": "26.2"}
  ],
  "checksum": "abc123...",
  "generated_at": "2026-02-10T12:00:00Z"
}
```

**Dependencies:**
- Layer 1: `lib/lib.sh`

**Called By:**
- Layer 3 scripts that work with device definitions
- `user/devices.sh` - For device management operations

**Guards:**
- Uses `IOS_DEVICE_CONFIG_LOADED` flag to prevent duplicate sourcing

---

### `domain/device_manager.sh` (Layer 3)

**Purpose:** Runtime resolution, device creation, and simulator management operations.

**Type:** Sourced library (must be sourced, not executed)

**Key Responsibilities:**
1. Resolve iOS runtimes (iOS versions)
2. Match device names to simulator device types
3. Create and delete simulators
4. Ensure simulators match device definitions

**Exported Functions:**
- `ios_resolve_runtime(version)` - Find runtime identifier for iOS version
- `ios_match_device_type(name)` - Match device name to simulator device type ID
- `ios_create_simulator(name, device_type, runtime)` - Create new simulator
- `ios_delete_simulator(udid)` - Delete simulator by UDID
- `ios_ensure_device_from_definition(device_json_file)` - Sync simulator with definition
- `ios_download_runtime(version)` - Download iOS runtime if missing (if IOS_DOWNLOAD_RUNTIME=1)

**Runtime Resolution:**
- Queries available runtimes: `xcrun simctl list runtimes -j`
- Matches by iOS version (e.g., "17.5", "26.2")
- Supports partial version matching (e.g., "17" matches "17.5")
- Can auto-download missing runtimes via `xcodebuild -downloadPlatform iOS`

**Device Type Matching:**
- Queries device types: `xcrun simctl list devicetypes -j`
- Normalizes names for fuzzy matching
- Handles spaces, dashes, and case variations
- Example: "iPhone 17" → "com.apple.CoreSimulator.SimDeviceType.iPhone-17"

**Dependencies:**
- Layer 1: `lib/lib.sh`
- Layer 2: `platform/core.sh`, `platform/device_config.sh`

**Called By:**
- `user/devices.sh sync` - To ensure simulators match definitions
- Layer 4 scripts that manage devices

**Guards:**
- Uses `IOS_DEVICE_MANAGER_LOADED` flag to prevent duplicate sourcing

---

### `domain/simulator.sh` (Layer 3)

**Purpose:** Simulator lifecycle management - boot, shutdown, health checks.

**Type:** Sourced library (must be sourced, not executed)

**Key Responsibilities:**
1. Boot simulators
2. Shutdown simulators
3. Check simulator health and state
4. Recover from CoreSimulatorService failures
5. Handle pure mode (create test-specific simulators)

**Exported Functions:**
- `ios_start_simulator(device_name)` - Boot simulator by device name
- `ios_stop_simulator([udid])` - Shutdown simulator (or all if no UDID)
- `ios_simulator_is_booted(udid)` - Check if simulator is running
- `ios_wait_for_simulator_boot(udid, timeout)` - Wait for simulator ready state
- `ios_check_simulator_service()` - Verify CoreSimulatorService is healthy
- `ios_recover_simulator_service()` - Attempt to recover from service failures

**Pure Mode Behavior:**
When `IOS_SIMULATOR_PURE=1` or `IN_NIX_SHELL=pure`:
- Creates fresh simulator with " Test" suffix
- Isolated from existing simulators
- Automatically cleaned up after tests
- Ensures reproducible testing environment

**Health Checks:**
- Verifies CoreSimulatorService is responding
- Checks simulator boot status via `xcrun simctl bootstatus`
- Provides recovery instructions for common failures

**Dependencies:**
- Layer 1: `lib/lib.sh`
- Layer 2: `platform/core.sh`

**Called By:**
- `user/ios.sh simulator start` - User command
- Layer 4 scripts that need simulator operations
- Test suites (via devbox scripts)

**Guards:**
- Uses `IOS_SIMULATOR_LOADED` flag to prevent duplicate sourcing

---

### `domain/deploy.sh` (Layer 3)

**Purpose:** App building and deployment to simulators.

**Type:** Sourced library (must be sourced, not executed)

**Key Responsibilities:**
1. Resolve Xcode project/workspace
2. Build app via xcodebuild
3. Find app bundle artifact
4. Install app on simulator
5. Launch app on simulator

**Exported Functions:**
- `ios_build_app(project, scheme, config)` - Build iOS app with xcodebuild
- `ios_find_app_artifact(derived_data)` - Locate .app bundle after build
- `ios_install_app(udid, app_path)` - Install app on simulator
- `ios_launch_app(udid, bundle_id)` - Launch app on simulator
- `ios_deploy_to_simulator(device_name)` - Complete build→install→launch flow

**Build Process:**
1. Resolves project from `IOS_APP_PROJECT` environment variable
2. Uses scheme from `IOS_APP_SCHEME`
3. Builds with `xcodebuild` (with Nix flags stripped for compatibility)
4. Locates built .app bundle
5. Installs via `xcrun simctl install`
6. Launches via `xcrun simctl launch`

**Environment Variables Used:**
- `IOS_APP_PROJECT` - Path to .xcodeproj or .xcworkspace
- `IOS_APP_SCHEME` - Xcode build scheme
- `IOS_APP_BUNDLE_ID` - App bundle identifier
- `IOS_APP_ARTIFACT` - Path to built .app (optional, auto-detected if not set)
- `IOS_APP_DERIVED_DATA` - DerivedData path (optional)

**Dependencies:**
- Layer 1: `lib/lib.sh`
- Layer 2: `platform/core.sh`
- **Note:** Currently sources `domain/simulator.sh` (layer 3 violation - refactoring opportunity)

**Called By:**
- `user/ios.sh` commands that deploy apps
- Test suites

**Guards:**
- Uses `IOS_DEPLOY_LOADED` flag to prevent duplicate sourcing

---

### `domain/validate.sh` (Layer 3)

**Purpose:** Non-blocking validation functions that warn about potential issues.

**Type:** Sourced library (must be sourced, not executed)

**Key Responsibilities:**
1. Validate devices.lock checksum
2. Validate Xcode installation
3. Check simulator runtime availability
4. Warn about configuration issues

**Exported Functions:**
- `ios_validate_lock_file()` - Validate devices.lock checksum against device definitions
- `ios_validate_xcode()` - Validate Xcode installation is complete
- `ios_validate_runtimes()` - Check iOS runtime availability

**Validation Philosophy:**
- **Warnings only**, never blocks execution
- Returns 0 even on validation failures
- Provides actionable fix commands in warning messages
- Skips validation when tools unavailable

**Example Output:**
```
Warning: devices.lock may be stale (device definitions changed).
Run 'devbox run ios.sh devices eval' to update.
```

**Dependencies:**
- Layer 1: `lib/lib.sh`
- Layer 2: `platform/core.sh`

**Called By:**
- `init/setup.sh` - Automatically runs validations during environment setup

**Guards:**
- Uses `IOS_VALIDATE_LOADED` flag to prevent duplicate sourcing

---

### `user/ios.sh` (Layer 4)

**Purpose:** Main CLI entry point that routes commands to appropriate handlers.

**Type:** Executable script

**Usage:**
```bash
ios.sh <command> [args]

Commands:
  devices <command> [args]     # Delegate to devices.sh
  simulator start [device]     # Start simulator (optionally --pure)
  simulator stop               # Stop all simulators
  config show                  # Show configuration
  info                         # Show Xcode summary
```

**Command Handlers:**
- `devices` - Delegates to `devices.sh`
- `simulator start` - Sources `domain/simulator.sh` and calls `ios_start_simulator()`
- `simulator stop` - Sources `domain/simulator.sh` and calls `ios_stop_simulator()`
- `config show` - Sources `user/config.sh` and calls `ios_config_show()`
- `info` - Sources `platform/core.sh` and calls `ios_show_summary()`

**Pure Mode Support:**
`simulator start` accepts `--pure` flag to create isolated test simulator.

**Dependencies:**
- Can source from layers 1, 2, and 3
- Delegates to `devices.sh` (layer 4)

**Called By:** User via `devbox run ios.sh <command>`

---

### `user/devices.sh` (Layer 4)

**Purpose:** Device management CLI for creating, updating, listing, and managing device definitions.

**Type:** Executable script

**Usage:**
```bash
devices.sh <command> [args]

Commands:
  list                         # List all device definitions
  show <name>                  # Show specific device JSON
  create <name> --runtime <version>
  update <name> [--name <new>] [--runtime <version>]
  delete <name>                # Remove device definition
  eval                         # Generate devices.lock
  sync                         # Ensure simulators match device definitions
```

**Key Functions:**
- `resolve_device_file(name)` - Find device JSON by filename or name field
- `validate_runtime(value)` - Ensure runtime is valid iOS version format

**Lock File Generation (`eval` command):**
1. Reads all device definition files from `IOS_DEVICES_DIR`
2. Builds JSON array of device objects
3. Computes SHA-256 checksum of all device files
4. Writes `devices.lock` with devices, checksum, and timestamp

**Simulator Sync (`sync` command):**
1. Reads `devices.lock` file
2. For each device definition:
   - Checks if matching simulator exists
   - Creates simulator if missing
   - Recreates if configuration mismatch
3. Reports: matched, recreated, created, skipped

**Valid Runtimes:**
- iOS version numbers (e.g., "15.4", "17.5", "26.2")
- Run `xcrun simctl list runtimes` to see available versions

**Valid Device Names:**
- iOS device type names (e.g., "iPhone 13", "iPhone 17", "iPad Pro")
- Run `xcrun simctl list devicetypes` for exact names

**Dependencies:**
- Layer 1: `lib/lib.sh`
- Layer 2: `platform/core.sh`, `platform/device_config.sh`
- Layer 3: `domain/device_manager.sh`
- `jq` - For JSON manipulation
- `sha256sum` or `shasum` - For checksum computation

**Called By:**
- `ios.sh devices` - Via delegation
- User via `devbox run devices.sh <command>`

---

### `user/config.sh` (Layer 4)

**Purpose:** Configuration display functions.

**Type:** Sourced library

**Exported Functions:**
- `ios_config_show()` - Display current iOS configuration

**Configuration Display:**
Shows resolved values for:
- Xcode Developer Directory
- iOS SDK Root
- Device definitions directory
- Default device
- Device selection filter

**Dependencies:**
- Layer 1: `lib/lib.sh`
- Layer 2: `platform/core.sh`

**Called By:**
- `user/ios.sh config show` command

---

### `init/init-hook.sh` (Layer 5)

**Purpose:** Pre-initialization hook that generates devices.lock before shell starts.

**Type:** Executable bash script (not sourced)

**Execution:** Runs automatically on `devbox shell` or `devbox run` (before environment setup)

**Key Responsibilities:**
1. Generate `devices.lock` from device definition files
2. Filter devices by `IOS_DEVICES` environment variable
3. Compute checksum for validation
4. Make all scripts executable

**Device Selection:**
- If `IOS_DEVICES` is empty: includes all devices
- If `IOS_DEVICES` is set: filters to specified devices (comma or space separated)
- Examples:
  - `IOS_DEVICES=""` → all devices
  - `IOS_DEVICES="min,max"` → only min and max
  - `IOS_DEVICES="iPhone 17"` → only iPhone 17

**Lock File Output:**
Creates JSON file with:
- `devices` - Array of device definitions
- `checksum` - SHA-256 of all device files
- `generated_at` - ISO 8601 timestamp

**Dependencies:**
- `jq` - For JSON manipulation
- `sha256sum` or `shasum` - For checksum

**Called By:** Devbox init hook (automatic, defined in plugin.json)

---

### `init/setup.sh` (Layer 5)

**Purpose:** Environment initialization script run on every shell startup.

**Type:** Dual-mode script (can be executed or sourced)

**Execution Modes:**
1. **Sourced** (`. setup.sh` or `source setup.sh`):
   - Sources `platform/core.sh` for environment setup
   - Runs validation (non-blocking)
   - Displays SDK summary if `INIT_IOS` is set
   - Standard mode for interactive shells

2. **Executed** (`./setup.sh` or `bash setup.sh`):
   - Can be used to inspect environment
   - Useful for debugging

**Key Responsibilities:**
1. Source `platform/core.sh` (which sources `lib/lib.sh`)
2. Initialize Xcode environment
3. Run validation checks
4. Display SDK summary (if requested)

**Environment Variable:**
- `INIT_IOS=1` - Show SDK summary on shell startup

**Dependencies:**
- Layer 2: `platform/core.sh` (which depends on layer 1)
- Layer 3: `domain/validate.sh`

**Called By:** Devbox shell initialization (automatic, defined in plugin.json)

---

## Script Dependency Graph

```
lib/lib.sh (layer 1)
  ↓
platform/core.sh (layer 2) ←─┐
platform/device_config.sh ←──┤
  ↓                          │
domain/device_manager.sh ←───┤
domain/simulator.sh ←────────┤
domain/deploy.sh ←───────────┤ (sources simulator.sh - refactoring opportunity)
domain/validate.sh ←─────────┤
  ↓                          │
user/ios.sh (layer 4) ───────┤
user/devices.sh ─────────────┤
user/config.sh ──────────────┘
  ↓
init/init-hook.sh (layer 5) - Executed before shell
init/setup.sh (layer 5) - Sourced on shell startup
```

## Execution Flow Examples

### Example 1: User runs `devbox run ios.sh info`

```
1. ios.sh executes
2. Parses command: "info"
3. Sources platform/core.sh
   3a. core.sh sources lib/lib.sh
   3b. core.sh discovers Xcode (with caching)
   3c. core.sh sets up environment variables
4. Calls ios_show_summary()
5. Prints Xcode and SDK information
```

### Example 2: User runs `devbox run ios.sh devices create iphone15 --runtime 17.5`

```
1. ios.sh executes
2. Parses command: "devices create ..."
3. Delegates to devices.sh via exec
4. devices.sh sources dependencies (lib, platform/core, platform/device_config)
5. devices.sh parses: "create iphone15 --runtime 17.5"
6. Validates runtime value (17.5)
7. Creates JSON file: devbox.d/ios/devices/iphone15.json
   {
     "name": "iphone15",
     "runtime": "17.5"
   }
```

### Example 3: User runs `devbox run ios.sh devices eval`

```
1. ios.sh delegates to devices.sh
2. devices.sh sources dependencies
3. devices.sh parses: "eval"
4. Reads all device files from IOS_DEVICES_DIR
5. Builds JSON array of device objects
6. Computes SHA-256 checksum of device files
7. Writes devices.lock:
   {
     "devices": [{"name":"iPhone 13","runtime":"15.4"}, ...],
     "checksum": "abc123...",
     "generated_at": "2026-02-10T12:00:00Z"
   }
```

### Example 4: User runs `devbox shell`

```
1. Devbox runs init-hook.sh (pre-init)
   1a. init-hook.sh generates devices.lock
   1b. init-hook.sh makes scripts executable
2. Devbox sources setup.sh (shell startup)
   2a. setup.sh sources platform/core.sh
       - core.sh sources lib/lib.sh
       - core.sh discovers Xcode (with caching)
       - core.sh sets up PATH and environment
   2b. setup.sh runs validation (non-blocking)
   2c. setup.sh shows SDK summary (if INIT_IOS=1)
3. User has iOS-ready shell environment
```

### Example 5: User runs `devbox run ios.sh simulator start --pure`

```
1. ios.sh executes
2. Parses command: "simulator start" with --pure flag
3. Sets IOS_SIMULATOR_PURE=1
4. Sources domain/simulator.sh (which sources platform/core.sh, lib/lib.sh)
5. Calls ios_start_simulator with pure mode enabled
6. Creates test-specific simulator "iPhone 17 Test"
7. Boots simulator
8. Returns UDID of test simulator
```

## Environment Variable Loading Priority

Scripts use a consistent pattern for finding configuration:

1. `IOS_CONFIG_DIR` environment variable (explicit override)
2. `${DEVBOX_PROJECT_ROOT}/devbox.d/ios/`
3. `${DEVBOX_PROJECT_DIR}/devbox.d/ios/`
4. `${DEVBOX_WD}/devbox.d/ios/`
5. `./devbox.d/ios/` (current directory)

Device definitions directory:
1. `IOS_DEVICES_DIR` environment variable (explicit override)
2. `${IOS_CONFIG_DIR}/devices`
3. Falls back to config dir + `/devices`

## Common Patterns

### Sourcing Guard Pattern
```bash
if ! (return 0 2>/dev/null); then
  echo "❌ script.sh must be sourced, not executed." >&2
  exit 1
fi

if [ "${IOS_SCRIPT_LOADED:-}" = "1" ] && [ "${IOS_SCRIPT_LOADED_PID:-}" = "$$" ]; then
  return 0 2>/dev/null || exit 0
fi
IOS_SCRIPT_LOADED=1
IOS_SCRIPT_LOADED_PID="$$"
```

### Debug Logging Pattern
```bash
if ios_debug_enabled; then
  ios_debug_log "message"
fi
```

### Non-Blocking Validation Pattern
```bash
ios_validate_something || true  # Always succeeds, just warns
```

### Xcode Path Caching Pattern
```bash
# Check cache first (1-hour TTL)
cache_file=".devbox/virtenv/ios/.xcode_dev_dir.cache"
if [ -f "$cache_file" ]; then
  cache_age=$(($(date +%s) - $(stat -f %m "$cache_file" 2>/dev/null || echo 0)))
  if [ "$cache_age" -lt 3600 ]; then
    cached_path="$(cat "$cache_file")"
    if [ -d "$cached_path" ]; then
      echo "$cached_path"
      return 0
    fi
  fi
fi

# Expensive discovery...
discovered_path="$(find_xcode)"
echo "$discovered_path" > "$cache_file"
```

### Layer Dependency Pattern
```bash
# Layer 4 script orchestrating multiple layer 3 operations
ios.sh start-ios) {
  . "$IOS_SCRIPTS_DIR/domain/simulator.sh"  # Layer 3
  . "$IOS_SCRIPTS_DIR/domain/deploy.sh"     # Layer 3

  # Step 1: Start simulator
  ios_start_simulator "$device"

  # Step 2: Deploy app
  ios_deploy_to_simulator "$device"
}
```

## Best Practices When Modifying Scripts

1. **Respect the Layer Architecture:**
   - Only source/depend on earlier layers
   - Layer 3 scripts must be atomic (no same-layer dependencies)
   - Use layer 4 for orchestration

2. **Sourced vs Executable:**
   - Sourced libraries must check `(return 0 2>/dev/null)` guard
   - Use sourcing guards to prevent duplicate loading
   - Respect script type (don't execute sourced scripts)

3. **Error Handling:**
   - User-facing CLI scripts use `set -eu` for strict error handling
   - Validation functions return 0 and use `|| true` when called
   - Provide helpful error messages with actionable steps

4. **Environment Variables:**
   - Always check if variable is already set before overriding
   - Use consistent naming: `IOS_*` prefix
   - Document all environment variables in REFERENCE.md

5. **Debug Logging:**
   - Use `ios_debug_log()` for debug output
   - Check `ios_debug_enabled()` before expensive operations
   - Log important state transitions

6. **Path Resolution:**
   - Try multiple fallback strategies
   - Support both explicit env vars and auto-detection
   - Use caching for expensive operations (with TTL)

7. **Tool Dependencies:**
   - Check tool availability with `command -v`
   - Use `ios_require_tool()` for required tools
   - Provide helpful error messages with installation hints

8. **JSON Manipulation:**
   - Always use `jq` for JSON operations
   - Validate input before updating files
   - Use temp files and atomic moves: `jq ... > tmp && mv tmp original`

9. **Xcode Compatibility:**
   - Strip Nix-specific flags when calling Xcode tools
   - Handle multiple Xcode installations gracefully
   - Cache expensive Xcode discovery operations

## Debugging Scripts

Enable debug mode:
```bash
IOS_DEBUG=1 devbox shell
# or
DEBUG=1 devbox shell
```

Debug output shows:
- Script execution context (sourced vs run)
- Xcode discovery steps
- Environment variable values
- Runtime resolution
- Simulator operations
- Device matching logic

## Platform-Specific Considerations

### Xcode Discovery
Layer 2 (`platform/core.sh`) uses sophisticated Xcode discovery:
- Checks environment variables first
- Scans `/Applications/Xcode*.app` and sorts by version
- Uses `xcode-select -p` as fallback
- Caches result for 1 hour (reduces shell startup time)

### Runtime Management
Layer 3 (`domain/device_manager.sh`) resolves runtimes:
- Queries via `xcrun simctl list runtimes -j`
- Supports partial version matching (e.g., "17" → "17.5")
- Can auto-download missing runtimes (if `IOS_DOWNLOAD_RUNTIME=1`)
- Gracefully falls back to any available iOS runtime

### Simulator Service Health
Layer 3 (`domain/simulator.sh`) monitors CoreSimulatorService:
- Checks service responsiveness before operations
- Provides recovery instructions for common failures
- Handles service unavailability gracefully

### Pure Mode Testing
Supports isolated testing via `IOS_SIMULATOR_PURE=1` or `IN_NIX_SHELL=pure`:
- Creates test-specific simulators (with " Test" suffix)
- Isolated from existing simulators
- Automatically cleaned up after tests
- Ensures reproducible CI environment

## Known Refactoring Opportunities

1. **deploy.sh sourcing simulator.sh:**
   - Current: `domain/deploy.sh` sources `domain/simulator.sh` (layer 3 violation)
   - Options:
     - Move shared simulator utilities to `platform/` (layer 2)
     - Have `user/ios.sh` orchestrate both separately
     - Extract common functions to layer 2

2. **Device configuration split:**
   - Device operations split between `platform/device_config.sh` and `domain/device_manager.sh`
   - Consider consolidating device file operations in layer 2
   - Keep simulator operations in layer 3

## Comparison with Android Plugin

Both iOS and Android plugins follow the same 5-layer architecture:

**Similarities:**
- Same layer structure and dependency rules
- Similar naming conventions (platform-prefixed functions)
- Consistent approach to device management
- Non-blocking validation philosophy
- Debug logging patterns

**Key Differences:**
- **SDK Management:** iOS uses native Xcode; Android uses Nix flake
- **Device Complexity:** iOS has 2 fields (name, runtime); Android has 5 fields (api, device, tag, abi, name)
- **Init Structure:** iOS uses separate init-hook.sh + setup.sh; Android uses single dual-mode setup.sh
- **Lock File Format:** iOS includes full device JSON; Android includes API list
- **Platform Tools:** iOS uses xcrun/simctl; Android uses avdmanager/emulator
- **Caching:** iOS caches Xcode path; Android relies on Nix caching

The layered architecture ensures both plugins maintain consistent patterns while adapting to platform-specific requirements.
