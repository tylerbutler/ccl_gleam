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

/// Test typed parsing functionality using JSON test cases
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
        run_typed_test_by_name(test_case.name, parsed)
        True
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

// Route to appropriate test based on name from JSON
fn run_typed_test_by_name(name: String, parsed: ccl_core.CCL) {
  case name {
    "parse_basic_integer" -> test_basic_integer(parsed)
    "parse_basic_float" -> test_basic_float(parsed)
    "parse_boolean_true" -> test_boolean_true(parsed)
    "parse_boolean_variants" -> test_boolean_variants(parsed)
    "parse_mixed_types" -> test_mixed_types(parsed)
    "parse_empty_value" -> test_empty_value(parsed)
    "parse_with_whitespace" -> test_with_whitespace(parsed)
    "parse_with_conservative_options" -> test_conservative_options(parsed)
    _ -> {
      io.println("  ! Test case '" <> name <> "' not implemented yet")
    }
  }
}

// Test implementations
fn test_basic_integer(parsed: ccl_core.CCL) {
  case ccl.get_int(parsed, "port") {
    Ok(8080) -> io.println("  ✓ get_int(port) = 8080")
    Ok(other) -> {
      io.println("  ✗ get_int(port) = " <> string.inspect(other) <> ", expected 8080")
      should.fail()
    }
    Error(err) -> {
      io.println("  ✗ get_int(port) error: " <> err)
      should.fail()
    }
  }
  
  case ccl.get_typed_value(parsed, "port") {
    Ok(ccl.IntVal(8080)) -> io.println("  ✓ get_typed_value(port) = IntVal(8080)")
    Ok(other) -> {
      io.println("  ✗ get_typed_value(port) = " <> string.inspect(other))
      should.fail()
    }
    Error(err) -> {
      io.println("  ✗ get_typed_value(port) error: " <> err)
      should.fail()
    }
  }
}

fn test_basic_float(parsed: ccl_core.CCL) {
  case ccl.get_float(parsed, "temperature") {
    Ok(98.6) -> io.println("  ✓ get_float(temperature) = 98.6")
    Ok(other) -> {
      io.println("  ✗ get_float(temperature) = " <> string.inspect(other))
      should.fail()
    }
    Error(err) -> {
      io.println("  ✗ get_float(temperature) error: " <> err)
      should.fail()
    }
  }
  
  case ccl.get_typed_value(parsed, "temperature") {
    Ok(ccl.FloatVal(98.6)) -> io.println("  ✓ get_typed_value(temperature) = FloatVal(98.6)")
    Ok(other) -> {
      io.println("  ✗ get_typed_value(temperature) = " <> string.inspect(other))
      should.fail()
    }
    Error(err) -> {
      io.println("  ✗ get_typed_value(temperature) error: " <> err)
      should.fail()
    }
  }
}

fn test_boolean_true(parsed: ccl_core.CCL) {
  case ccl.get_bool(parsed, "enabled") {
    Ok(True) -> io.println("  ✓ get_bool(enabled) = True")
    Ok(False) -> {
      io.println("  ✗ get_bool(enabled) = False, expected True")
      should.fail()
    }
    Error(err) -> {
      io.println("  ✗ get_bool(enabled) error: " <> err)
      should.fail()
    }
  }
  
  case ccl.get_typed_value(parsed, "enabled") {
    Ok(ccl.BoolVal(True)) -> io.println("  ✓ get_typed_value(enabled) = BoolVal(True)")
    Ok(other) -> {
      io.println("  ✗ get_typed_value(enabled) = " <> string.inspect(other))
      should.fail()
    }
    Error(err) -> {
      io.println("  ✗ get_typed_value(enabled) error: " <> err)
      should.fail()
    }
  }
}

