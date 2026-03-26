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

/// Conflicts that make a test incompatible with certain implementations
pub type Conflicts {
  Conflicts(behaviours: List(String))
}

/// A single test case from the JSON test suite
pub type TestCase {
  TestCase(
    name: String,
    source_test: String,
    validation: String,
    functions: List(String),
    inputs: List(String),
    behaviours: List(String),
    variants: List(String),
    features: List(String),
    expected: Expected,
    path: Option(List(String)),
    args: Option(List(String)),
    conflicts: Conflicts,
  )
}

/// A complete test suite loaded from a JSON file
pub type TestSuite {
  TestSuite(tests: List(TestCase))
}

/// Details about a test failure, kept as a record so new fields
/// (e.g. context, input) can be added without touching every call site.
pub type FailureDetail {
  FailureDetail(
    reason: String,
    actual: String,
    expected: String,
    assertions: Int,
  )
}

/// Result of running a single test
pub type TestResult {
  TestPassed(name: String, assertions: Int)
  TestFailed(name: String, detail: FailureDetail)
  TestSkipped(name: String, reason: String)
}

/// Summary of running a test suite
pub type TestSuiteResult {
  TestSuiteResult(
    file: String,
    total: Int,
    passed: Int,
    failed: Int,
    skipped: Int,
    results: List(TestResult),
  )
}

/// Configuration for what functions/behaviours the implementation supports
pub type ImplementationConfig {
  ImplementationConfig(
    functions: List(String),
    behaviours: List(String),
    variants: List(String),
    features: List(String),
  )
}
