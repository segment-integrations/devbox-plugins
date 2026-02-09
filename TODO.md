# TODO

## Priority 1: iOS Refactor & Core Code Changes

- [ ] Refactor iOS scripts/ and tests/ to follow Android layered architecture patterns
  - [ ] Implement script layering (lib/ → platform/ → domain/ → user/ → init/)
  - [ ] Align test organization and naming conventions
  - [ ] Standardize shell shebangs to POSIX sh

- [ ] Move Android unit tests to plugins/android/tests/
  - [ ] Create or move test-lib.sh
  - [ ] Create or move test-devices.sh
  - [ ] Update plugin.json references

- [ ] Create iOS device management tests in plugins/ios/tests/
  - [ ] Add test-devices.sh

## Priority 2: Minor Code Changes & Fixes

- [ ] Fix devbox-mcp README npm package name references

- [ ] Add E2E test for devbox-mcp plugin to CI workflows

## Priority 3: Cleanup

- [ ] Deep cleanup of all git-indexed files
  - [ ] Remove dead code and unused files
  - [ ] Standardize formatting and style across all scripts
  - [ ] Fix naming inconsistencies
  - [ ] Review error messages for clarity and actionability
  - [ ] Update .gitignore (.env, *.log, .swp, .swo)

## Priority 4: Documentation

- [ ] Expand iOS REFERENCE.md documentation
  - [ ] Match Android REFERENCE.md comprehensiveness (~80 lines)
  - [ ] Document all device management commands
  - [ ] Document all configuration options
  - [ ] Document all environment variables

- [ ] Create iOS LAYERS.md documentation
  - [ ] Explain lib → platform → domain → user → init layering

- [ ] Expand React Native REFERENCE.md
  - [ ] Complete command reference
  - [ ] Document all environment variables
  - [ ] Document all configuration options

- [ ] Create example project README files
  - [ ] examples/android/README.md with quick start
  - [ ] examples/ios/README.md with quick start
  - [ ] examples/react-native/README.md (if missing)

- [ ] Document MCP server usage with Claude Code examples

## Priority 5: Repository Setup & Finishing Touches

- [ ] Create LICENSE file (MIT)

- [ ] Create CHANGELOG.md for release tracking
  - [ ] Add v1.0.0 release notes
  - [ ] Document breaking changes

- [ ] Create standard repository files
  - [ ] CONTRIBUTING.md
  - [ ] CODE_OF_CONDUCT.md
  - [ ] SECURITY.md
  - [ ] RELEASE.md with v1.0.0 checklist

- [ ] Add CI/CD badges to main README
  - [ ] GitHub Actions status badge
  - [ ] npm package version badge

- [ ] Create wiki with architecture overview and design decisions
  - [ ] Document script layering architecture
  - [ ] Document device management workflows
  - [ ] Document plugin composition patterns

- [ ] Write getting started guides for new users
  - [ ] Quick start for Android development
  - [ ] Quick start for iOS development
  - [ ] Quick start for React Native development
  - [ ] Troubleshooting guide

- [ ] Set up git post-commit hook for documentation-driven AI development
  - [ ] Create hook that launches Claude to examine commits
  - [ ] Check for wiki/design doc drift
  - [ ] Auto-suggest documentation updates

- [ ] Add unified formatting tools
  - [ ] Configure treefmt + prettier/shfmt/swiftformat/ktlint/markdownlint
  - [ ] Set up pre-commit hooks for automatic formatting

- [ ] Add npm publish workflow for devbox-mcp plugin

- [ ] Create v1.0.0 release automation
  - [ ] .github/workflows/release.yml for semantic versioning
  - [ ] Align all plugin versions (0.1.0 → 1.0.0)

- [ ] Add dependabot workflow for dependency updates

- [ ] Add coverage reporting and performance benchmarks

---

**Last Updated:** 2026-02-07
