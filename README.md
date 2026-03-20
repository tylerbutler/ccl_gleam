# CCL Gleam

A Gleam implementation of [CCL (Categorical Configuration Language)](https://ccl.tylerbutler.com/) with an integrated test runner for the [ccl-test-data](https://github.com/CatConfLang/ccl-test-data) JSON test suite.

## Packages

This monorepo contains two packages:

| Package | Path | Description |
|---------|------|-------------|
| **ccl** | `packages/ccl/` | Core CCL library — parser, hierarchy builder, typed access, formatter |
| **ccl_test_runner** | `packages/ccl_test_runner/` | Test runner CLI, TUI viewer, and startest integration |

## Quick Start

```sh
# Install dependencies
just deps

# Run all tests
just test

# Run the CLI test runner
just run-tests

# Launch interactive TUI viewer
just view
```

## Available Functions

The CCL library implements:

- `parse` - Indentation-aware key-value parsing
- `print` - Structure-preserving output (round-trips with parse)
- `build_hierarchy` - Convert flat entries to nested objects
- `get_string` / `get_int` / `get_bool` / `get_float` / `get_list` - Typed access

## Development

See [DEV.md](DEV.md) for detailed development instructions.

```sh
gleam build    # Build all packages
gleam test     # Run tests
just ci        # Full CI check
```

## Test Suite Format

See the [CCL Test Suite Guide](https://ccl.tylerbutler.com/test-suite-guide/) for details on the JSON test format and expected results structure.
