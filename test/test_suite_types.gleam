import ccl_core
import gleam/dynamic/decode
import gleam/io
import gleam/json
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

// Types for typed parsing tests
pub type TypedTestCase {
  TypedTestCase(
    name: String,
    description: String,
    input: String,
    expected_flat: List(ccl_core.Entry),
    expected_typed: List(#(String, TypedValue)),  // path -> typed value pairs
    parse_options: ParseOptions,
    api_calls: List(String),
    tags: List(String),
  )
}

pub type TypedValue {
  StringVal(String)
  IntVal(Int)
  FloatVal(Float)
  BoolVal(Bool)
  EmptyVal
}

pub type ParseOptions {
  ParseOptions(
    parse_integers: Bool,
    parse_floats: Bool,
    parse_booleans: Bool,
  )
}

// Load and parse JSON test suite
pub fn get_test_cases() -> List(TestCase) {
  case load_test_suite() {
    Ok(test_suite) -> test_suite.tests
    Error(_) -> []
  }
}

pub fn get_error_test_cases() -> List(ErrorTestCase) {
  case load_test_suite() {
    Ok(test_suite) -> test_suite.error_tests
    Error(_) -> []
  }
}

pub fn get_typed_parsing_test_cases() -> List(TypedTestCase) {
  case load_test_suite() {
    Ok(test_suite) -> test_suite.typed_parsing_tests
    Error(_) -> []
  }
}

// JSON test suite structure decoder
type TestSuite {
  TestSuite(
    tests: List(TestCase), 
    error_tests: List(ErrorTestCase),
    typed_parsing_tests: List(TypedTestCase),
  )
}

// Load and parse JSON test suite
fn load_test_suite() -> Result(TestSuite, String) {
  case simplifile.read("ccl-test-suite/ccl-test-suite.json") {
    Ok(content) -> {
      let test_suite_decoder = {
        use tests <- decode.field("tests", decode.list(test_case_decoder()))
        use error_tests <- decode.field(
          "error_tests",
          decode.list(error_test_case_decoder()),
        )
        // For now, just return empty list for typed parsing tests
        // Will implement full decoder later
        let typed_parsing_tests = []
        decode.success(TestSuite(tests:, error_tests:, typed_parsing_tests:))
      }

      case json.parse(content, test_suite_decoder) {
        Ok(parsed) -> Ok(parsed)
        Error(err) -> {
          io.println("JSON parse error occurred")
          Error("Failed to parse JSON")
        }
      }
    }
    Error(err) -> {
      io.println("File read error: " <> simplifile.describe_error(err))
      Error("Failed to read test suite file")
    }
  }
}

// Decoder for Entry objects
fn entry_decoder() -> decode.Decoder(ccl_core.Entry) {
  use key <- decode.field("key", decode.string)
  use value <- decode.field("value", decode.string)
  decode.success(ccl_core.Entry(key, value))
}

// Decoder for test cases
fn test_case_decoder() -> decode.Decoder(TestCase) {
  use name <- decode.field("name", decode.string)
  use description <- decode.field("description", decode.string)
  use input <- decode.field("input", decode.string)
  use expected <- decode.field("expected", decode.list(entry_decoder()))
  use tags <- decode.field("tags", decode.list(decode.string))
  decode.success(TestCase(name:, description:, input:, expected:, tags:))
}

// Decoder for error test cases
fn error_test_case_decoder() -> decode.Decoder(ErrorTestCase) {
  use name <- decode.field("name", decode.string)
  use description <- decode.field("description", decode.string)
  use input <- decode.field("input", decode.string)
  use expected_error <- decode.field("expected_error", decode.bool)
  use error_message <- decode.field("error_message", decode.string)
  use tags <- decode.field("tags", decode.list(decode.string))
  decode.success(ErrorTestCase(
    name:,
    description:,
    input:,
    expected_error:,
    error_message:,
    tags:,
  ))
}

// TODO: Implement full typed parsing test decoder later
// For now, using placeholder function to allow compilation
fn typed_test_case_decoder() -> decode.Decoder(TypedTestCase) {
  // Placeholder - will implement proper decoder later
  decode.success(TypedTestCase(
    name: "placeholder",
    description: "placeholder",
    input: "placeholder = value",
    expected_flat: [],
    expected_typed: [],
    parse_options: ParseOptions(parse_integers: True, parse_floats: True, parse_booleans: True),
    api_calls: [],
    tags: ["placeholder"],
  ))
}
