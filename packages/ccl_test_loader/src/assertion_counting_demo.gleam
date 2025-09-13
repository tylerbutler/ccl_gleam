import gleam/io
import unified_test_runner

pub fn main() {
  io.println("=== CCL Assertion Counting Demo ===")
  io.println("")
  
  // Test with a single API file
  let api_file = "../../../ccl-test-data/tests/api-core-ccl-parsing.json"
  io.println("Testing assertion counting with: " <> api_file)
  unified_test_runner.run_and_display_test_suite_file(api_file)
  
  // Test with multiple files
  let test_files = [
    "../../../ccl-test-data/tests/api-core-ccl-parsing.json",
    "../../../ccl-test-data/tests/api-errors.json",
    "../../../ccl-test-data/tests/api-comments.json",
  ]
  
  io.println("=== Testing Multiple Files ===")
  unified_test_runner.run_and_display_multiple_test_suites(test_files)
}