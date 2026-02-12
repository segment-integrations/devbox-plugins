# React Native Plugin Tests

This directory contains tests for the React Native plugin, specifically focused on Metro bundler lifecycle management.

## Test Files

### Unit Tests

**`test-metro.sh`** - Integration test for metro.sh CLI
- Tests port allocation and unique run IDs
- Tests environment file creation with symlinks
- Tests Metro start/stop lifecycle
- Tests parallel test suite isolation
- Tests cleanup of state files

**Run:**
```bash
cd examples/react-native
devbox run test:metro
```

### Integration Tests

**`test-metro-shutdown.yaml`** - Process-compose test for Metro shutdown behavior
- Tests Metro starts and becomes healthy
- Tests Metro responds to health checks
- Tests Metro stops cleanly when cleanup runs
- Tests no processes left running after shutdown

**Run:**
```bash
cd examples/react-native
devbox run test:metro:shutdown
```

## What These Tests Verify

### Port Allocation
- Unique ports allocated in range 8091-8199
- Different test suites get different ports
- Port allocation is stable across runs

### File Management
- Environment files created with unique run IDs
- Symlinks created for convenient access
- Files use format: `port-{suite}-{timestamp}-{pid}.txt`
- Symlinks use format: `env-{suite}.sh`

### Metro Lifecycle
- Metro starts on allocated port
- Metro responds to health checks
- Metro stops cleanly when requested
- No orphaned processes after shutdown

### Cleanup Behavior
- State files removed on cleanup
- Metro process terminated properly
- No port conflicts on subsequent runs

## Common Issues

### Metro Not Stopping
If Metro doesn't stop properly:
1. Check if cleanup process has dependency on `metro-bundler: process_healthy`
2. Verify cleanup explicitly calls `metro.sh stop {suite}`
3. Check shutdown handler is configured with timeout

### Port Conflicts
If you get port allocation errors:
1. Check for orphaned Metro processes: `lsof -i :8091-8199`
2. Kill orphaned processes: `kill $(lsof -ti :PORT)`
3. Clean up state files: `metro.sh clean {suite}`

### Test Failures
If tests fail:
1. Check logs in `test-results/metro-shutdown-logs/`
2. Verify Node.js and npm are available
3. Ensure React Native project has node_modules installed

## Architecture

### Unique Run IDs
Each test suite run gets a unique ID in format `{timestamp}-{pid}`:
- Prevents conflicts when running multiple test suites in parallel
- Allows cleanup to target specific run's files
- Enables debugging by preserving file history

### Symlink Strategy
- Unique files: `env-android-1234567890-12345.sh` (isolated)
- Symlinks: `env-android.sh` → unique file (convenient)
- Test suites use symlinks for current run
- Cleanup can target unique files by run ID

### Shutdown Handling
Two-layer approach:
1. **Explicit stop in cleanup** - Cleanup process calls `metro.sh stop`
2. **Shutdown handler** - Backup mechanism when process-compose exits

This ensures Metro stops reliably in both normal and error scenarios.
