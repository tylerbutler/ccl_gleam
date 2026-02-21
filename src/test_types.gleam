/// Types for the CCL test suite, matching the generated test format from ccl-test-data.
import gleam/dict.{type Dict}
import gleam/option.{type Option}

/// A single test entry with key-value pair
pub type TestEntry {
  TestEntry(key: String, value: String)
}

/// Expected result format with count field for assertion verification
pub type Expected {
  ExpectedEntries(count: Int, entries: List(TestEntry))
  ExpectedValue(count: Int, value: String)
  ExpectedObject(count: Int, object: Dict(String, ExpectedNode))
  ExpectedList(count: Int, list: List(String))
  ExpectedInt(count: Int, value: Int)
  ExpectedFloat(count: Int, value: Float)
  ExpectedBool(count: Int, value: Bool)
  ExpectedError(count: Int, error: Bool)
  ExpectedBoolean(count: Int, boolean: Bool)
  ExpectedCountOnly(count: Int)
}

/// Recursive type for nested objects in expected results
pub type ExpectedNode {
  NodeString(String)
  NodeList(List(String))
  NodeObject(Dict(String, ExpectedNode))
}

/// Behavior conflicts - behaviors that would cause this test to fail
pub type Conflicts {
  Conflicts(behaviors: List(String))
  NoConflicts
}

/// A single test case from the JSON test suite
pub type TestCase {
  TestCase(
    name: String,
    source_test: String,
    validation: String,
    functions: List(String),
    inputs: List(String),
    behaviors: List(String),
    variants: List(String),
    features: List(String),
    expected: Expected,
    path: Option(List(String)),
    conflicts: Conflicts,
  )
}

/// A complete test suite loaded from a JSON file
pub type TestSuite {
  TestSuite(tests: List(TestCase))
}

/// Result of running a single test
pub type TestResult {
  TestPassed(name: String, assertions: Int)
  TestFailed(name: String, reason: String, assertions: Int)
  TestSkipped(name: String, reason: String)
}

/// How to group failures in the report.
pub type FailureGrouping {
  /// Group failures by source file (default)
  GroupByFile
  /// Group failures by validation kind (parse, print, build_hierarchy, etc.)
  GroupByValidation
}

/// A test case paired with its execution result
pub type TestCaseResult {
  TestCaseResult(test_case: TestCase, result: TestResult)
}

/// Summary of running a test suite
pub type TestSuiteResult {
  TestSuiteResult(
    file: String,
    total: Int,
    passed: Int,
    failed: Int,
    skipped: Int,
    results: List(TestCaseResult),
  )
}

/// Configuration for what functions/behaviors the implementation supports.
/// Functions, behaviors, and variants are used for test filtering.
/// Features are NOT used for filtering — they are metadata for reporting only.
pub type ImplementationConfig {
  ImplementationConfig(
    functions: List(String),
    behaviors: List(String),
    variants: List(String),
    features: List(String),
  )
}
