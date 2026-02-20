# ccl_gleam - Gleam CCL Test Runner

CCL (Categorical Configuration Language) test runner implementation in Gleam, targeting the Erlang VM (BEAM).

## Commands

```bash
# Core development
just deps                # Install dependencies
just build               # Build project
just test                # Run unit tests
just format              # Format code
just check               # Type check
just ci                  # Full CI check (format, build, test)
just clean               # Clean build artifacts

# Running the test runner
just run-tests [dir]     # Run against test data (default: ../ccl-test-data/generated_tests/)
just run-tests-with-functions [dir] [funcs]  # Run with specific functions
just list [dir]          # List test files with counts
just stats [dir]         # Show test suite statistics
just view [dir]          # Launch interactive TUI viewer
just run <args>          # Run test runner with raw arguments
just debug-parse         # Run debug JSON parser
```

## Project Structure

```
src/
├── ccl_test_runner.gleam      # CLI entry point (glint-based)
├── test_runner.gleam          # Core test execution logic
├── test_loader.gleam          # JSON test suite loading
├── test_filter.gleam          # Test filtering by capabilities
├── test_types.gleam           # Type definitions for test data
├── debug_parse.gleam          # Debug utilities
├── cli/
│   ├── commands.gleam         # CLI subcommands (run, list, stats, view)
│   └── flags.gleam            # CLI flag definitions
├── render/
│   ├── ccl_input.gleam        # CCL input rendering
│   ├── entries.gleam          # Entry list rendering
│   ├── error.gleam            # Expected error rendering
│   ├── list.gleam             # List value rendering
│   ├── object.gleam           # Nested object rendering (JSON format)
│   ├── theme.gleam            # Color/style theming
│   ├── typed.gleam            # Typed value rendering
│   ├── value.gleam            # Single value rendering with visible whitespace
│   └── whitespace.gleam       # Whitespace visualization utilities
└── tui/
    ├── app.gleam              # TUI application entry point
    ├── components.gleam       # Reusable TUI components
    ├── model.gleam            # Application state (Elm architecture)
    ├── msg.gleam              # Message types
    ├── update.gleam           # State transitions
    ├── view.gleam             # Main view dispatcher
    └── views/
        ├── file_list.gleam    # Test file browser
        ├── test_detail.gleam  # Individual test detail view
        └── test_list.gleam    # Test list within a file
test/
├── ccl_test_runner_test.gleam
└── render/
    ├── ccl_input_test.gleam
    ├── entries_test.gleam
    ├── error_test.gleam
    ├── list_test.gleam
    ├── object_test.gleam
    ├── typed_test.gleam
    ├── value_test.gleam
    └── whitespace_test.gleam
```

## Integration with ccl-test-data

This test runner consumes the JSON test suite from `../ccl-test-data/generated_tests/`:

```bash
# Run with default parse-only config
just run-tests

# Run with specific functions
just run-tests-with-functions ../ccl-test-data/generated_tests/ parse,print,build_hierarchy

# List test files with counts
just list

# Show test suite statistics
just stats

# Launch interactive TUI viewer
just view
```

### Available CCL Functions

- `parse` - Basic key-value parsing
- `print` - Print entries back to CCL format
- `build_hierarchy` - Convert flat entries to nested objects
- `get_string` - Get string value at path
- `get_int` - Get integer value at path
- `get_bool` - Get boolean value at path
- `get_float` - Get float value at path
- `get_list` - Get list value at path

## Architecture

### Test Flow

1. **Load**: `test_loader` reads JSON test files into `TestSuite` structures
2. **Filter**: `test_filter` selects tests matching implementation capabilities
3. **Execute**: `test_runner` runs tests against a `CclImplementation`
4. **Report**: Results aggregated with pass/fail/skip counts

### Implementation Interface

The `CclImplementation` type defines the contract for CCL implementations:

```gleam
type CclImplementation {
  CclImplementation(
    parse: fn(String) -> Result(List(Entry), String),
    print: fn(List(Entry)) -> String,
    build_hierarchy: fn(List(Entry)) -> CCL,
    get_string: fn(CCL, List(String)) -> Result(String, String),
    get_int: fn(CCL, List(String)) -> Result(Int, String),
    get_bool: fn(CCL, List(String)) -> Result(Bool, String),
    get_float: fn(CCL, List(String)) -> Result(Float, String),
    get_list: fn(CCL, List(String)) -> Result(List(String), String),
  )
}
```

### Test Case Structure

Tests use feature-based tagging for capability filtering:
- **functions**: Required CCL functions (`parse`, `build_hierarchy`, etc.)
- **behaviors**: Runtime behaviors (`crlf_normalize_to_lf`, `toplevel_indent_strip`)
- **variants**: Implementation variants (`reference_compliant`)
- **features**: Optional features (`comments`, `dotted-keys`)

## Dependencies

- `gleam_stdlib` - Standard library
- `gleam_json` - JSON parsing
- `simplifile` - File system operations
- `birch` - Structured logging
- `argv` - CLI argument parsing
- `glint` - CLI framework with subcommands and flags
- `shore` - Terminal UI framework (Elm architecture)
- `gleam_erlang` / `gleam_otp` - BEAM interop
- `filepath` - File path utilities
- `gleeunit` - Testing framework (dev)

## Development Guidelines

- Use Result types for error handling, not exceptions
- Pattern match exhaustively
- Follow Gleam's built-in formatter output
- Test both happy path and error cases
- Keep functions small and focused