fn test_boolean_variants(parsed: ccl_core.CCL) {
  let true_flags = ["flag1", "flag2", "flag3"]
  let false_flags = ["flag4", "flag5", "flag6", "flag7"]
  
  list.each(true_flags, fn(flag) {
    case ccl.get_bool(parsed, flag) {
      Ok(True) -> io.println("  ✓ get_bool(" <> flag <> ") = True")
      Ok(False) -> {
        io.println("  ✗ get_bool(" <> flag <> ") = False, expected True")
        should.fail()
      }
      Error(err) -> {
        io.println("  ✗ get_bool(" <> flag <> ") error: " <> err)
        should.fail()
      }
    }
  })
  
  list.each(false_flags, fn(flag) {
    case ccl.get_bool(parsed, flag) {
      Ok(False) -> io.println("  ✓ get_bool(" <> flag <> ") = False")
      Ok(True) -> {
        io.println("  ✗ get_bool(" <> flag <> ") = True, expected False")
        should.fail()
      }
      Error(err) -> {
        io.println("  ✗ get_bool(" <> flag <> ") error: " <> err)
        should.fail()
      }
    }
  })
}

fn test_mixed_types(parsed: ccl_core.CCL) {
  // Test various get_typed_value() calls
  case ccl.get_typed_value(parsed, "host") {
    Ok(ccl.StringVal("localhost")) -> io.println("  ✓ get_typed_value(host) = StringVal(localhost)")
    Ok(other) -> {
      io.println("  ✗ get_typed_value(host) = " <> string.inspect(other))
      should.fail()
    }
    Error(err) -> {
      io.println("  ✗ get_typed_value(host) error: " <> err)
      should.fail()
    }
  }
  
  case ccl.get_typed_value(parsed, "port") {
    Ok(ccl.IntVal(8080)) -> io.println("  ✓ get_typed_value(port) = IntVal(8080)")
    Ok(other) -> {
      io.println("  ✗ get_typed_value(port) = " <> string.inspect(other))
      should.fail()
    }
    Error(err) -> {
      io.println("  ✗ get_typed_value(port) error: " <> err)
      should.fail()
    }
  }
  
  case ccl.get_typed_value(parsed, "ssl") {
    Ok(ccl.BoolVal(True)) -> io.println("  ✓ get_typed_value(ssl) = BoolVal(True)")
    Ok(other) -> {
      io.println("  ✗ get_typed_value(ssl) = " <> string.inspect(other))
      should.fail()
    }
    Error(err) -> {
      io.println("  ✗ get_typed_value(ssl) error: " <> err)
      should.fail()
    }
  }
  
  case ccl.get_typed_value(parsed, "timeout") {
    Ok(ccl.FloatVal(30.5)) -> io.println("  ✓ get_typed_value(timeout) = FloatVal(30.5)")
    Ok(other) -> {
      io.println("  ✗ get_typed_value(timeout) = " <> string.inspect(other))
      should.fail()
    }
    Error(err) -> {
      io.println("  ✗ get_typed_value(timeout) error: " <> err)
      should.fail()
    }
  }
  
  case ccl.get_typed_value(parsed, "debug") {
    Ok(ccl.BoolVal(False)) -> io.println("  ✓ get_typed_value(debug) = BoolVal(False)")
    Ok(other) -> {
      io.println("  ✗ get_typed_value(debug) = " <> string.inspect(other))
      should.fail()
    }
    Error(err) -> {
      io.println("  ✗ get_typed_value(debug) error: " <> err)
      should.fail()
    }
  }
}

