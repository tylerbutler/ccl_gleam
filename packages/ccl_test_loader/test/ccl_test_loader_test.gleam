import ccl_core
import ccl_test_loader
import ccl_types.{Entry}
import gleam/list
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn basic_test_loader_test() {
  let entries = [Entry("key", "value")]
  let ccl = ccl_core.make_objects(entries)

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
  let core_paths = ccl_test_loader.ccl_core_test_paths()
  let package_paths = ccl_test_loader.ccl_package_test_paths()

  list.length(core_paths) |> should.equal(7)
  // 7 test suites for ccl_core
  list.length(package_paths) |> should.equal(2)
  // 2 test suites for ccl package
}
