# Testing Guide for CCL Gleam Implementation

## Running Tests

### Quick Start

```bash
# Run all tests
gleam test

# Run tests for a specific package
cd packages/ccl && gleam test
cd packages/ccl_core && gleam test
cd packages/ccl_test_loader && gleam test
```

### Test Framework

This project uses **gleeunit** for testing, which is the standard Gleam test framework.

## Project Test Structure

```
ccl_gleam/
├── test/                          # Main test directory
│   ├── ccl_gleam_test.gleam     # Main test runner
│   └── test_suite_types.gleam   # JSON test loader types
├── packages/
│   ├── ccl/test/                 # Full library tests
│   ├── ccl_core/test/           # Core library tests
│   └── ccl_test_loader/test/    # Test loader tests
└── ccl-test-suite/               # JSON test files
```

## Adding Tests

### Adding Gleam Unit Tests

Create a new test file in the appropriate `test/` directory:

```gleam
import gleeunit/should
import ccl

pub fn parse_simple_test() {
  let input = "key = value"
  let result = ccl.parse(input)
  
  result
  |> should.be_ok
  |> should.equal([ccl.Entry("key", "value")])
}
```

### Using the JSON Test Suite

The project uses JSON test files for cross-language compatibility:

```gleam
import test_suite_types

pub fn run_json_tests() {
  // Load test cases from JSON
  let test_cases = test_suite_types.get_entry_parsing_tests()
  
  // Run each test
  list.each(test_cases, fn(test_case) {
    let result = ccl.parse(test_case.input)
    case test_case.expected {
      Ok(expected) -> should.equal(result, Ok(expected))
      Error(_) -> should.be_error(result)
    }
  })
}
```

## Test Categories

The Gleam implementation runs tests from these JSON files:

- `ccl-entry-parsing.json` - Core parsing tests
- `ccl-entry-processing.json` - Comment filtering tests
- `ccl-object-construction.json` - Nested object tests
- `ccl-typed-parsing-examples.json` - Type conversion tests
- `ccl-pretty-printer.json` - Formatting tests
- `ccl-errors.json` - Error handling tests

## Test Utilities

### Loading Test Data

Use the `ccl_test_loader` package to load JSON test files:

```gleam
import ccl_test_loader

// Load a specific test file
let tests = ccl_test_loader.load_file("ccl-test-suite/ccl-entry-parsing.json")
```

### Running Test Suites

The main test runner (`test/ccl_gleam_test.gleam`) orchestrates all tests:

```gleam
pub fn main() {
  gleeunit.main()
}

// Individual test functions
pub fn entry_parsing_tests() {
  run_test_suite("Entry Parsing", test_suite_types.get_entry_parsing_tests())
}

pub fn object_construction_tests() {
  run_test_suite("Object Construction", test_suite_types.get_object_tests())
}
```

## Debugging Tests

### Verbose Output

Enable detailed test output:

```gleam
import gleam/io

pub fn debug_test() {
  let input = "key = value"
  io.println("Input: " <> input)
  
  let result = ccl.parse(input)
  io.println("Result: " <> string.inspect(result))
  
  should.be_ok(result)
}
```

### Testing Specific Features

Test individual CCL features in isolation:

```gleam
// Test multiline values
pub fn multiline_test() {
  let input = "desc = line1\n  line2\n  line3"
  let result = ccl.parse(input)
  // Verify multiline handling
}

// Test nested sections
pub fn nesting_test() {
  let input = "section =\n  key = value"
  let result = ccl.parse(input)
  // Verify nesting
}
```

## Performance Testing

For performance benchmarks:

```gleam
import gleam/erlang/process

pub fn benchmark_parsing() {
  let start = process.system_time(process.Millisecond)
  
  // Run parsing 1000 times
  list.range(1, 1000)
  |> list.each(fn(_) { ccl.parse(large_config) })
  
  let end = process.system_time(process.Millisecond)
  io.println("Time: " <> int.to_string(end - start) <> "ms")
}
```

## Continuous Integration

Tests run automatically on CI for:
- All commits to main branch
- All pull requests
- Tagged releases

The CI configuration uses:
```yaml
- uses: erlef/setup-beam@v1
  with:
    otp-version: "26.0"
    gleam-version: "1.0.0"
- run: gleam test
```

## Troubleshooting

### Common Issues

1. **Test files not found**: Ensure you're running from the project root
2. **JSON decode errors**: Check test file format matches expected schema
3. **Type errors**: Run `gleam check` to identify type mismatches

### Getting Help

- Check existing tests for examples
- Review the [Gleam API Guide](gleam-api-guide.md)
- Consult gleeunit documentation
- Open an issue on GitHub

## Test Coverage Goals

The Gleam implementation aims for:
- 100% coverage of CCL specification features
- All JSON test suite cases passing
- Edge case handling
- Performance regression prevention