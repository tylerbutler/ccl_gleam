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

## Development Workflow

### Daily Development

```bash
# Check your code compiles
just check

# Run tests
just test

# Format code
just format
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

## Project Structure

```
.
├── src/
│   ├── ccl_test_runner.gleam   # CLI entry point
│   ├── test_runner.gleam       # Core test execution
│   ├── test_loader.gleam       # JSON test loading
│   ├── test_filter.gleam       # Capability filtering
│   ├── test_types.gleam        # Type definitions
│   ├── cli/                    # CLI commands and flags
│   └── tui/                    # TUI viewer
├── test/
│   └── ccl_test_runner_test.gleam
├── packages/
│   └── ccl_types/              # Shared types
├── .claude/commands/           # Custom Claude commands
├── gleam.toml
└── justfile
```

## Running the Test Runner

```bash
# Run against default test data
just run-tests

# Run against specific directory
just run ../ccl-test-data/generated_tests/

# Run with specific functions
just run-tests-with-functions ../ccl-test-data/generated_tests/ parse,print

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
# Run all tests
just test

# Run specific test module
gleam test -- --filter "loader"
```

## Commit Messages

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(parser): add support for dotted keys
fix(loader): handle empty test files
docs: update CLI usage examples
```

## Troubleshooting

### Test Data Not Found

Ensure ccl-test-data is cloned as a sibling directory:

```bash
cd ..
git clone <ccl-test-data-url>
```

### Build Errors

```bash
just clean
just deps
just build
```
