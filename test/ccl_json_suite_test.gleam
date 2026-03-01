/// Startest-based wrapper for the CCL JSON test suite.
///
/// Loads all JSON test files from ccl-test-data/, converts each test case
/// into a startest `it`/`xit` node, and runs them through `gleam test`.
///
/// This gives individual test-level reporting, name-based filtering, and
/// standard `gleam test` integration while reusing the existing test runner
/// and loader infrastructure.
///
/// The CLI test runner (`gleam run -- run`) is still available for the TUI,
/// stats, and other specialized use cases.
import gleam/list
import gleam/result
import gleam/string
import startest
import startest/assertion_error.{AssertionError}
import test_runner/filter
import test_runner/loader
import test_runner/runner
import test_runner/types.{TestFailed, TestPassed, TestSkipped}

const test_data_dir = "./ccl-test-data"

pub fn main() {
  startest.run(startest.default_config())
}

/// Generates a startest `describe` tree from each JSON test file.
///
/// Structure: `CCL JSON Suite ❯ <filename> ❯ <test name>`
///
/// Tests that are incompatible with the current implementation config
/// are marked as skipped via `xit`.
pub fn ccl_json_suite_tests() {
  let config = filter.full_config()

  let files = case loader.list_test_files(test_data_dir) {
    Ok(f) -> f
    Error(e) -> {
      panic as { "Failed to list test files in " <> test_data_dir <> ": " <> e }
    }
  }

  startest.describe(
    "CCL JSON Suite",
    files
      |> list.map(fn(file) {
        let filename = file_basename(file)
        let suite = case loader.load_test_file(file) {
          Ok(s) -> s
          Error(e) -> {
            panic as { "Failed to load " <> file <> ": " <> e }
          }
        }

        startest.describe(
          filename,
          suite.tests
            |> list.map(fn(tc) {
              case filter.get_skip_reason(config, tc) {
                // Incompatible — skip it
                Error(_reason) -> startest.xit(tc.name, fn() { Nil })
                // Compatible — run through the existing runner
                Ok(Nil) ->
                  startest.it(tc.name, fn() {
                    let result = runner.run_single_test(tc, config)
                    assert_test_result(result)
                  })
              }
            }),
        )
      }),
  )
}

/// Convert a TestResult from the existing runner into a startest assertion.
///
/// Passed tests succeed silently. Failed tests raise an `AssertionError` with
/// separate actual/expected fields so startest renders its coloured diff output.
/// Skipped results should not reach here (handled by `xit` above), but are
/// tolerated as a pass.
fn assert_test_result(result: types.TestResult) -> Nil {
  case result {
    TestPassed(_, _) -> Nil
    TestFailed(_name, detail) -> {
      AssertionError(detail.reason, detail.actual, detail.expected)
      |> assertion_error.raise
    }
    TestSkipped(_, _) -> Nil
  }
}

/// Extract the filename from a path.
fn file_basename(path: String) -> String {
  path
  |> string.split("/")
  |> list.last
  |> result.unwrap(path)
}
