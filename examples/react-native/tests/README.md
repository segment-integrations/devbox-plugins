# React Native Test Suites

This directory contains E2E test suites for React Native development.

## Quick Start

```bash
# Run iOS tests only (fast - skips Android SDK)
./tests/run-ios-tests.sh

# Run Android tests only (fast - skips iOS setup)
./tests/run-android-tests.sh

# Run all tests (both platforms)
devbox run test:e2e:all
```

## Test Suites

- **test-suite-ios.yaml** - iOS simulator build and deployment
- **test-suite-android.yaml** - Android emulator build and deployment
- **test-suite-all.yaml** - Both platforms in parallel

## Platform-Specific Optimization

The wrapper scripts (`run-ios-tests.sh` and `run-android-tests.sh`) optimize startup time by skipping the unused platform:

- `run-ios-tests.sh` sets `ANDROID_SKIP_DOWNLOADS=1` to skip Android SDK Nix flake evaluation
- `run-android-tests.sh` sets `IOS_SKIP_SETUP=1` to skip iOS environment setup

This is particularly useful in CI/CD pipelines where you split platform tests into separate jobs.

## Running via devbox

You can also run tests through devbox commands:

```bash
# Standard commands (no optimization)
devbox run test:e2e:ios
devbox run test:e2e:android
devbox run test:e2e:all

# Manual optimization
ANDROID_SKIP_DOWNLOADS=1 devbox run test:e2e:ios
IOS_SKIP_SETUP=1 devbox run test:e2e:android
```

## Build Configuration

By default, E2E tests use Release builds for better production-like behavior. You can override this with the `IOS_BUILD_CONFIG` environment variable:

```bash
# Run iOS tests with Release build (default)
devbox run test:e2e:ios

# Run iOS tests with Debug build
IOS_BUILD_CONFIG=Debug devbox run test:e2e:ios

# Run all platform tests with Debug build
IOS_BUILD_CONFIG=Debug devbox run test:e2e:all
```

## Test Logs

Test logs are written to `reports/react-native-{platform}-e2e-logs/`

## Interactive Development

For interactive development with full environment setup (both platforms available):

```bash
devbox shell
```

This gives you a fully configured environment with both Android SDK and iOS tooling ready to use.
