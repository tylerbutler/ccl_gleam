import ccl_core
import ccl_types.{type Entry, Entry, type CCL}
import gleam/dynamic/decode
import gleam/io
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
  
  use test_suite <- result.try(
    json.parse(content, test_suite_decoder())
    |> result.map_error(fn(_) { "Failed to parse JSON in file: " <> file_path })
  )
  
  Ok(test_suite)
}

// JSON Decoders
fn test_suite_decoder() -> decode.Decoder(TestSuite) {
  use suite <- decode.field("suite", decode.string)
  use version <- decode.field("version", decode.string)
  use description <- decode.field("description", decode.string)
  use tests <- decode.field("tests", decode.list(test_case_decoder()))
  decode.success(TestSuite(suite, version, description, tests))
}

fn test_case_decoder() -> decode.Decoder(TestCase) {
  // Try the standard format first, then the object-construction format
  decode.one_of(
    standard_test_case_decoder(),
    or: [object_construction_test_case_decoder()]
  )
}

fn standard_test_case_decoder() -> decode.Decoder(TestCase) {
  use name <- decode.field("name", decode.string)
  use input <- decode.field("input", decode.string)
  use expected <- decode.field("expected", decode.list(entry_decoder()))
  use meta <- decode.field("meta", test_meta_decoder())
  decode.success(TestCase(name, input, expected, meta))
}

fn object_construction_test_case_decoder() -> decode.Decoder(TestCase) {
  use name <- decode.field("name", decode.string)
  use input <- decode.field("input", decode.string)
  use expected <- decode.field("expected_flat", decode.list(entry_decoder()))
  use meta <- decode.field("meta", test_meta_decoder())
  decode.success(TestCase(name, input, expected, meta))
}

fn entry_decoder() -> decode.Decoder(Entry) {
  use key <- decode.field("key", decode.string)
  use value <- decode.field("value", decode.string)
  decode.success(Entry(key, value))
}

fn test_meta_decoder() -> decode.Decoder(TestMeta) {
  use tags <- decode.field("tags", decode.list(decode.string))
  use level <- decode.field("level", decode.int)
  decode.success(TestMeta(tags, level))
}

// === ARCHITECTURE SUMMARY ===
// The comprehensive test runner infrastructure is complete:
// - All JSON test suite paths are defined (ccl_core_test_paths, ccl_package_test_paths) 
// - Generic test execution (run_test_suite_with_parser, run_ccl_core_comprehensive_tests)
// - Package-specific separation (ccl_core vs ccl package tests)
// - No hardcoded test data in any package
// - Single source of truth for all CCL testing
//
// JSON parsing implementation can be completed later using proper decode API

// === TEST DATA NOW LOADED FROM JSON ===
// All test cases are loaded directly from the JSON files in ccl-test-data/tests/
// No hardcoded test data remains in this codebase.

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

/// Run a test case with smart multi-level testing
pub fn run_test_case(test_case: TestCase, parse_fn: fn(String) -> Result(List(Entry), e)) -> TestResult {
  // Always test Level 1 (entry parsing) first
  case parse_fn(test_case.input) {
    Ok(actual_entries) -> {
      // Test Level 1: Entry parsing
      case actual_entries == test_case.expected {
        True -> {
          // Level 1 passed - check if we should test Level 3 (object construction)
          case should_test_object_construction(test_case) {
            True -> test_object_construction(test_case, actual_entries)
            False -> Pass(test_case.name, "Level 1 parsing passed")
          }
        }
        False -> Fail(test_case.name, "Level 1 parsing failed: Expected " <> string.inspect(test_case.expected) <> " but got " <> string.inspect(actual_entries))
      }
    }
    Error(_parse_error) -> Fail(test_case.name, "Parse error")
  }
}

/// Determine if test case should include object construction testing
fn should_test_object_construction(test_case: TestCase) -> Bool {
  // Test object construction if:
  // 1. Test has dotted keys (indicates nested structure)
  // 2. Test is tagged as object construction or level 3
  // 3. Test name suggests nesting
  let has_dotted_keys = list.any(test_case.expected, fn(entry) {
    string.contains(entry.key, ".")
  })
  
  let is_object_construction_test = list.contains(test_case.meta.tags, "nested") || 
                                   list.contains(test_case.meta.tags, "object-construction") ||
                                   test_case.meta.level >= 3
  
  let suggests_nesting = string.contains(test_case.name, "nested") ||
                        string.contains(test_case.name, "dotted") ||
                        string.contains(test_case.name, "construction")
  
  has_dotted_keys || is_object_construction_test || suggests_nesting
}

/// Test Level 3 object construction and nested access
fn test_object_construction(test_case: TestCase, entries: List(Entry)) -> TestResult {
  // Import ccl_core functions for object construction
  let ccl = ccl_core.make_objects(entries)
  
  // Test that we can access dotted keys as nested structures
  let dotted_keys = list.filter(entries, fn(entry) { 
    string.contains(entry.key, ".") 
  })
  
  case test_dotted_key_access(ccl, dotted_keys) {
    Ok(_) -> Pass(test_case.name, "Level 1 parsing + Level 3 object construction passed")
    Error(error) -> Fail(test_case.name, "Level 3 object construction failed: " <> error)
  }
}

