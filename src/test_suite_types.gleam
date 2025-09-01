import ccl
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{type Option}
import gleam/result
import simplifile

pub type TestSuite {
  TestSuite(
    test_suite: String,
    version: String,
    description: Option(String),
    tests: List(TestCase),
    error_tests: Option(List(ErrorTestCase)),
  )
}

pub type TestCase {
  TestCase(
    name: String,
    description: String,
    input: String,
    expected: List(ccl.Entry),
    tags: List(String),
  )
}

pub type ErrorTestCase {
  ErrorTestCase(
    name: String,
    description: String,
    input: String,
    expected_error: Bool,
    error_message: Option(String),
    tags: List(String),
  )
}

pub type ExpectedEntry {
  ExpectedEntry(key: String, value: String)
}

// JSON Decoders
fn expected_entry_decoder() {
  use key <- decode.field("key", decode.string)
  use value <- decode.field("value", decode.string)
  decode.success(ExpectedEntry(key: key, value: value))
}

fn test_case_decoder() {
  use name <- decode.field("name", decode.string)
  use description <- decode.field("description", decode.string)
  use input <- decode.field("input", decode.string)
  use expected <- decode.field(
    "expected",
    decode.list(expected_entry_decoder()),
  )
  use tags <- decode.field("tags", decode.list(decode.string))

  // Convert ExpectedEntry list to ccl.Entry list
  let ccl_entries =
    expected
    |> list.map(fn(e) { ccl.Entry(e.key, e.value) })

  decode.success(TestCase(
    name: name,
    description: description,
    input: input,
    expected: ccl_entries,
    tags: tags,
  ))
}

fn error_test_case_decoder() {
  use name <- decode.field("name", decode.string)
  use description <- decode.field("description", decode.string)
  use input <- decode.field("input", decode.string)
  use expected_error <- decode.field("expected_error", decode.bool)
  use error_message <- decode.field(
    "error_message",
    decode.optional(decode.string),
  )
  use tags <- decode.field("tags", decode.list(decode.string))

  decode.success(ErrorTestCase(
    name: name,
    description: description,
    input: input,
    expected_error: expected_error,
    error_message: error_message,
    tags: tags,
  ))
}

fn test_suite_decoder() {
  use test_suite <- decode.field("test_suite", decode.string)
  use version <- decode.field("version", decode.string)
  use description <- decode.field("description", decode.optional(decode.string))
  use tests <- decode.field("tests", decode.list(test_case_decoder()))
  use error_tests <- decode.field(
    "error_tests",
    decode.optional(decode.list(error_test_case_decoder())),
  )

  decode.success(TestSuite(
    test_suite: test_suite,
    version: version,
    description: description,
    tests: tests,
    error_tests: error_tests,
  ))
}

// Load test suite from JSON file
pub fn load_test_suite() -> Result(TestSuite, String) {
  use json_string <- result.try(
    simplifile.read("ccl-test-suite/ccl-test-suite.json")
    |> result.map_error(fn(_) { "Failed to read ccl-test-suite.json" }),
  )

  json.parse(json_string, test_suite_decoder())
  |> result.map_error(fn(_) { "Failed to parse JSON test suite" })
}

pub fn get_test_cases() -> List(TestCase) {
  case load_test_suite() {
    Ok(suite) -> suite.tests
    Error(_) -> []
  }
}

pub fn get_error_test_cases() -> List(ErrorTestCase) {
  case load_test_suite() {
    Ok(suite) -> option.unwrap(suite.error_tests, [])
    Error(_) -> []
  }
}
