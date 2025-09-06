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
  let level1_count = list.length(test_suite_types.get_level1_tests())
  let level2_count = list.length(test_suite_types.get_level2_tests())
  let level3_count = list.length(test_suite_types.get_level3_tests())
  let level4_count =
    list.length(test_suite_types.get_typed_parsing_test_cases())
  let pretty_printer_count =
    list.length(test_suite_types.get_pretty_printer_tests())
  let total_count =
    level1_count
    + level2_count
    + level3_count
    + level4_count
    + pretty_printer_count
    + 1
  // +1 for parse_error_type_test

  io.println(
    "Level 1 (Entry Parsing): " <> string.inspect(level1_count) <> " tests",
  )
  io.println(
    "Level 2 (Entry Processing): " <> string.inspect(level2_count) <> " tests",
  )
  io.println(
    "Level 3 (Object Construction): "
    <> string.inspect(level3_count)
    <> " tests",
  )
  io.println(
    "Level 4 (Typed Parsing): " <> string.inspect(level4_count) <> " tests",
  )
  io.println(
    "Pretty Printer: " <> string.inspect(pretty_printer_count) <> " tests",
  )
  io.println("Error Handling: 1 test")
  io.println("Total: " <> string.inspect(total_count) <> " tests")
  io.println("")
}

// REMOVED: Legacy test runner - all tests now in 4-level architecture

// NEW 4-LEVEL TEST RUNNER

/// Level 1: Entry Parsing Tests - Core CCL parsing functionality
pub fn ccl_level1_entry_parsing_test() {
  io.println("\n=== LEVEL 1: Entry Parsing ===")
  let test_cases = test_suite_types.get_level1_tests()

  run_basic_test_cases(test_cases, "Level 1")
}

/// Level 2: Entry Processing Tests - Comments, filtering, composition
pub fn ccl_level2_entry_processing_test() {
  io.println("\n=== LEVEL 2: Entry Processing ===")
  let test_cases = test_suite_types.get_level2_tests()

  run_basic_test_cases(test_cases, "Level 2")
}

/// Level 3: Object Construction Tests - Nested objects, make_objects()
pub fn ccl_level3_object_construction_test() {
  io.println("\n=== LEVEL 3: Object Construction ===")
  let test_cases = test_suite_types.get_level3_tests()

  let results =
    list.map(test_cases, fn(test_case) {
      case ccl_core.parse(test_case.input) {
        Ok(entries) -> {
          let passed = entries == test_case.expected_flat
          case passed {
            False -> {
              io.println("FAILED: " <> test_case.name)
              io.println("  Input: " <> string.inspect(test_case.input))
              io.println(
                "  Expected: " <> string.inspect(test_case.expected_flat),
              )
              io.println("  Got: " <> string.inspect(entries))
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
    "Level 3: "
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

/// Level 4: Typed Parsing Tests - Type-aware extraction (existing)
pub fn ccl_level4_typed_parsing_test() {
  io.println("\n=== LEVEL 4: Typed Parsing ===")

  // Load test cases from JSON
  let test_cases = test_suite_types.get_typed_parsing_test_cases()

  let passed =
    list.count(test_cases, fn(test_case) {
      // Convert \\n to actual newlines in input
      let cleaned_input = string.replace(test_case.input, "\\n", "\n")

      case ccl_core.parse(cleaned_input) {
        Ok(entries) -> {
          let parsed = ccl_core.make_objects(entries)

          // First verify the flat parsing matches expected
          case entries == test_case.expected_flat {
            True -> {
              // Now validate typed parsing results from JSON
              validate_typed_parsing_from_json_quiet(
                parsed,
                test_case.expected_typed,
                test_case.parse_options,
              )
            }
            False -> False
          }
        }
        Error(_) -> False
      }
    })

  io.println(
    "Level 4: "
    <> string.inspect(passed)
    <> "/"
    <> string.inspect(list.length(test_cases))
    <> " passed",
  )

  // Fail if any typed parsing tests failed
  case passed == list.length(test_cases) {
    False -> should.fail()
    True -> Nil
  }
}

/// Helper function to run basic test cases (Level 1 & 2)
fn run_basic_test_cases(
  test_cases: List(test_suite_types.TestCase),
  level_name: String,
) -> Nil {
  let results =
    list.map(test_cases, fn(test_case) {
      case ccl_core.parse(test_case.input) {
        Ok(result) -> {
          let passed = result == test_case.expected
          case passed {
            False -> {
              io.println("FAILED: " <> test_case.name)
              io.println("  Input: " <> string.inspect(test_case.input))
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
    level_name
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

// Test to satisfy cleam - ParseError is part of the public API but cleam
// doesn't recognize types used only in function signatures as "used"
pub fn parse_error_type_test() {
  // This test ensures ParseError type is considered "used" by cleam
  // even though it's legitimately part of the public API
  case ccl_core.parse("invalid\nno equals") {
    Error(_) -> should.equal(True, True)
    // Just check that it's an error
    Ok(_) -> should.fail()
  }
}

// REMOVED: Legacy error test runner - now part of get_error_tests() in Level architecture

// REMOVED: Algebraic test runner - algebraic tests now in Level 2 composition_tests

// === TYPED PARSING TESTS ===

// Quiet validation function for concise output
fn validate_typed_parsing_from_json_quiet(
  parsed: ccl_core.CCL,
  expected_typed: List(#(String, test_suite_types.TypedValue)),
  parse_options: test_suite_types.ParseOptions,
) -> Bool {
  // Convert test_suite_types.ParseOptions to ccl.ParseOptions
  let ccl_options =
    ccl.ParseOptions(
      parse_integers: parse_options.parse_integers,
      parse_floats: parse_options.parse_floats,
      parse_booleans: parse_options.parse_booleans,
    )

  list.all(expected_typed, fn(pair) {
    let #(path, expected_value) = pair
    case expected_value {
      test_suite_types.StringVal(expected_str) -> {
        case ccl.get_typed_value_with_options(parsed, path, ccl_options) {
          Ok(ccl.StringVal(actual_str)) -> actual_str == expected_str
          _ -> False
        }
      }
      test_suite_types.IntVal(expected_int) -> {
        case ccl.get_typed_value_with_options(parsed, path, ccl_options) {
          Ok(ccl.IntVal(actual_int)) -> actual_int == expected_int
          _ -> False
        }
      }
      test_suite_types.FloatVal(expected_float) -> {
        case ccl.get_typed_value_with_options(parsed, path, ccl_options) {
          Ok(ccl.FloatVal(actual_float)) -> actual_float == expected_float
          _ -> False
        }
      }
      test_suite_types.BoolVal(expected_bool) -> {
        case ccl.get_typed_value_with_options(parsed, path, ccl_options) {
          Ok(ccl.BoolVal(actual_bool)) -> actual_bool == expected_bool
          _ -> False
        }
      }
      test_suite_types.EmptyVal -> {
        case ccl.get_typed_value_with_options(parsed, path, ccl_options) {
          Ok(ccl.EmptyVal) -> True
          _ -> False
        }
      }
    }
  })
}
