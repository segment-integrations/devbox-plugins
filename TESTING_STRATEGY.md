# Testing Strategy

## Philosophy

Tests are organized into two categories with different purposes:

### Plugin Tests (Fast Unit Tests)
**Location**: `plugins/tests/{platform}/`
**Purpose**: Test plugin functions in isolation
**Duration**: < 1 minute each
**Run**: Frequently during development

### E2E Tests (Integration Tests)
**Location**: `examples/{platform}/tests/`
**Purpose**: Test complete workflows with real emulators/apps
**Duration**: 2-5 minutes each
**Run**: Before commits, in CI/CD

## Android Testing

### Plugin Tests (`plugins/tests/android/`)

All lightweight, no emulator launching:

**test-lib.sh**
- Tests utility functions (JSON, paths, strings)
- Pure logic, no external dependencies
- `devbox run test:plugin:android:lib`

**test-devices.sh**
- Tests device CRUD operations
- Lock file generation
- Device validation
- `devbox run test:plugin:android:devices`

**test-emulator-detection.sh**
- Tests detection functions
- Uses existing emulators if available
- No emulator launching
- `devbox run test:plugin:android:emulator-detection`

**test-emulator-modes.sh**
- Educational demonstration
- Documents pure vs normal mode
- No emulator launching
- `devbox run test:plugin:android:emulator-modes`

### E2E Tests (`examples/android/tests/`)

Orchestrated with process-compose:

**test-suite.yaml** (Single Emulator)
- Build → Sync → Emulator → Deploy → Verify → Cleanup
- 2-3 minutes
- `devbox run test:e2e` (from examples/android)
- `devbox run test:e2e:android` (from root)

## Test Organization

```
devbox-plugins/
├── plugins/tests/android/          # Plugin unit tests
│   ├── test-lib.sh                 # Fast (< 10s)
│   ├── test-devices.sh             # Fast (< 20s)
│   ├── test-emulator-detection.sh  # Fast (< 10s)
│   └── test-emulator-modes.sh      # Fast (< 10s)
│
└── examples/android/tests/         # E2E tests
    ├── test-suite.yaml             # Slow (2-3 min)
    └── test-summary.sh             # Helper script
```

## Running Tests

### During Development (Fast Feedback)
```bash
# Run all plugin unit tests
devbox run test:plugin:android:all

# Run specific plugin test
devbox run test:plugin:android:emulator-detection

# Total time: < 1 minute
```

### Before Commit (Comprehensive)
```bash
# Run lint + unit tests
devbox run test:fast

# Run standard E2E test
devbox run test:e2e:android

# Total time: 3-4 minutes
```

### Before Release (Full Coverage)
```bash
# Run all tests
devbox run test:fast
devbox run test:e2e:android

# Total time: 4-5 minutes
```

## Test Characteristics

### Plugin Tests ✓
- ✅ Fast (< 1 minute total)
- ✅ No heavy dependencies
- ✅ Test functions in isolation
- ✅ Simple shell scripts
- ✅ Can run in parallel
- ✅ No emulator launching
- ✅ Analyze existing state
- ✅ Run frequently

### E2E Tests ✓
- ✅ Complete workflows
- ✅ Real emulators and apps
- ✅ Process-compose orchestration
- ✅ Parallel process execution
- ✅ Readiness probes
- ✅ Proper cleanup
- ✅ Comprehensive coverage
- ✅ Run before commits/releases

## Best Practices

### When to Run Plugin Tests
- ✅ After modifying plugin scripts
- ✅ During active development
- ✅ Before every commit
- ✅ In CI/CD (fast feedback)

### When to Run E2E Tests
- ✅ Before creating PRs
- ✅ After major changes
- ✅ Before releases
- ✅ In CI/CD (comprehensive validation)

## CI/CD Integration

### PR Checks (Fast - 15-30 min)
```yaml
- name: Plugin Unit Tests
  run: devbox run test:plugin:android:all

- name: Standard E2E Test
  run: devbox run test:e2e:android
```

### Full E2E (Comprehensive - 45-60 min)
```yaml
- name: Min/Max Platform Tests
  run: |
    devbox run test:e2e:android  # API 21 and API 36
```

## Summary

**Key Principles**:
1. Plugin tests are lightweight unit tests (< 1 min total)
2. E2E tests use process-compose for complex orchestration (2-5 min each)
3. Multi-device support tested at both levels
4. Clear separation of concerns
5. Fast feedback loop for development
6. Comprehensive coverage for releases

This strategy provides:
- ⚡ Fast iteration during development
- 🎯 Targeted testing of specific functionality
- 🔒 Comprehensive validation before releases
- 🚀 Efficient CI/CD pipelines
- 📊 Clear understanding of what each test covers
