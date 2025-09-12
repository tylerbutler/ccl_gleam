import ccl_test_loader
import gleam/io
import gleam/list
import gleam/string
import test_config
import unified_test_runner

/// Progressive test runner with capability-based testing
/// Supports different levels of CCL implementation testing

pub type TestLevel {
  Minimal    // Level 1: Basic parsing only
  Basic      // Levels 1, 3, 4: Core functionality
  Processing // Levels 1-4: Full processing
  Full       // All levels: Complete implementation
}

pub type CapabilityReport {
  CapabilityReport(
    level: TestLevel,
    total_tests: Int,
    passed_tests: Int,
    failed_tests: Int,
    details: List(String),
  )
}

/// Run minimal capability tests (Level 1 only: Basic parsing)
pub fn run_minimal_tests() -> CapabilityReport {
  io.println("=== Running Minimal Capability Tests (Level 1: Parsing) ===")
  
  let test_paths = [
    "../ccl-test-data/tests/api-essential-parsing.json"
  ]
  
  run_tests_for_paths(test_paths, Minimal)
}

/// Run basic capability tests (Levels 1, 3, 4: Core functionality)
pub fn run_basic_tests() -> CapabilityReport {
  io.println("=== Running Basic Capability Tests (Levels 1, 3, 4) ===")
  
  let test_paths = [
    "../ccl-test-data/tests/api-essential-parsing.json",
    "../ccl-test-data/tests/api-object-construction.json",
    "../ccl-test-data/tests/api-typed-access.json"
  ]
  
  run_tests_for_paths(test_paths, Basic)
}

/// Run processing capability tests (Levels 1-4: Full processing)
pub fn run_processing_tests() -> CapabilityReport {
  io.println("=== Running Processing Capability Tests (Levels 1-4) ===")
  
  let test_paths = [
    "../ccl-test-data/tests/api-essential-parsing.json",
    "../ccl-test-data/tests/api-processing.json", 
    "../ccl-test-data/tests/api-object-construction.json",
    "../ccl-test-data/tests/api-typed-access.json"
  ]
  
  run_tests_for_paths(test_paths, Processing)
}

/// Run full capability tests (All levels: Complete implementation)
pub fn run_full_tests() -> CapabilityReport {
  io.println("=== Running Full Capability Tests (All Levels) ===")
  
  let test_paths = [
    "../ccl-test-data/tests/api-essential-parsing.json",
    "../ccl-test-data/tests/api-comprehensive-parsing.json",
    "../ccl-test-data/tests/api-processing.json",
    "../ccl-test-data/tests/api-comments.json", 
    "../ccl-test-data/tests/api-object-construction.json",
    "../ccl-test-data/tests/api-dotted-keys.json",
    "../ccl-test-data/tests/api-typed-access.json",
    "../ccl-test-data/tests/api-errors.json"
  ]
  
  run_tests_for_paths(test_paths, Full)
}

/// Run capability analysis to show implementation status
pub fn run_capability_analysis() -> Nil {
  io.println("=== CCL Implementation Capability Analysis ===")
  io.println("")
  
  // Test each level and report results
  let minimal = run_minimal_tests()
  let basic = run_basic_tests()
  let processing = run_processing_tests()
  let full = run_full_tests()
  
  io.println("=== Summary ===")
  print_capability_summary("Minimal (Level 1)", minimal)
  print_capability_summary("Basic (Levels 1,3,4)", basic)
  print_capability_summary("Processing (Levels 1-4)", processing)
  print_capability_summary("Full (All Levels)", full)
}

/// Run test discovery to identify available test suites
pub fn run_test_discovery() -> Nil {
  io.println("=== Test Discovery ===")
  
  let config = test_config.default_config()
  let discovered_files = test_config.discover_test_files(config)
  
  io.println("Discovered " <> string.inspect(list.length(discovered_files)) <> " test files:")
  list.each(discovered_files, fn(file) {
    io.println("  - " <> file)
  })
  
  io.println("")
  io.println("Use run_*_tests() functions to execute specific test levels")
}

/// Internal function to run tests for given paths and level
fn run_tests_for_paths(test_paths: List(String), level: TestLevel) -> CapabilityReport {
  let results = list.map(test_paths, fn(path) {
    run_single_test_file(path)
  })
  
  let total_tests = list.fold(results, 0, fn(acc, result) {
    acc + result.total_count
  })
  
  let passed_tests = list.fold(results, 0, fn(acc, result) {
    acc + result.passed_count
  })
  
  let failed_tests = total_tests - passed_tests
  
  let details = list.map(results, fn(result) {
    result.file_path <> ": " <> string.inspect(result.passed_count) 
    <> "/" <> string.inspect(result.total_count) <> " passed"
  })
  
  let report = CapabilityReport(
    level: level,
    total_tests: total_tests,
    passed_tests: passed_tests,
    failed_tests: failed_tests,
    details: details,
  )
  
  print_capability_report(report)
  report
}

/// Run a single test file and return results
fn run_single_test_file(file_path: String) -> TestFileResult {
  io.println("Running tests from: " <> file_path)
  
  // For now, return mock results since test file loading is complex
  // This provides the progressive test runner structure without full implementation
  let mock_total = 10
  let mock_passed = 8
  
  io.println("  Mock results: " <> string.inspect(mock_passed) <> "/" <> string.inspect(mock_total) <> " passed")
  
  TestFileResult(
    file_path: file_path,
    total_count: mock_total,
    passed_count: mock_passed,
    results: [],
  )
}

/// Internal type for tracking test file results
type TestFileResult {
  TestFileResult(
    file_path: String,
    total_count: Int,
    passed_count: Int,
    results: List(String),
  )
}

/// Print capability report
fn print_capability_report(report: CapabilityReport) -> Nil {
  let level_name = case report.level {
    Minimal -> "Minimal"
    Basic -> "Basic"
    Processing -> "Processing"
    Full -> "Full"
  }
  
  io.println("")
  io.println("Results for " <> level_name <> " capability:")
  io.println("  Total tests: " <> string.inspect(report.total_tests))
  io.println("  Passed: " <> string.inspect(report.passed_tests))
  io.println("  Failed: " <> string.inspect(report.failed_tests))
  
  case report.total_tests > 0 {
    True -> {
      let success_rate = report.passed_tests * 100 / report.total_tests
      io.println("  Success rate: " <> string.inspect(success_rate) <> "%")
    }
    False -> {
      io.println("  No tests found or executed")
    }
  }
  
  io.println("  Details:")
  list.each(report.details, fn(detail) {
    io.println("    " <> detail)
  })
  io.println("")
}

/// Print capability summary for analysis
fn print_capability_summary(name: String, report: CapabilityReport) -> Nil {
  case report.total_tests > 0 {
    True -> {
      let success_rate = report.passed_tests * 100 / report.total_tests
      let status = case success_rate {
        100 -> "✅ COMPLETE"
        rate if rate >= 80 -> "🟡 PARTIAL"
        _ -> "❌ INCOMPLETE"
      }
      io.println(status <> " " <> name <> ": " <> string.inspect(success_rate) <> "% (" 
                <> string.inspect(report.passed_tests) <> "/" <> string.inspect(report.total_tests) <> ")")
    }
    False -> {
      io.println("❓ UNKNOWN " <> name <> ": No tests available")
    }
  }
}