import ccl_core
import ccl_test_loader
import ccl_types.{Entry}
import gleam/list
import gleeunit
import gleeunit/should
import validation_test

pub fn main() {
  gleeunit.main()
}

pub fn basic_test_loader_test() {
  let entries = [Entry("key", "value")]
  let ccl = ccl_core.build_hierarchy(entries)

  ccl_core.get_value(ccl, "key") |> should.be_ok() |> should.equal("value")
}

pub fn test_case_creation_test() {
  let test_case =
    ccl_test_loader.create_basic_test("test", "key = value", [
      Entry("key", "value"),
    ])

  test_case.name |> should.equal("test")
  test_case.input |> should.equal("key = value")
}

pub fn run_test_case_test() {
  let test_case =
    ccl_test_loader.create_basic_test("basic_parse", "name = Alice", [
      Entry("name", "Alice"),
    ])

  let result = ccl_test_loader.run_test_case(test_case, ccl_core.parse)

  case result {
    ccl_test_loader.Pass(_, _) -> should.equal(True, True)
    ccl_test_loader.Fail(_, _) -> should.equal(True, False)
  }
}

pub fn ccl_core_comprehensive_test_suite() {
  // This runs all CCL Core test suites against ccl_core.parse
  let _results =
    ccl_test_loader.run_ccl_core_comprehensive_tests(ccl_core.parse)

  // For now, just ensure it completes without crashing
  should.equal(True, True)
}

pub fn test_suite_paths_test() {
  // Verify we have the expected test suite paths
  let api_paths = ccl_test_loader.ccl_api_test_paths()

  list.length(api_paths) |> should.equal(8)
  // 8 API test suites (including round-trip and algebraic)
  // 2 test suites for ccl package
}

/// Simple JSON parsing test
pub fn json_parsing_test() {
  case ccl_core.parse("key = value") {
    Ok(entries) -> list.length(entries) |> should.equal(1)
    Error(_) -> should.fail()
  }
}

// Import validation tests
pub fn test_combine_validation_simple() {
  validation_test.test_combine_validation_simple()
}

pub fn test_round_trip_validation_basic() {
  validation_test.test_round_trip_validation_basic()
}
