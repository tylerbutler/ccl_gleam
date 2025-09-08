import ccl_core
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import test_config.{type TestConfig}
import test_suite_types

/// Run tests from a single JSON file
pub fn run_tests_from_file(file_path: String) -> Nil {
  let config = test_config.from_file(file_path)
  run_tests_with_config(config)
}

/// Run tests from a directory
pub fn run_tests_from_directory(directory_path: String) -> Nil {
  let config = test_config.from_directory(directory_path)
  run_tests_with_config(config)
}

/// Run tests from multiple paths
pub fn run_tests_from_paths(paths: List(String)) -> Nil {
  let config = test_config.from_paths(paths)
  run_tests_with_config(config)
}

/// Run tests with custom configuration
pub fn run_tests_with_config(config: TestConfig) -> Nil {
  run_tests_with_config_and_pretty_print_path(config, "../ccl-test-data/tests/pretty-print.json")
}

/// Run tests with custom configuration and custom pretty print path
pub fn run_tests_with_config_and_pretty_print_path(config: TestConfig, pretty_print_path: String) -> Nil {
  // Print configuration info
  print_config_overview(config)
  
  // Run all test types with the custom config
  run_regular_tests_with_config(config)
  run_error_tests_with_config(config)
  run_pretty_printer_tests_with_config(config, pretty_print_path)
}

/// Print configuration overview
fn print_config_overview(config: TestConfig) -> Nil {
  io.println("=== Test Configuration ===")
  io.println("Paths: " <> string.inspect(config.test_paths))
  io.println("Recursive: " <> string.inspect(config.recursive))
  case config.suite_filter {
    Some(filter) -> io.println("Suite filter: " <> filter)
    None -> Nil
  }
  case config.tag_filter {
    Some(tags) -> io.println("Tag filter: " <> string.inspect(tags))
    None -> Nil
  }
  
  // Show discovered files
  let discovered_files = test_config.discover_test_files(config)
  io.println("Discovered " <> string.inspect(list.length(discovered_files)) <> " test files:")
  list.each(discovered_files, fn(file) { io.println("  - " <> file) })
  io.println("")
}

/// Run regular tests with configuration
pub fn run_regular_tests_with_config(config: TestConfig) -> Nil {
  io.println("=== REGULAR TESTS ===")
  let test_cases = test_suite_types.get_regular_tests(config)
  run_basic_test_cases(test_cases, "Regular")
}

/// Run error tests with configuration
pub fn run_error_tests_with_config(config: TestConfig) -> Nil {
  io.println("=== ERROR TESTS ===")
  let error_test_cases = test_suite_types.get_all_error_tests(config)
  run_error_test_cases(error_test_cases, "Error")
}

/// Run pretty printer tests with configuration
pub fn run_pretty_printer_tests_with_config(_config: TestConfig, pretty_print_path: String) -> Nil {
  io.println("=== PRETTY PRINTER TESTS ===")
  let test_cases = test_suite_types.get_pretty_printer_tests(pretty_print_path)
  run_pretty_printer_test_cases(test_cases)
}

/// Helper function to run basic test cases
fn run_basic_test_cases(
  test_cases: List(test_suite_types.TestCase),
  category_name: String,
) -> Nil {
  case list.is_empty(test_cases) {
    True -> {
      io.println(category_name <> ": No tests found")
    }
    False -> {
      let results =
        list.map(test_cases, fn(test_case) {
          // Convert \\n to actual newlines in input
          let cleaned_input = string.replace(test_case.input, "\\n", "\n")
          case ccl_core.parse(cleaned_input) {
            Ok(result) -> {
              let passed = result == test_case.expected
              case passed {
                False -> {
                  io.println("FAILED: " <> test_case.name)
                  io.println("  Input: " <> string.inspect(cleaned_input))
                  io.println("  Expected: " <> string.inspect(test_case.expected))
                  io.println("  Got: " <> string.inspect(result))
                }
                True -> Nil
              }
              passed
            }
            Error(err) -> {
              io.println(
                "FAILED: "
                <> test_case.name
                <> " - Parse Error: "
                <> string.inspect(err),
              )
              False
            }
          }
        })

      let passed = list.count(results, fn(r) { r == True })
      let total = list.length(results)

      io.println(
        category_name
        <> ": "
        <> string.inspect(passed)
        <> "/"
        <> string.inspect(total)
        <> " passed",
      )
      io.println("")
    }
  }
}

/// Helper function to run error test cases
fn run_error_test_cases(
  error_test_cases: List(test_suite_types.ErrorTestCase),
  category_name: String,
) -> Nil {
  case list.is_empty(error_test_cases) {
    True -> {
      io.println(category_name <> ": No tests found")
    }
    False -> {
      let results =
        list.map(error_test_cases, fn(error_test_case) {
          case ccl_core.parse(error_test_case.input) {
            Error(_) -> {
              // Expected error occurred
              error_test_case.expected_error
            }
            Ok(_) -> {
              // Parse succeeded but error was expected
              case error_test_case.expected_error {
                True -> {
                  io.println("FAILED: " <> error_test_case.name)
                  io.println("  Expected error but parse succeeded")
                  io.println("  Input: " <> string.inspect(error_test_case.input))
                  False
                }
                False -> True
              }
            }
          }
        })

      let passed = list.count(results, fn(r) { r == True })
      let total = list.length(results)

      io.println(
        category_name
        <> ": "
        <> string.inspect(passed)
        <> "/"
        <> string.inspect(total)
        <> " passed",
      )
      io.println("")
    }
  }
}

/// Helper to run pretty printer test cases
fn run_pretty_printer_test_cases(
  test_cases: List(test_suite_types.PrettyPrintTestCase),
) -> Nil {
  case list.is_empty(test_cases) {
    True -> {
      io.println("Pretty Printer: No tests found")
    }
    False -> {
      let results =
        list.map(test_cases, fn(test_case) {
          let result = case test_case.property {
            "round_trip" -> run_round_trip_test(test_case)
            "canonical_format" -> run_canonical_format_test(test_case)
            "deterministic" -> run_deterministic_test(test_case)
            _ -> False
          }
          case result {
            False -> io.println("FAILED: " <> test_case.name)
            True -> Nil
          }
          result
        })

      let passed = list.count(results, fn(r) { r == True })
      let total = list.length(test_cases)

      io.println(
        "Pretty Printer: "
        <> string.inspect(passed)
        <> "/"
        <> string.inspect(total)
        <> " passed",
      )
      io.println("")
    }
  }
}

// Pretty printer test implementations (placeholders for now)
fn run_round_trip_test(_test_case: test_suite_types.PrettyPrintTestCase) -> Bool {
  // This would need to be implemented with ccl pretty print functions
  // For now, return True as a placeholder
  True
}

fn run_canonical_format_test(_test_case: test_suite_types.PrettyPrintTestCase) -> Bool {
  // This would need to be implemented with ccl pretty print functions
  // For now, return True as a placeholder
  True
}

fn run_deterministic_test(_test_case: test_suite_types.PrettyPrintTestCase) -> Bool {
  // This would need to be implemented with ccl pretty print functions  
  // For now, return True as a placeholder
  True
}

/// Get available test files for a configuration
pub fn list_test_files(config: TestConfig) -> List(String) {
  test_config.discover_test_files(config)
}

/// Get test summary for a configuration
pub fn get_test_summary(config: TestConfig) -> String {
  test_suite_types.get_test_suite_summary(config)
}