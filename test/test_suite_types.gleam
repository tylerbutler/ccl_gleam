// Placeholder for test suite types - will be implemented later
import ccl_core

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

// Return empty lists for now - JSON parsing to be implemented later
pub fn get_test_cases() -> List(TestCase) {
  []
}

pub fn get_error_test_cases() -> List(ErrorTestCase) {
  []
}