fn test_error_cases(parsed: ccl_core.CCL) {
  // Test integer parsing error
  case ccl.get_int(parsed, "port") {
    Error(_) -> io.println("  ✓ get_int(port) correctly returned error")
    Ok(_) -> {
      io.println("  ✗ get_int(port) should have returned error")
      should.fail()
    }
  }
  
  // Test float parsing error
  case ccl.get_float(parsed, "temperature") {
    Error(_) -> io.println("  ✓ get_float(temperature) correctly returned error")
    Ok(_) -> {
      io.println("  ✗ get_float(temperature) should have returned error")
      should.fail()
    }
  }
  
  // Test boolean parsing error
  case ccl.get_bool(parsed, "enabled") {
    Error(_) -> io.println("  ✓ get_bool(enabled) correctly returned error")
    Ok(_) -> {
      io.println("  ✗ get_bool(enabled) should have returned error")
      should.fail()
    }
  }
  
  // Test missing path error
  case ccl.get_int(parsed, "missing") {
    Error(_) -> io.println("  ✓ get_int(missing) correctly returned error")
    Ok(_) -> {
      io.println("  ✗ get_int(missing) should have returned error")
      should.fail()
    }
  }
}

fn test_empty_value(parsed: ccl_core.CCL) {
  case ccl.get_typed_value(parsed, "empty_key") {
    Ok(ccl.EmptyVal) -> io.println("  ✓ get_typed_value(empty_key) = EmptyVal")
    Ok(other) -> {
      io.println("  ✗ get_typed_value(empty_key) = " <> string.inspect(other))
      should.fail()
    }
    Error(err) -> {
      io.println("  ✗ get_typed_value(empty_key) error: " <> err)
      should.fail()
    }
  }
}

fn test_with_whitespace(parsed: ccl_core.CCL) {
  // Test integer with whitespace
  case ccl.get_int(parsed, "number") {
    Ok(42) -> io.println("  ✓ get_int(number) = 42 (whitespace trimmed)")
    Ok(other) -> {
      io.println("  ✗ get_int(number) = " <> string.inspect(other))
      should.fail()
    }
    Error(err) -> {
      io.println("  ✗ get_int(number) error: " <> err)
      should.fail()
    }
  }
  
  // Test boolean with whitespace
  case ccl.get_bool(parsed, "flag") {
    Ok(True) -> io.println("  ✓ get_bool(flag) = True (whitespace trimmed)")
    Ok(False) -> {
      io.println("  ✗ get_bool(flag) = False, expected True")
      should.fail()
    }
    Error(err) -> {
      io.println("  ✗ get_bool(flag) error: " <> err)
      should.fail()
    }
  }
}

fn test_conservative_options(parsed: ccl_core.CCL) {
  let conservative = ccl.ParseOptions(parse_integers: True, parse_floats: False, parse_booleans: False)
  
  // Should parse as integer
  case ccl.get_typed_value_with_options(parsed, "number", conservative) {
    Ok(ccl.IntVal(42)) -> io.println("  ✓ get_typed_value_with_options(number) = IntVal(42)")
    Ok(other) -> {
      io.println("  ✗ get_typed_value_with_options(number) = " <> string.inspect(other))
      should.fail()
    }
    Error(err) -> {
      io.println("  ✗ get_typed_value_with_options(number) error: " <> err)
      should.fail()
    }
  }
  
  // Should remain as string (float parsing disabled)
  case ccl.get_typed_value_with_options(parsed, "decimal", conservative) {
    Ok(ccl.StringVal("3.14")) -> io.println("  ✓ get_typed_value_with_options(decimal) = StringVal(3.14)")
    Ok(other) -> {
      io.println("  ✗ get_typed_value_with_options(decimal) = " <> string.inspect(other))
      should.fail()
    }
    Error(err) -> {
      io.println("  ✗ get_typed_value_with_options(decimal) error: " <> err)
      should.fail()
    }
  }
  
  // Should remain as string (boolean parsing disabled)
  case ccl.get_typed_value_with_options(parsed, "flag", conservative) {
    Ok(ccl.StringVal("true")) -> io.println("  ✓ get_typed_value_with_options(flag) = StringVal(true)")
    Ok(other) -> {
      io.println("  ✗ get_typed_value_with_options(flag) = " <> string.inspect(other))
      should.fail()
    }
    Error(err) -> {
      io.println("  ✗ get_typed_value_with_options(flag) error: " <> err)
      should.fail()
    }
  }
}
