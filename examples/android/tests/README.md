# Android E2E Tests

This directory contains the E2E test suite for the Android example app.

## Running Tests

From the `examples/android` directory:

```bash
# Run complete E2E test (build → emulator → deploy → verify)
devbox run test:e2e

# Run in deterministic mode (fresh emulator, clean state)
TEST_PURE=1 devbox run test:e2e

# Run with TUI for interactive monitoring
TEST_TUI=true devbox run test:e2e
```

## Test Suite

The test suite (`test-suite.yaml`) orchestrates:
1. **Build** - Gradle assembleDebug
2. **Sync AVDs** - Ensure emulator definitions match device configs
3. **Start Emulator** - Boot Android emulator (or reuse existing)
4. **Deploy** - Install and launch APK
5. **Cleanup** - Stop app (and emulator in pure mode)
6. **Summary** - Display results

## Copy to Your Project

To add testing to your own Android project:

1. **Include the plugin:**
   ```json
   {
     "include": ["plugin:android"]
   }
   ```

2. **Configure for your app:**
   ```json
   {
     "env": {
       "ANDROID_APP_APK": "app/build/outputs/apk/debug/app-debug.apk",
       "ANDROID_APP_ID": "com.mycompany.myapp"
     }
   }
   ```

3. **Run plugin E2E test:**
   ```bash
   devbox run test:e2e
   ```

4. **Optional: Copy example tests:**
   ```bash
   cp -r examples/android/tests/ your-project/tests/
   # Edit and customize for your needs
   ```

## Test Configuration

Configure via environment variables in `devbox.json`:

```json
{
  "env": {
    "ANDROID_APP_APK": "path/to/your/app.apk",
    "ANDROID_APP_ID": "com.your.package.name",
    "ANDROID_DEFAULT_DEVICE": "max",
    "ANDROID_SERIAL": "emulator-5554"
  }
}
```

## Learn More

- Plugin tests: `plugins/android/tests/README.md`
- Plugin reference: `plugins/android/REFERENCE.md`
