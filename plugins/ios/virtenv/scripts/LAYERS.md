# Script Layering Architecture

The iOS plugin scripts are organized into layers to prevent circular dependencies and maintain clear separation of concerns.

## Layer Rules

**Critical Rule**: Scripts can only source/depend on scripts from **earlier layers**, never from the same layer or later layers.

This prevents circular dependencies and makes the codebase easier to understand and maintain.

## Directory Structure

```
scripts/
├── lib/              # Layer 1: Pure Utilities
│   └── lib.sh
├── platform/         # Layer 2: Platform Setup
│   ├── core.sh
│   └── device_config.sh
├── domain/           # Layer 3: Domain Operations
│   ├── device_manager.sh
│   ├── simulator.sh
│   ├── deploy.sh
│   └── validate.sh
├── user/             # Layer 4: User CLI
│   ├── ios.sh
│   ├── devices.sh
│   └── config.sh
└── init/             # Layer 5: Setup & Init
    ├── init-hook.sh
    └── setup.sh
```

## Layer Structure

```
Layer 1: lib/ - Pure Utilities
  ↓
Layer 2: platform/ - Platform Setup
  ↓
Layer 3: domain/ - Domain Operations
  ↓
Layer 4: user/ - User CLI
  ↓
Layer 5: init/ - Environment Init
```

## Layer 1: Pure Utilities

**File**: `lib.sh`

**Purpose**: Pure utility functions with no iOS-specific logic.

**Functions**:
- String sanitization (`ios_sanitize_device_name`)
- Path resolution (`ios_config_path`, `ios_devices_dir`)
- Checksums (`ios_compute_devices_checksum`)
- Requirement checking (`ios_require_tool`, `ios_require_jq`)
- Load-once guards

**Dependencies**: None

## Layer 2: Platform Setup

**Files**: `core.sh`, `device_config.sh`

**Purpose**: Xcode discovery, environment setup, and device configuration utilities.

### core.sh
- Xcode developer directory discovery (`ios_resolve_developer_dir`, `ios_latest_xcode_dev_dir`)
- Environment setup (`ios_setup_environment`)
- PATH configuration (Xcode tools, iOS scripts)
- Debug utilities (`ios_debug_enabled`, `ios_debug_log`, `ios_debug_dump_vars`)
- Summary display (`ios_show_summary`)

### device_config.sh
- Device file discovery and loading
- Device definition parsing
- Lock file management
- Device filtering by IOS_DEVICES env var

**Dependencies**: Layer 1 only

## Layer 3: Domain Operations

**Directory**: `domain/`

**Files**:
- `domain/device_manager.sh` - Runtime resolution, device creation, simulator management
- `domain/simulator.sh` - Simulator lifecycle (boot, shutdown, health checks)
- `domain/deploy.sh` - App building and deployment to simulators
- `domain/validate.sh` - Non-blocking environment validation

**Purpose**: Internal domain logic for iOS operations. These scripts are not meant to be called directly by users.

**Critical Rule**: Scripts in this layer CANNOT source or call functions from other layer 3 scripts. If two layer 3 scripts need the same functionality, that functionality must be moved to layer 2 or layer 1.

**Why?** Layer 3 scripts are domain operations that should be atomic and independent. Orchestration of multiple layer 3 operations belongs in layer 4.

**Example - WRONG**:
```sh
# domain/deploy.sh calling domain/simulator.sh - VIOLATES LAYER RULE
ios_deploy_app() {
  ios_start_simulator  # ❌ Calling another layer 3 function
  # ... deploy app
}
```

**Example - CORRECT**:
```sh
# ios.sh (layer 4) orchestrates multiple layer 3 operations
ios.sh start-ios) {
  . domain/simulator.sh
  . domain/deploy.sh

  # Step 1: Start simulator
  ios_start_simulator "$device"

  # Step 2: Deploy app
  ios_deploy_app "$device"
}
```

**Note**: The current implementation has `domain/deploy.sh` sourcing `domain/simulator.sh`. This should eventually be refactored to follow the layer rules by moving shared functionality to layer 2 or having layer 4 orchestrate both.

**Dependencies**: Layers 1 & 2 only (ideally; some refactoring needed)

## Layer 4: User CLI

**Files**: `ios.sh`, `devices.sh`, `config.sh`

**Purpose**: User-facing command-line interfaces.

### ios.sh
Main CLI entry point with commands:
- `devices` - Delegate to devices.sh
- `config` - Configuration management
- `info` - Xcode and SDK information display

### devices.sh
Device management CLI:
- `list` - List device definitions
- `show` - Show specific device JSON
- `create` - Create device definition
- `update` - Update device definition
- `delete` - Delete device definition
- `eval` - Generate devices.lock
- `sync` - Sync simulators with device definitions

### config.sh
Configuration management:
- `ios_config_show` - Display current configuration

**Purpose**: Orchestrate layer 3 operations and provide clean user interface.

**Dependencies**: Can source from layers 1, 2, and 3

## Layer 5: Setup & Init

**Files**: `init-hook.sh`, `setup.sh`

**Purpose**: Initialization scripts run by devbox init hooks.

### init-hook.sh
**Execution**: Bash script (executed mode)

**Purpose**:
- Generates `devices.lock` from device definitions
- Filters devices by IOS_DEVICES env var
- Computes checksum for validation
- Makes scripts executable
- Runs once on `devbox shell` startup