/// Test that dotted keys can be accessed as nested structures  
fn test_dotted_key_access(ccl: CCL, dotted_entries: List(Entry)) -> Result(Nil, String) {
  case dotted_entries {
    [] -> Ok(Nil) // No dotted keys to test
    [first_entry, ..rest] -> {
      // Test that we can access the value through the dotted path
      case ccl_core.get_value(ccl, first_entry.key) {
        Ok(value) -> {
          case value == first_entry.value {
            True -> test_dotted_key_access(ccl, rest) // Test remaining entries
            False -> Error("Dotted key access mismatch for " <> first_entry.key)
          }
        }
        Error(_) -> Error("Could not access dotted key: " <> first_entry.key)
      }
    }
  }
}

// === COMPREHENSIVE TEST EXECUTION ===
// This section provides complete CCL test suite execution

pub type TestSuiteResult {
  TestSuiteResult(
    suite_name: String,
    total: Int,
    passed: Int,
    failed: Int,
    results: List(TestResult)
  )
}

pub type ComprehensiveTestResults {
  ComprehensiveTestResults(
    level_1: List(TestSuiteResult),
    level_2: List(TestSuiteResult), 
    level_3: List(TestSuiteResult),
    level_4: List(TestSuiteResult),
    total_passed: Int,
    total_failed: Int
  )
}

/// Run a complete test suite from a JSON file with a provided parse function
pub fn run_test_suite_with_parser(file_path: String, parse_fn: fn(String) -> Result(List(Entry), e)) -> TestSuiteResult {
  case load_test_suite(file_path) {
    Ok(suite) -> {
      let results = list.map(suite.tests, fn(test_case) {
        run_test_case(test_case, parse_fn)
      })
      let passed = list.count(results, fn(result) { 
        case result { Pass(_, _) -> True Fail(_, _) -> False }
      })
      let failed = list.length(results) - passed
      
      TestSuiteResult(
        suite_name: suite.suite,
        total: list.length(results),
        passed: passed,
        failed: failed,
        results: results
      )
    }
    Error(_) -> TestSuiteResult(
      suite_name: "Failed to load: " <> file_path,
      total: 0,
      passed: 0, 
      failed: 1,
      results: [Fail("load_error", "Could not load test suite")]
    )
  }
}

/// Print test suite results
pub fn print_test_suite_result(result: TestSuiteResult) -> Nil {
  io.println("=== " <> result.suite_name <> " ===")
  io.println("Total: " <> string.inspect(result.total) <> ", Passed: " <> string.inspect(result.passed) <> ", Failed: " <> string.inspect(result.failed))
  
  // Print failed tests
  list.each(result.results, fn(test_result) {
    case test_result {
      Fail(name, error) -> io.println("  FAIL: " <> name <> " - " <> error)
      Pass(_, _) -> Nil
    }
  })
  io.println("")
}

/// List of all JSON test suite paths for CCL Core (Levels 1-3)
pub fn ccl_core_test_paths() -> List(String) {
  [
    "/home/tylerbu/code/claude-workspace/ccl-test-data/tests/essential-parsing.json",      // Level 1
    "/home/tylerbu/code/claude-workspace/ccl-test-data/tests/comprehensive-parsing.json", // Level 1 
    "/home/tylerbu/code/claude-workspace/ccl-test-data/tests/comments.json",              // Level 2
    "/home/tylerbu/code/claude-workspace/ccl-test-data/tests/processing.json",            // Level 2
    "/home/tylerbu/code/claude-workspace/ccl-test-data/tests/object-construction.json",   // Level 3
    "/home/tylerbu/code/claude-workspace/ccl-test-data/tests/dotted-keys.json",          // Level 3
    "/home/tylerbu/code/claude-workspace/ccl-test-data/tests/errors.json"                // All levels
  ]
}

/// List of all JSON test suite paths for CCL Package (Level 4+)
pub fn ccl_package_test_paths() -> List(String) {
  [
    "/home/tylerbu/code/claude-workspace/ccl-test-data/tests/typed-access.json",     // Level 4
    "/home/tylerbu/code/claude-workspace/ccl-test-data/tests/pretty-print.json"     // Integration
  ]
}

/// Run all test suites for CCL Core with a provided parser
pub fn run_ccl_core_comprehensive_tests(parse_fn: fn(String) -> Result(List(Entry), e)) -> List(TestSuiteResult) {
  io.println("🧪 Running CCL Core Comprehensive Tests")
  io.println("========================================")
  
  let results = list.map(ccl_core_test_paths(), fn(path) {
    run_test_suite_with_parser(path, parse_fn)
  })
  
  list.each(results, print_test_suite_result)
  
  let total_passed = list.fold(results, 0, fn(acc, result) { acc + result.passed })
  let total_failed = list.fold(results, 0, fn(acc, result) { acc + result.failed })
  
  io.println("🏁 CCL CORE COMPREHENSIVE RESULTS")
  io.println("==================================")
  io.println("Total Passed: " <> string.inspect(total_passed))
  io.println("Total Failed: " <> string.inspect(total_failed))
  
  results
}
