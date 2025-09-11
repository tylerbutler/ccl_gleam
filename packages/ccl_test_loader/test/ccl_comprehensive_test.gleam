import ccl_core
import gleam/io
import gleeunit
import gleeunit/should
import progressive_test_runner
import test_config

pub fn main() {
  // Check for custom test configuration from environment
  let config = test_config.from_env()

  // Print test overview with config
  print_test_overview(config)
  gleeunit.main()
}

fn print_test_overview(_config: test_config.TestConfig) {
  io.println("=== CCL Test Suite Overview ===")
  io.println("Using modern progressive test runner")
  io.println("Run ccl_capability_analysis() for detailed capability breakdown")
  io.println("")
}

// REMOVED: Legacy test runner - all tests now in 4-level architecture

// PROGRESSIVE TEST RUNNER INTEGRATION

/// Run minimal capability tests (Level 1 only)
pub fn ccl_minimal_tests() {
  progressive_test_runner.run_minimal_tests()
}

/// Run basic capability tests (Levels 1, 3, 4)
pub fn ccl_basic_tests() {
  progressive_test_runner.run_basic_tests()
}

/// Run processing capability tests (Levels 1-4)
pub fn ccl_processing_tests() {
  progressive_test_runner.run_processing_tests()
}

/// Run full capability tests (All levels)
pub fn ccl_full_tests() {
  progressive_test_runner.run_full_tests()
}

/// Run capability analysis
pub fn ccl_capability_analysis() {
  progressive_test_runner.run_capability_analysis()
}

/// Run test discovery
pub fn ccl_test_discovery() {
  progressive_test_runner.run_test_discovery()
}

// Test for error handling - ensures ParseError type is properly used
pub fn parse_error_type_test() {
  // This test verifies error handling for invalid CCL syntax
  case ccl_core.parse("invalid\nno equals") {
    Error(_) -> should.equal(True, True)
    // Just check that it's an error
    Ok(_) -> should.fail()
  }
}
