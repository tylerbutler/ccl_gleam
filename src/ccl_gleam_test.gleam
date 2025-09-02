import ccl_core
import gleam/io
import gleam/list
import gleam/string
import gleeunit
import gleeunit/should
import test_suite_types

pub fn main() {
  // Run the JSON test suite directly
  io.println("=== CCL JSON Test Suite ===")
  
  let test_cases = test_suite_types.get_test_cases()
  io.println("Loaded " <> string.inspect(list.length(test_cases)) <> " test cases")

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

  // Test error cases too
  let error_test_cases = test_suite_types.get_error_test_cases()
  io.println("\nLoaded " <> string.inspect(list.length(error_test_cases)) <> " error test cases")
  
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
      }
      Error(_err) -> {
        io.println("  ✓ PASS - Got expected error")
      }
    }
  })
}