### setup.sh
**Execution**: Sourced script (`. setup.sh`)

**Purpose**:
- Sources `platform/core.sh` for Xcode resolution and environment setup
- `core.sh` automatically sources `lib/lib.sh` as dependency
- Runs validation (non-blocking)
- Displays SDK summary (if INIT_IOS is set)
- Runs on every shell startup

**Dependencies**: Sources layer 2 (`platform/core.sh`), which sources layer 1 (`lib/lib.sh`)

## Dependency Graph

```
lib/lib.sh (layer 1)
  ↓
platform/core.sh (layer 2) - Xcode discovery, PATH setup
platform/device_config.sh (layer 2) - Device configuration
  ↓
domain/device_manager.sh (layer 3) - Runtime, device operations
domain/simulator.sh (layer 3) - Simulator lifecycle
domain/deploy.sh (layer 3) - App deployment
domain/validate.sh (layer 3) - Validation
  ↓
user/ios.sh (layer 4) - Main CLI router
user/devices.sh (layer 4) - Device management CLI
user/config.sh (layer 4) - Config management
  ↓
init/init-hook.sh (layer 5) - Lock file generation
init/setup.sh (layer 5) - Env init (sources core.sh when sourced)
```

## iOS-Specific Considerations

### Xcode Discovery
Layer 2 (`platform/core.sh`) handles Xcode discovery with multiple fallback strategies:
1. Check `IOS_DEVELOPER_DIR` environment variable
2. Find latest Xcode in `/Applications/Xcode*.app` by version
3. Use `xcode-select -p` output
4. Fallback to `/Applications/Xcode.app/Contents/Developer`

This ensures compatibility across different Xcode installations and CI environments.

### Runtime Resolution
Layer 3 (`domain/device_manager.sh`) resolves iOS runtimes:
- Queries available runtimes via `xcrun simctl list runtimes -j`
- Matches by iOS version (e.g., "17.5")
- Supports automatic runtime downloads via `xcodebuild -downloadPlatform iOS`
- Falls back to any available iOS runtime

### Simulator Operations
Layer 3 (`domain/simulator.sh`) manages simulator lifecycle:
- Health checks for CoreSimulatorService
- Simulator boot/shutdown operations
- Device state management
- Recovery instructions for service failures

### App Deployment
Layer 3 (`domain/deploy.sh`) handles app building and deployment:
- Xcode project resolution
- Build artifact discovery
- App bundle installation
- App launch on simulator

## Adding New Scripts

When adding a new script, ask:

1. **What does this script depend on?**
   - If it only needs utilities → Layer 1
   - If it needs Xcode/platform setup → Layer 2
   - If it performs domain operations (simulator, device, app) → Layer 3
   - If it's a user-facing CLI → Layer 4
   - If it's environment initialization → Layer 5

2. **Can I avoid same-layer dependencies?**
   - If a layer 3 script needs another layer 3 script, consider:
     - Moving shared logic to layer 2
     - Having layer 4 source both scripts and orchestrate
     - Splitting into smaller, focused scripts

3. **Is this script internal or user-facing?**
   - Internal domain operations → `domain/` directory
   - User-facing CLI → `user/` directory

## Testing Layer Violations

To check for layer violations:

```bash
# Layer 3 scripts should not source other layer 3 scripts
grep -r "IOS_SCRIPTS_DIR}/domain" domain/

# Should return minimal matches (only for orchestration, ideally none)

# Check for circular dependencies
grep -r "\. .*lib\.sh" lib/
grep -r "\. .*platform/" platform/
grep -r "\. .*domain/" domain/

# Should show no same-layer or forward-layer dependencies
```

## Known Refactoring Opportunities

1. **deploy.sh sourcing simulator.sh**: Currently `domain/deploy.sh` sources `domain/simulator.sh` which violates layer 3 independence. This should be refactored to either:
   - Move shared functionality to `platform/`
   - Have `user/ios.sh` orchestrate both operations
   - Extract common simulator utilities to layer 2

2. **Device config in multiple layers**: Device configuration logic is split between `platform/device_config.sh` and `domain/device_manager.sh`. Consider consolidating device file operations in layer 2.

## Benefits

1. **No circular dependencies** - Impossible by design
2. **Clear structure** - Easy to understand what depends on what
3. **Easier testing** - Lower layers can be tested independently
4. **Better maintainability** - Changes in one layer have predictable impact
5. **Forced modularity** - Encourages small, focused scripts
6. **Platform consistency** - iOS follows same architecture as Android plugin

## Comparison with Android Plugin

Both iOS and Android plugins follow the same 5-layer architecture:

**Similarities**:
- Same layer structure and dependency rules
- Similar naming conventions (platform-prefixed functions)
- Consistent approach to device management
- Dual-mode init scripts (executed + sourced)

**Differences**:
- **Layer 2**: Android uses Nix flake for SDK; iOS uses native Xcode
- **Layer 3**: iOS has runtime resolution; Android has AVD management
- **Lock files**: iOS includes full device JSON; Android includes API list
- **Platform tools**: iOS uses xcrun/simctl; Android uses Android SDK tools

The layered architecture ensures both plugins maintain consistent patterns while adapting to platform-specific requirements.
