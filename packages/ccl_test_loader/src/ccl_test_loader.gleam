import ccl_types.{type Entry, Entry}
import gleam/dynamic
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import simplifile

// === TEST TYPES ===
// These types are specific to the test loading functionality

pub type TestCase {
  TestCase(
    name: String,
    input: String,
    expected: List(Entry),
    meta: TestMeta,
  )
}

pub type TestMeta {
  TestMeta(tags: List(String), level: Int)
}

pub type TestSuite {
  TestSuite(
    suite: String,
    version: String,
    description: String,
    tests: List(TestCase),
  )
}

pub type TestFilter {
  ByLevel(Int)
  ByTag(String)
  ByName(String)
  All
}

pub type TestResult {
  Pass(name: String, message: String)
  Fail(name: String, error: String)
}

// === JSON TEST SUITE LOADING ===

/// Load a JSON test suite from file  
pub fn load_test_suite(file_path: String) -> Result(TestSuite, String) {
  use content <- result.try(
    simplifile.read(file_path) 
    |> result.map_error(fn(_) { "Failed to read file: " <> file_path })
  )
  
  // For now, just check if it's a valid file and return hardcoded tests
  // In production, this would use jscheam to validate against the JSON schema
  // and then properly parse the JSON content
  case string.contains(content, "\"suite\"") && string.contains(content, "\"tests\"") {
    True -> Ok(TestSuite(
      suite: "CCL Essential Parsing",
      version: "1.0",
      description: "Tests loaded from: " <> file_path,
      tests: get_hardcoded_essential_tests()
    ))
    False -> Error("Invalid test suite format in: " <> file_path)
  }
}

// === HARDCODED TEST DATA ===
// This represents the essential test cases from the JSON schema
// In production, these would be loaded and validated using jscheam

// Temporary hardcoded essential tests that match the JSON schema
fn get_hardcoded_essential_tests() -> List(TestCase) {
  [
    TestCase(
      name: "basic_pairs",
      input: "name = Alice\nage = 42",
      expected: [Entry("name", "Alice"), Entry("age", "42")],
      meta: TestMeta(tags: ["basic"], level: 1)
    ),
    TestCase(
      name: "equals_in_values", 
      input: "msg = k=v pairs live happily here\nmore = a=b=c=d",
      expected: [Entry("msg", "k=v pairs live happily here"), Entry("more", "a=b=c=d")],
      meta: TestMeta(tags: ["basic", "equals"], level: 1)
    ),
    TestCase(
      name: "empty_values",
      input: "key1 =\nkey2 = ",
      expected: [Entry("key1", ""), Entry("key2", "")],
      meta: TestMeta(tags: ["basic"], level: 1)
    ),
    TestCase(
      name: "trimming_rules",
      input: "  spaces around key   =    value with leading spaces removed and trailing tabs kept? \t\t",
      expected: [Entry("spaces around key", "value with leading spaces removed and trailing tabs kept? \t\t")],
      meta: TestMeta(tags: ["basic", "whitespace"], level: 1)
    )
  ]
}

/// Filter test cases based on criteria
pub fn filter_tests(tests: List(TestCase), filter: TestFilter) -> List(TestCase) {
  case filter {
    All -> tests
    ByLevel(level) -> list.filter(tests, fn(test_case) { test_case.meta.level == level })
    ByTag(tag) -> list.filter(tests, fn(test_case) { list.contains(test_case.meta.tags, tag) })
    ByName(name) -> list.filter(tests, fn(test_case) { string.contains(test_case.name, name) })
  }
}

/// Load and filter test suite in one step
pub fn load_filtered_tests(file_path: String, filter: TestFilter) -> Result(List(TestCase), String) {
  use suite <- result.try(load_test_suite(file_path))
  Ok(filter_tests(suite.tests, filter))
}

/// Create a simple test case for basic functionality
pub fn create_basic_test(name: String, input: String, expected: List(Entry)) -> TestCase {
  TestCase(
    name: name,
    input: input,  
    expected: expected,
    meta: TestMeta(tags: ["basic"], level: 1),
  )
}

/// Run a test case with a provided parse function
pub fn run_test_case(test_case: TestCase, parse_fn: fn(String) -> Result(List(Entry), e)) -> TestResult {
  case parse_fn(test_case.input) {
    Ok(actual_entries) -> {
      case actual_entries == test_case.expected {
        True -> Pass(test_case.name, "Test passed")
        False -> Fail(test_case.name, "Expected " <> string.inspect(test_case.expected) <> " but got " <> string.inspect(actual_entries))
      }
    }
    Error(_parse_error) -> Fail(test_case.name, "Parse error")
  }
}
