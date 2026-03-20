# Development Guide

This document provides detailed instructions for developing and contributing to ccl_gleam.

## Prerequisites

Ensure you have the following installed:

| Tool | Version | Purpose |
|------|---------|---------|
| Erlang/OTP | 27+ | BEAM runtime |
| Gleam | 1.11.0+ | Compiler and tooling |
| just | 1.38.0+ | Task runner |

**Recommended:** Use [mise](https://mise.jdx.dev/) or [asdf](https://asdf-vm.com/) with the provided `.mise.toml` file.

```bash
# With mise
mise install
```

## Getting Started

```bash
# Clone the repository
git clone <repo-url>
cd ccl_gleam

# Install dependencies
just deps

# Verify everything works
just ci
```

## Monorepo Structure

This repository contains two Gleam packages:

| Package | Path | Description |
|---------|------|-------------|
| `ccl` | `packages/ccl/` | Core CCL library (parser, hierarchy, access, format) |
| `ccl_test_runner` | `packages/ccl_test_runner/` | Test runner, CLI, and TUI (depends on `ccl` via path) |

The test runner depends on the CCL library via a path dependency in its `gleam.toml`:
```toml
ccl = { path = "../ccl" }
```

## Development Workflow

### Daily Development

```bash
# Check all code compiles
just check

# Run all tests
just test

# Format all code
just format
```

### Working on the CCL library

```bash
# Build only the CCL package
just build-ccl

# Run CCL library tests
just test-ccl
```

### Working on the test runner

```bash
# Build only the test runner
just build-runner

# Run test runner tests
just test-runner
```

### Before Committing

```bash
# Run full CI checks locally
just pr
```

### Before Merging to Main

```bash
# Run extended checks
just main
```

## Running the Test Runner

```bash
# Run against default test data
just run-tests

# Run against specific directory
just run-tests ./custom-test-data/

# Run with specific functions
just run-tests-with-functions ./ccl-test-data/ parse,print

# Launch TUI viewer
just view
```

## Code Style

### Formatting

This project uses Gleam's built-in formatter:

```bash
just format
```

### Error Handling

Use Result types for fallible operations:

```gleam
pub fn load_tests(path: String) -> Result(TestSuite, String) {
  // ...
}
```

### Pattern Matching

Handle all cases exhaustively:

```gleam
case result {
  Ok(suite) -> run_suite(suite)
  Error(msg) -> log_error(msg)
}
```

## Testing

```bash
# Run all tests across both packages
just test

# Run specific test module (from test runner package)
cd packages/ccl_test_runner && gleam test -- --test-name-filter="loader"
```

## Commit Messages

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(parser): add support for dotted keys
fix(loader): handle empty test files
docs: update CLI usage examples
```

## Troubleshooting

### Build Errors

```bash
just clean
just deps
just build
```
