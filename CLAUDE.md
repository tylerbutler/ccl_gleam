# ccl_gleam - Gleam CCL Test Runner

CCL (Categorical Configuration Language) test runner implementation in Gleam, targeting the Erlang VM (BEAM).

## Build Commands

```bash
gleam build              # Compile project
gleam test               # Run unit tests
gleam check              # Type check without building
gleam format             # Format code
gleam run -- <args>      # Run test runner
```

## Just Commands

```bash
just deps                # Install dependencies
just build               # Build project
just test                # Run unit tests
just format              # Format code
just check               # Type check
just run <dir>           # Run test runner against directory
just run-tests           # Run against default test data
just ci                  # Full CI check (format, build, test)
```

## Project Structure

```
src/
├── ccl_test_runner.gleam   # CLI entry point with mock implementation
├── test_runner.gleam       # Core test execution logic
├── test_loader.gleam       # JSON test suite loading
├── test_filter.gleam       # Test filtering by capabilities
├── test_types.gleam        # Type definitions for test data
└── debug_parse.gleam       # Debug utilities
test/
└── ccl_test_runner_test.gleam
packages/
└── ccl_types/              # Shared type definitions
```

## Integration with ccl-test-data

This test runner consumes the JSON test suite from `../ccl-test-data/generated_tests/`:

```bash
# Run with default parse-only config
gleam run -- ../ccl-test-data/generated_tests/

# Run with specific functions
gleam run -- ../ccl-test-data/generated_tests/ --functions parse,print,build_hierarchy
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
- `gleeunit` - Testing framework (dev)

## Development Guidelines

- Use Result types for error handling, not exceptions
- Pattern match exhaustively
- Follow Gleam's built-in formatter output
- Test both happy path and error cases
- Keep functions small and focused
