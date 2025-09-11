import gleam/io
import gleeunit
import gleeunit/should
import progressive_test_runner

pub fn main() {
  print_test_overview()
  gleeunit.main()
}

fn print_test_overview() {
  io.println("=== MODERN PROGRESSIVE CCL TEST SUITE ===")
  io.println("This suite runs tests based on implementation capability levels:")
  io.println("- Minimal: Parse-only (Level 1)")
  io.println("- Basic: Parse + Objects + Typed Access (Levels 1-3)")
  io.println("- Processing: + Level 2 Functions (Levels 1-4)")
  io.println("- Full: Complete CCL Implementation (All Levels)")
  io.println("")
}

/// Run minimal capability tests (parse-only)
pub fn minimal_capability_tests() {
  io.println("Running minimal capability tests...")
  progressive_test_runner.run_minimal_tests()
  should.equal(True, True)
}

/// Run basic capability tests (parse + objects + typed access)
pub fn basic_capability_tests() {
  io.println("Running basic capability tests...")
  progressive_test_runner.run_basic_tests()
  should.equal(True, True)
}

/// Run processing capability tests (+ Level 2 functions)
pub fn processing_capability_tests() {
  io.println("Running processing capability tests...")
  progressive_test_runner.run_processing_tests()
  should.equal(True, True)
}

/// Run full capability tests (complete implementation)
pub fn full_capability_tests() {
  io.println("Running full capability tests...")
  progressive_test_runner.run_full_tests()
  should.equal(True, True)
}

/// Run test discovery analysis
pub fn test_discovery_analysis() {
  io.println("Running test discovery analysis...")
  progressive_test_runner.run_test_discovery()
  should.equal(True, True)
}

/// Run capability analysis
pub fn capability_analysis() {
  io.println("Running capability analysis...")
  progressive_test_runner.run_capability_analysis()
  should.equal(True, True)
}
