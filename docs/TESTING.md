# CCL Test Suite Documentation

## Overview

The CCL test suite is organized by the 4-level CCL architecture with an additional pretty printer test layer:

- **Level 1**: Entry Parsing (`ccl-test-suite/ccl-entry-parsing.json`)
- **Level 2**: Entry Processing (`ccl-test-suite/ccl-entry-processing.json`) 
- **Level 3**: Object Construction (`ccl-test-suite/ccl-object-construction.json`)
- **Level 4**: Typed Parsing (`ccl-test-suite/ccl-typed-parsing-examples.json`)
- **Pretty Printer**: Round-trip and canonical formatting (`ccl-test-suite/ccl-pretty-printer.json`)
- **Error Handling**: Parse errors (`ccl-test-suite/ccl-errors.json`)

## Adding New Test Cases

### Step 1: Add Test to JSON File

Choose the appropriate test suite file and add your test case:

```json
{
  "name": "descriptive_test_name",
  "input": "ccl input text",
  "expected": [
    {"key": "parsed_key", "value": "parsed_value"}
  ],
  "meta": {"tags": ["category"], "level": 1}
}
```

### Step 2: Pretty Printer Tests (Special Format)

For pretty printer tests, use this format:

```json
{
  "name": "test_name",
  "property": "round_trip|canonical_format|deterministic", 
  "input": "ccl input text",
  "expected_canonical": "expected pretty printed output",
  "meta": {"tags": ["category"], "level": "pretty-print"}
}
```

**Property Types:**
- `round_trip`: Test that `parse(pretty_print(parse(input))) == parse(input)`
- `canonical_format`: Test that `pretty_print(parse(input)) == expected_canonical`
- `deterministic`: Test that multiple calls to pretty_print produce identical output

### Step 3: Update Type Definitions (if needed)

If adding new test structure, update `test/test_suite_types.gleam`:

```gleam
// Add new decoder function
fn new_test_decoder() -> decode.Decoder(NewTestType) {
  // Decoder implementation
}

// Add new getter function  
pub fn get_new_tests() -> List(NewTestType) {
  load_test_file("ccl-test-suite/new-test-file.json")
}
```

### Step 4: Update Test Runner

Add your test execution in `test/ccl_gleam_test.gleam`:

```gleam
pub fn new_test_category() {
  io.println("\n=== NEW TEST CATEGORY ===")
  let test_cases = test_suite_types.get_new_tests()
  
  // Test execution logic
  run_test_cases(test_cases, "New Category")
}
```

### Step 5: Update Test Overview

Update the `print_test_overview()` function to include your new test count:

```gleam
let new_test_count = list.length(test_suite_types.get_new_tests())
let total_count = existing_counts + new_test_count + ...

io.println("New Test Category: " <> string.inspect(new_test_count) <> " tests")
```

## CCL Behavior Guidelines

When writing tests, follow these CCL parsing and formatting rules:

### Whitespace Handling
- **Keys**: Trim all leading/trailing whitespace
- **Values**: Strip leading spaces, preserve trailing tabs/spaces
- **Line endings**: Normalize CRLF → LF  
- **Empty values**: `key =` (no trailing space in canonical format)

### Multiline Values  
- Preserve exact whitespace structure within multiline content
- Don't normalize internal spacing in multiline values
- Empty multiline sections should have empty string values

### List Formatting
- Empty keys use `= value` format (no space before equals)
- Regular keys use `key = value` format (spaces around equals)

### Tab Preservation
- Leading tabs in values are preserved (after leading space removal)
- Trailing tabs in values are stripped during parsing
- Tabs within values are preserved exactly

## Example Test Cases

### Basic Entry Parsing
```json
{
  "name": "basic_key_value",
  "input": "name = Alice\nage = 42", 
  "expected": [
    {"key": "name", "value": "Alice"},
    {"key": "age", "value": "42"}
  ],
  "meta": {"tags": ["basic"], "level": 1}
}
```

### Pretty Printer Round-trip
```json
{
  "name": "round_trip_basic",
  "property": "round_trip",
  "input": "key = value\nnested =\n  sub = val",
  "expected_canonical": "key = value\nnested =\n  sub = val",
  "meta": {"tags": ["round-trip", "basic"], "level": "pretty-print"}
}
```

### Error Test
```json
{
  "name": "invalid_syntax",
  "input": "invalid input without equals",
  "expected_error": true,
  "error_message": "expected equals sign",
  "meta": {"tags": ["error", "syntax"], "level": 1}
}
```

## Running Tests

```bash
# Run all tests
gleam test

# Check specific components  
gleam check
gleam build
```

The test runner will show:
- Test counts by category
- Pass/fail status for each level
- Details about any failing tests

All tests must pass before merging changes.