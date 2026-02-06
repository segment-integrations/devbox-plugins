# Testing Guide

This repository includes comprehensive testing for all mobile plugins and example projects.

## Quick Start

```bash
# Run all tests (unit + lint)
devbox run test

# Run E2E tests (sequential with live output)
devbox run test:e2e

# Sync examples with latest plugins
devbox run sync
```

## Available Commands

### Unit Testing

| Command | Description |
|---------|-------------|
| `devbox run test` | All plugin tests (lint + unit) |
| `devbox run test:unit` | All unit tests only |
| `devbox run test:android` | Android plugin tests |
| `devbox run test:ios` | iOS plugin tests |
| `devbox run test:rn` | React Native plugin tests |

### E2E Testing

| Command | Description |
|---------|-------------|
| `devbox run test:e2e` | **All E2E tests (sequential, live output)** 📺 |
| `devbox run test:e2e:parallel` | All E2E tests (parallel, faster) ⚡ |
| `devbox run test:e2e:android` | Android example E2E |
| `devbox run test:e2e:ios` | iOS example E2E |
| `devbox run test:e2e:rn` | React Native example E2E |

### Linting

| Command | Description |
|---------|-------------|
| `devbox run lint` | Lint all plugins |
| `devbox run lint:android` | Lint Android only |
| `devbox run lint:ios` | Lint iOS only |
| `devbox run lint:rn` | Lint React Native only |

### Other

| Command | Description |
|---------|-------------|
| `devbox run sync` | Sync example projects |
| `devbox run check:workflows` | Validate GitHub Actions |

## E2E Tests Explained

### Sequential E2E (Default)

```bash
devbox run test:e2e
```

**Strategy:** Tests run one at a time with live output

**Benefits:** See what's happening in real-time, easier debugging

**When to use:** Development, debugging, watching progress

### Parallel E2E (Faster)

```bash
devbox run test:e2e:parallel
```

**Strategy:** Android + iOS run concurrently, then React Native

**Benefits:** ~50% faster, output shown at completion

**When to use:** CI/CD, quick validation

## More Information

See [devbox/plugins/tests/README.md](devbox/plugins/tests/README.md) for complete testing documentation.

## Running E2E Tests Directly

E2E tests can also be run directly without devbox:

```bash
# From the repository root
bash devbox/tests/e2e-sequential.sh       # All tests sequentially
bash devbox/tests/e2e-all.sh              # All tests in parallel
bash devbox/tests/e2e-android.sh          # Android only
bash devbox/tests/e2e-ios.sh              # iOS only
bash devbox/tests/e2e-react-native.sh     # React Native only
```
