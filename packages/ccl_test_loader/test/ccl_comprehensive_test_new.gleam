import api_test_runner
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleeunit
import gleeunit/should
import property_test_runner
import test_suite_types

pub fn main() {
  // Print test overview first
  print_new_test_overview()
  gleeunit.main()
}

fn print_new_test_overview() {
  io.println("=== NEW JSON-BASED CCL TEST SUITE ===")

  let api_paths = test_suite_types.api_test_paths()
  let property_paths = test_suite_types.property_test_paths()

  let api_test_count = count_tests_in_files(api_paths)
  let property_test_count = count_tests_in_files(property_paths)
  let total_count = api_test_count + property_test_count

  io.println("API Tests: " <> string.inspect(api_test_count) <> " tests")
  io.println(
    "Property Tests: " <> string.inspect(property_test_count) <> " tests",
  )
  io.println("Total: " <> string.inspect(total_count) <> " tests")
  io.println("")
}

fn count_tests_in_files(paths: List(String)) -> Int {
  list.fold(paths, 0, fn(acc, path) {
    case test_suite_types.load_new_test_suite(path) {
      Ok(suite) -> acc + list.length(suite.tests)
      Error(_) -> acc
    }
  })
}

/// Run all API tests from JSON files
pub fn comprehensive_api_tests() {
  io.println("\n=== API TESTS ===")
  let api_paths = test_suite_types.api_test_paths()
  let total_tests = run_all_api_test_files(api_paths)
  io.println("API Tests: " <> string.inspect(total_tests) <> " total tests")
}

/// Run all property tests from JSON files  
pub fn comprehensive_property_tests() {
  io.println("\n=== PROPERTY TESTS ===")
  let property_paths = test_suite_types.property_test_paths()
  let total_tests = run_all_property_test_files(property_paths)
  io.println(
    "Property Tests: " <> string.inspect(total_tests) <> " total tests",
  )
}

/// Helper to run all API test files
fn run_all_api_test_files(paths: List(String)) -> Int {
  list.fold(paths, 0, fn(acc, path) {
    case test_suite_types.load_new_test_suite(path) {
      Ok(suite) -> {
        io.println("Running " <> suite.suite)
        let test_count = run_api_test_suite(suite)
        acc + test_count
      }
      Error(error) -> {
        io.println("Failed to load " <> path <> ": " <> error)
        acc
      }
    }
  })
}

/// Helper to run all property test files
fn run_all_property_test_files(paths: List(String)) -> Int {
  list.fold(paths, 0, fn(acc, path) {
    case test_suite_types.load_new_test_suite(path) {
      Ok(suite) -> {
        io.println("Running " <> suite.suite)
        let test_count = run_property_test_suite(suite)
        acc + test_count
      }
      Error(error) -> {
        io.println("Failed to load " <> path <> ": " <> error)
        acc
      }
    }
  })
}

/// Run an API test suite and return test count
fn run_api_test_suite(suite: test_suite_types.NewTestSuite) -> Int {
  let results =
    list.map(suite.tests, fn(test_case) {
      let api_results = api_test_runner.run_api_test(test_case)
      let all_passed = case list.length(api_results) {
        0 -> True
        // No validations to run
        _ ->
          list.all(api_results, fn(result) {
            case result {
              api_test_runner.ParseTestResult(_, _, passed) -> passed
              api_test_runner.MakeObjectsTestResult(_, _, passed) -> passed
              api_test_runner.GetStringTestResult(_, _, passed) -> passed
              api_test_runner.GetListTestResult(_, _, passed) -> passed
              api_test_runner.NodeTypeTestResult(_, _, passed) -> passed
            }
          })
      }

      case all_passed {
        False -> {
          io.println("FAILED: " <> test_case.name)
          list.each(api_results, fn(result) {
            case result {
              api_test_runner.ParseTestResult(_, _, False) ->
                io.println("  Parse test failed")
              api_test_runner.MakeObjectsTestResult(_, _, False) ->
                io.println("  MakeObjects test failed")
              api_test_runner.GetStringTestResult(_, _, False) ->
                io.println("  GetString test failed")
              api_test_runner.GetListTestResult(_, _, False) ->
                io.println("  GetList test failed")
              api_test_runner.NodeTypeTestResult(_, _, False) ->
                io.println("  NodeType test failed")
              _ -> Nil
            }
          })
        }
        True -> Nil
      }
      all_passed
    })

  let passed = list.count(results, fn(r) { r == True })
  let total = list.length(results)

  io.println(
    suite.suite
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

  total
}

/// Run a property test suite and return test count
fn run_property_test_suite(suite: test_suite_types.NewTestSuite) -> Int {
  let results =
    list.map(suite.tests, fn(test_case) {
      let property_results = property_test_runner.run_property_test(test_case)
      let all_passed = case list.length(property_results) {
        0 -> True
        // No validations to run
        _ ->
          list.all(property_results, fn(result) {
            case result {
              property_test_runner.AssociativityTestResult(passed, _) -> passed
              property_test_runner.RoundTripTestResult(passed, _) -> passed
            }
          })
      }

      case all_passed {
        False -> {
          io.println("FAILED: " <> test_case.name)
          list.each(property_results, fn(result) {
            case result {
              property_test_runner.AssociativityTestResult(False, error) -> {
                io.println("  Associativity test failed")
                case error {
                  Some(err) -> io.println("    Error: " <> err)
                  None -> Nil
                }
              }
              property_test_runner.RoundTripTestResult(False, error) -> {
                io.println("  Round-trip test failed")
                case error {
                  Some(err) -> io.println("    Error: " <> err)
                  None -> Nil
                }
              }
              _ -> Nil
            }
          })
        }
        True -> Nil
      }
      all_passed
    })

  let passed = list.count(results, fn(r) { r == True })
  let total = list.length(results)

  io.println(
    suite.suite
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

  total
}
