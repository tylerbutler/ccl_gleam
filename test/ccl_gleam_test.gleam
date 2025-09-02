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

/// Test typed parsing functionality as extension to core CCL tests
pub fn ccl_typed_parsing_test() {
  io.println("\n=== CCL Typed Parsing Tests ===")
  
  // Test cases based on our JSON test design
  let test_cases = [
    #("basic_integer", "port = 8080", test_basic_integer),
    #("basic_float", "temperature = 98.6", test_basic_float),
    #("boolean_true", "enabled = true", test_boolean_true),
    #("boolean_variants", "flag1 = yes\nflag2 = on\nflag3 = 1\nflag4 = false\nflag5 = no\nflag6 = off\nflag7 = 0", test_boolean_variants),
    #("mixed_types", "host = localhost\nport = 8080\nssl = true\ntimeout = 30.5\ndebug = off", test_mixed_types),
    #("error_cases", "port = not_a_number\ntemperature = invalid\nenabled = maybe", test_error_cases),
  ]
  
  let passed = list.count(test_cases, fn(test_case) {
    let #(name, input, test_fn) = test_case
    io.println("Running typed test: " <> name)
    
    case ccl_core.parse(input) {
      Ok(entries) -> {
        let parsed = ccl_core.make_objects(entries)
        test_fn(parsed)
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
