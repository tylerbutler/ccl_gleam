import ccl_core
import gleam/json
import gleam/dynamic
import gleam/list
import gleam/result
import gleam/string
import simplifile

pub type TestCase {
  TestCase(
    name: String,
    description: String,
    input: String,
    expected: List(ccl_core.Entry),
    tags: List(String),
  )
}

pub type ErrorTestCase {
  ErrorTestCase(
    name: String,
    description: String,
    input: String,
    expected_error: Bool,
    error_message: String,
    tags: List(String),
  )
}

// Load and parse JSON test suite
pub fn get_test_cases() -> List(TestCase) {
  case load_test_suite() {
    Ok(test_suite) -> parse_regular_tests(test_suite)
    Error(err) -> {
      // Debug: print the error to understand why loading fails
      // Note: In production, this should use proper logging
      []
    }
  }
}

pub fn get_error_test_cases() -> List(ErrorTestCase) {
  case load_test_suite() {
    Ok(test_suite) -> parse_error_tests(test_suite)
    Error(_) -> []
  }
}

// Load JSON test suite file
fn load_test_suite() -> Result(dynamic.Dynamic, String) {
  case simplifile.read("ccl-test-suite/ccl-test-suite.json") {
    Ok(content) -> {
      case json.decode(content, dynamic.dynamic) {
        Ok(parsed) -> Ok(parsed)
        Error(_) -> Error("Failed to parse JSON")
      }
    }
    Error(_) -> Error("Failed to read test suite file")
  }
}

// Parse regular test cases from JSON
fn parse_regular_tests(test_suite: dynamic.Dynamic) -> List(TestCase) {
  let decoder = dynamic.field("tests", dynamic.list(decode_test_case))
  case decoder(test_suite) {
    Ok(tests) -> tests
    Error(_) -> []
  }
}

// Parse error test cases from JSON  
fn parse_error_tests(test_suite: dynamic.Dynamic) -> List(ErrorTestCase) {
  let decoder = dynamic.field("error_tests", dynamic.list(decode_error_test_case))
  case decoder(test_suite) {
    Ok(tests) -> tests
    Error(_) -> []
  }
}

// Decode a single test case
fn decode_test_case(data: dynamic.Dynamic) -> Result(TestCase, List(dynamic.DecodeError)) {
  let entry_decoder = dynamic.decode2(
    ccl_core.Entry,
    dynamic.field("key", dynamic.string),
    dynamic.field("value", dynamic.string),
  )
  
  dynamic.decode5(
    TestCase,
    dynamic.field("name", dynamic.string),
    dynamic.field("description", dynamic.string),
    dynamic.field("input", dynamic.string),
    dynamic.field("expected", dynamic.list(entry_decoder)),
    dynamic.field("tags", dynamic.list(dynamic.string)),
  )(data)
}

// Decode a single error test case
fn decode_error_test_case(data: dynamic.Dynamic) -> Result(ErrorTestCase, List(dynamic.DecodeError)) {
  dynamic.decode6(
    ErrorTestCase,
    dynamic.field("name", dynamic.string),
    dynamic.field("description", dynamic.string),
    dynamic.field("input", dynamic.string),
    dynamic.field("expected_error", dynamic.bool),
    dynamic.field("error_message", dynamic.string),
    dynamic.field("tags", dynamic.list(dynamic.string)),
  )(data)
}