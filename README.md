# CCL Test Runner

A test runner for CCL (Categorical Configuration Language) implementations in Gleam. Loads and runs tests from the [ccl-test-data](https://github.com/CatConfLang/ccl-test-data) JSON test suite.

## Usage

```sh
# Run tests with default config (parse-only)
gleam run -- ../ccl-test-data/generated_tests/

# Run tests for specific functions
gleam run -- ../ccl-test-data/generated_tests/ --functions parse,print,build_hierarchy

# Show help
gleam run -- --help
```

## Available Functions

The test runner filters tests based on which CCL functions your implementation supports:

- `parse` - Basic key-value parsing
- `print` - Print entries back to CCL format
- `build_hierarchy` - Convert flat entries to nested objects
- `get_string` - Get string value at path
- `get_int` - Get integer value at path
- `get_bool` - Get boolean value at path
- `get_float` - Get float value at path
- `get_list` - Get list value at path

## Integrating Your Implementation

The test runner uses a `CclImplementation` interface. Replace the mock implementation in `src/ccl_test_runner.gleam` with your actual CCL functions:

```gleam
import test_runner.{type CclImplementation, CclImplementation}

fn my_implementation() -> CclImplementation {
  CclImplementation(
    parse: my_parse,
    print: my_print,
    build_hierarchy: my_build_hierarchy,
    get_string: my_get_string,
    get_int: my_get_int,
    get_bool: my_get_bool,
    get_float: my_get_float,
    get_list: my_get_list,
  )
}
```

## Development

```sh
gleam build    # Build the project
gleam test     # Run unit tests
gleam run      # Run the test runner
```

## Test Suite Format

See the [CCL Test Suite Guide](https://ccl.tylerbutler.com/test-suite-guide/) for details on the JSON test format and expected results structure.
