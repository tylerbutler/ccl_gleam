import ccl
import ccl_core
import gleam/io
import gleam/list
import gleam/string
import gleeunit
import gleeunit/should
import test_suite_types

pub fn main() {
  gleeunit.main()
}

// Dynamic test suite execution
pub fn ccl_test_suite_test() {
  let test_cases = test_suite_types.get_test_cases()

  io.println(
    "Loaded " <> string.inspect(list.length(test_cases)) <> " test cases",
  )

  let results =
    list.map(test_cases, fn(test_case) {
      io.println(
        "Running test: " <> test_case.name <> " - " <> test_case.description,
      )

      case ccl_core.parse(test_case.input) {
        Ok(result) -> {
          case result == test_case.expected {
            True -> {
              io.println("  ✓ PASS")
              True
            }
            False -> {
              io.println("  ✗ FAIL")
              io.println("    Expected: " <> string.inspect(test_case.expected))
              io.println("    Got:      " <> string.inspect(result))
              False
            }
          }
        }
        Error(err) -> {
          io.println("  ✗ PARSE ERROR: " <> string.inspect(err))
          False
        }
      }
    })

  let passed = list.count(results, fn(r) { r == True })
  let failed = list.count(results, fn(r) { r == False })
  let total = list.length(results)

  io.println("\n=== Test Summary ===")
  io.println("Total tests: " <> string.inspect(total))
  io.println("Passed: " <> string.inspect(passed))
  io.println("Failed: " <> string.inspect(failed))

  // Only fail at the end if there were failures
  case failed > 0 {
    True -> should.fail()
    False -> Nil
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

// Error test cases
pub fn ccl_error_test_suite_test() {
  let error_test_cases = test_suite_types.get_error_test_cases()

  list.each(error_test_cases, fn(error_test_case) {
    io.println(
      "Running error test: "
      <> error_test_case.name
      <> " - "
      <> error_test_case.description,
    )

    case ccl_core.parse(error_test_case.input) {
      Ok(_result) -> {
        io.println("  ✗ FAIL - Expected error but got success")
        should.fail()
      }
      Error(_err) -> {
        io.println("  ✓ PASS - Got expected error")
      }
    }
  })
}

// === TYPED PARSING TESTS ===

/// Test typed parsing functionality using JSON test cases - fully JSON-driven
pub fn ccl_typed_parsing_test() {
  io.println("\n=== CCL Typed Parsing Tests ===")
  
  // Load test cases from JSON
  let test_cases = test_suite_types.get_typed_parsing_test_cases()
  
  io.println("Loaded " <> string.inspect(list.length(test_cases)) <> " typed parsing test cases")
  
  let passed = list.count(test_cases, fn(test_case) {
    io.println("Running typed test: " <> test_case.name <> " - " <> test_case.description)
    
    // Convert \\n to actual newlines in input
    let cleaned_input = string.replace(test_case.input, "\\n", "\n")
    
    case ccl_core.parse(cleaned_input) {
      Ok(entries) -> {
        let parsed = ccl_core.make_objects(entries)
        
        // First verify the flat parsing matches expected
        case verify_flat_parsing(entries, test_case.expected_flat) {
          True -> {
            io.println("  ✓ Flat parsing matches expected")
            // Now validate typed parsing results from JSON
            case validate_typed_parsing_from_json(parsed, test_case.expected_typed, test_case.parse_options) {
              True -> {
                io.println("  ✓ Typed parsing validation passed")
                True
              }
              False -> {
                io.println("  ✗ Typed parsing validation failed")
                False
              }
            }
          }
          False -> {
            io.println("  ✗ Flat parsing doesn't match expected")
            False
          }
        }
      }
      Error(err) -> {
        io.println("  ✗ PARSE ERROR: " <> string.inspect(err))
        False
      }
    }
  })
  
  io.println("\nTyped parsing tests: " <> string.inspect(passed) <> "/" <> string.inspect(list.length(test_cases)) <> " passed")
  
  // Fail if any typed parsing tests failed
  case passed == list.length(test_cases) {
    False -> should.fail()
    True -> Nil
  }
}

// Verify flat parsing results match expected from JSON
fn verify_flat_parsing(actual: List(ccl_core.Entry), expected: List(ccl_core.Entry)) -> Bool {
  case actual == expected {
    True -> True
    False -> {
      io.println("    FLAT PARSING MISMATCH:")
      io.println("    Expected: " <> string.inspect(expected))
      io.println("    Actual:   " <> string.inspect(actual))
      False
    }
  }
}

// JSON-driven validation function that uses the expected_typed data
fn validate_typed_parsing_from_json(parsed: ccl_core.CCL, expected_typed: List(#(String, test_suite_types.TypedValue)), parse_options: test_suite_types.ParseOptions) -> Bool {
  // Convert test_suite_types.ParseOptions to ccl.ParseOptions
  let ccl_options = ccl.ParseOptions(
    parse_integers: parse_options.parse_integers,
    parse_floats: parse_options.parse_floats, 
    parse_booleans: parse_options.parse_booleans,
  )
  
  
  list.all(expected_typed, fn(pair) {
    let #(path, expected_value) = pair
    case expected_value {
      test_suite_types.StringVal(expected_str) -> {
        case ccl.get_typed_value_with_options(parsed, path, ccl_options) {
          Ok(ccl.StringVal(actual_str)) -> {
            case actual_str == expected_str {
              True -> {
                io.println("  ✓ get_typed_value(" <> path <> ") = StringVal(" <> actual_str <> ")")
                True
              }
              False -> {
                io.println("  ✗ get_typed_value(" <> path <> ") = StringVal(" <> actual_str <> "), expected StringVal(" <> expected_str <> ")")
                False
              }
            }
          }
          Ok(other) -> {
            io.println("  ✗ get_typed_value(" <> path <> ") = " <> string.inspect(other) <> ", expected StringVal(" <> expected_str <> ")")
            False
          }
          Error(err) -> {
            io.println("  ✗ get_typed_value(" <> path <> ") error: " <> err)
            False
          }
        }
      }
      test_suite_types.IntVal(expected_int) -> {
        case ccl.get_typed_value_with_options(parsed, path, ccl_options) {
          Ok(ccl.IntVal(actual_int)) -> {
            case actual_int == expected_int {
              True -> {
                io.println("  ✓ get_typed_value(" <> path <> ") = IntVal(" <> string.inspect(actual_int) <> ")")
                True
              }
              False -> {
                io.println("  ✗ get_typed_value(" <> path <> ") = IntVal(" <> string.inspect(actual_int) <> "), expected IntVal(" <> string.inspect(expected_int) <> ")")
                False
              }
            }
          }
          Ok(other) -> {
            io.println("  ✗ get_typed_value(" <> path <> ") = " <> string.inspect(other) <> ", expected IntVal(" <> string.inspect(expected_int) <> ")")
            False
          }
          Error(err) -> {
            io.println("  ✗ get_typed_value(" <> path <> ") error: " <> err)
            False
          }
        }
      }
      test_suite_types.FloatVal(expected_float) -> {
        case ccl.get_typed_value_with_options(parsed, path, ccl_options) {
          Ok(ccl.FloatVal(actual_float)) -> {
            case actual_float == expected_float {
              True -> {
                io.println("  ✓ get_typed_value(" <> path <> ") = FloatVal(" <> string.inspect(actual_float) <> ")")
                True
              }
              False -> {
                io.println("  ✗ get_typed_value(" <> path <> ") = FloatVal(" <> string.inspect(actual_float) <> "), expected FloatVal(" <> string.inspect(expected_float) <> ")")
                False
              }
            }
          }
          Ok(other) -> {
            io.println("  ✗ get_typed_value(" <> path <> ") = " <> string.inspect(other) <> ", expected FloatVal(" <> string.inspect(expected_float) <> ")")
            False
          }
          Error(err) -> {
            io.println("  ✗ get_typed_value(" <> path <> ") error: " <> err)
            False
          }
        }
      }
      test_suite_types.BoolVal(expected_bool) -> {
        case ccl.get_typed_value_with_options(parsed, path, ccl_options) {
          Ok(ccl.BoolVal(actual_bool)) -> {
            case actual_bool == expected_bool {
              True -> {
                io.println("  ✓ get_typed_value(" <> path <> ") = BoolVal(" <> string.inspect(actual_bool) <> ")")
                True
              }
              False -> {
                io.println("  ✗ get_typed_value(" <> path <> ") = BoolVal(" <> string.inspect(actual_bool) <> "), expected BoolVal(" <> string.inspect(expected_bool) <> ")")
                False
              }
            }
          }
          Ok(other) -> {
            io.println("  ✗ get_typed_value(" <> path <> ") = " <> string.inspect(other) <> ", expected BoolVal(" <> string.inspect(expected_bool) <> ")")
            False
          }
          Error(err) -> {
            io.println("  ✗ get_typed_value(" <> path <> ") error: " <> err)
            False
          }
        }
      }
      test_suite_types.EmptyVal -> {
        case ccl.get_typed_value_with_options(parsed, path, ccl_options) {
          Ok(ccl.EmptyVal) -> {
            io.println("  ✓ get_typed_value(" <> path <> ") = EmptyVal")
            True
          }
          Ok(other) -> {
            io.println("  ✗ get_typed_value(" <> path <> ") = " <> string.inspect(other) <> ", expected EmptyVal")
            False
          }
          Error(err) -> {
            io.println("  ✗ get_typed_value(" <> path <> ") error: " <> err)
            False
          }
        }
      }
    }
  })
}
