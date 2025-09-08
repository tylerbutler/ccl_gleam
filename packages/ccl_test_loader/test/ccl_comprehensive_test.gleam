import ccl
import ccl_core
import gleam/io
import gleam/list
import gleam/string
import gleeunit
import gleeunit/should
import test_suite_types

pub fn main() {
  // Print test overview first
  print_test_overview()
  gleeunit.main()
}

fn print_test_overview() {
  io.println("=== CCL Test Suite Overview ===")
  io.println(test_suite_types.get_test_suite_summary())

  let regular_tests_count = list.length(test_suite_types.get_regular_tests())
  let error_tests_count = list.length(test_suite_types.get_all_error_tests())
  let pretty_printer_count =
    list.length(test_suite_types.get_pretty_printer_tests())
  let total_count =
    regular_tests_count + error_tests_count + pretty_printer_count + 1
  // +1 for parse_error_type_test

  io.println(
    "Regular Tests: " <> string.inspect(regular_tests_count) <> " tests",
  )
  io.println("Error Tests: " <> string.inspect(error_tests_count) <> " tests")
  io.println(
    "Pretty Printer: " <> string.inspect(pretty_printer_count) <> " tests",
  )
  io.println("Total: " <> string.inspect(total_count) <> " tests")
  io.println("")
}

// REMOVED: Legacy test runner - all tests now in 4-level architecture

// SIMPLIFIED TEST RUNNER

/// Run all regular tests
pub fn ccl_regular_tests() {
  io.println("\n=== REGULAR TESTS ===")
  let test_cases = test_suite_types.get_regular_tests()
  run_basic_test_cases(test_cases, "Regular")
}

/// Run all error tests
pub fn ccl_error_tests() {
  io.println("\n=== ERROR TESTS ===")
  let error_test_cases = test_suite_types.get_all_error_tests()
  run_error_test_cases(error_test_cases, "Error")
}

/// Helper function to run basic test cases for any category
fn run_basic_test_cases(
  test_cases: List(test_suite_types.TestCase),
  category_name: String,
) -> Nil {
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

  case passed != total {
    True -> should.fail()
    False -> Nil
  }
}

/// Pretty Printer Tests - Round-trip and canonical formatting
pub fn ccl_pretty_printer_test() {
  io.println("\n=== PRETTY PRINTER ===")
  let test_cases = test_suite_types.get_pretty_printer_tests()

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

  case passed != total {
    True -> should.fail()
    False -> Nil
  }
}

fn run_round_trip_test(test_case: test_suite_types.PrettyPrintTestCase) -> Bool {
  case ccl_core.parse(test_case.input) {
    Ok(entries) -> {
      let pretty_printed = ccl.pretty_print_entries(entries)
      case ccl_core.parse(pretty_printed) {
        Ok(reparsed_entries) -> {
          let round_trip_ok = entries == reparsed_entries
          let canonical_ok = pretty_printed == test_case.expected_canonical
          let passed = round_trip_ok && canonical_ok
          case passed {
            False -> {
              io.println("  Round-trip OK: " <> string.inspect(round_trip_ok))
              io.println("  Canonical OK: " <> string.inspect(canonical_ok))
              io.println("  Input: " <> string.inspect(test_case.input))
              io.println(
                "  Expected: " <> string.inspect(test_case.expected_canonical),
              )
              io.println("  Got: " <> string.inspect(pretty_printed))
            }
            True -> Nil
          }
          passed
        }
        Error(err) -> {
          io.println("  Reparse error: " <> string.inspect(err))
          False
        }
      }
    }
    Error(err) -> {
      io.println("  Parse error: " <> string.inspect(err))
      False
    }
  }
}

fn run_canonical_format_test(
  test_case: test_suite_types.PrettyPrintTestCase,
) -> Bool {
  case ccl_core.parse(test_case.input) {
    Ok(entries) -> {
      let pretty_printed = ccl.pretty_print_entries(entries)
      let passed = pretty_printed == test_case.expected_canonical
      case passed {
        False -> {
          io.println("  Input: " <> string.inspect(test_case.input))
          io.println(
            "  Expected: " <> string.inspect(test_case.expected_canonical),
          )
          io.println("  Got: " <> string.inspect(pretty_printed))
        }
        True -> Nil
      }
      passed
    }
    Error(err) -> {
      io.println("  Parse error: " <> string.inspect(err))
      False
    }
  }
}

fn run_deterministic_test(
  test_case: test_suite_types.PrettyPrintTestCase,
) -> Bool {
  case ccl_core.parse(test_case.input) {
    Ok(entries) -> {
      let output1 = ccl.pretty_print_entries(entries)
      let output2 = ccl.pretty_print_entries(entries)
      // Same input should always produce same output
      output1 == output2 && output1 == test_case.expected_canonical
    }
    Error(_) -> False
  }
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

/// Helper function to run error test cases
fn run_error_test_cases(
  error_test_cases: List(test_suite_types.ErrorTestCase),
  category_name: String,
) -> Nil {
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

  case passed != total {
    True -> should.fail()
    False -> Nil
  }
}
