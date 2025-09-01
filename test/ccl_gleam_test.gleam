import ccl
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

  let results =
    list.map(test_cases, fn(test_case) {
      io.println(
        "Running test: " <> test_case.name <> " - " <> test_case.description,
      )

      case ccl.parse(test_case.input) {
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
  case ccl.parse("invalid\nno equals") {
    Error(ccl.ParseError(line: _, reason: _)) -> should.equal(True, True)
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

    case ccl.parse(error_test_case.input) {
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
