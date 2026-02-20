/// Test report rendering for CLI output
///
/// Produces a clean, scannable test report using birch console features
/// (boxes, semantic types) and direct io.println for formatted output.
import birch/handler/console
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import test_types.{
  type ImplementationConfig, type TestResult, type TestSuiteResult, TestFailed,
}

// ============================================================================
// ANSI helpers
// ============================================================================

const reset = "\u{001b}[0m"

const bold = "\u{001b}[1m"

const dim = "\u{001b}[2m"

const green = "\u{001b}[32m"

const red = "\u{001b}[31m"



// ============================================================================
// Public API
// ============================================================================

/// Print the full test report: header, per-file results, and summary.
pub fn print_report(
  results: List(TestSuiteResult),
  config: ImplementationConfig,
  test_dir: String,
) -> Nil {
  print_header(config, test_dir)
  io.println("")

  list.each(results, print_file_result)

  print_summary(results)
}

// ============================================================================
// Header
// ============================================================================

fn print_header(config: ImplementationConfig, test_dir: String) -> Nil {
  let functions_line = "Functions: " <> string.join(config.functions, ", ")
  let dir_line = "Directory: " <> test_dir
  let body = functions_line <> "\n" <> dir_line
  console.write_box_with_title(body, "CCL Test Runner")
}

// ============================================================================
// Per-file results
// ============================================================================

fn print_file_result(suite_result: TestSuiteResult) -> Nil {
  let name = get_filename(suite_result.file)

  // File header line with counts
  let counts = format_counts(suite_result)
  io.println(
    bold <> "── " <> name <> " " <> reset <> dim <> counts <> reset,
  )

  // Show failures with details
  let failures = get_failures(suite_result.results)
  case failures {
    [] -> Nil
    _ -> {
      list.each(failures, print_failure)
    }
  }

  io.println("")
}

fn format_counts(r: TestSuiteResult) -> String {
  let parts = []

  let parts = case r.passed > 0 {
    True -> list.append(parts, [green <> "✔ " <> int.to_string(r.passed) <> " passed" <> reset])
    False -> parts
  }

  let parts = case r.failed > 0 {
    True -> list.append(parts, [red <> "✖ " <> int.to_string(r.failed) <> " failed" <> reset])
    False -> parts
  }

  let parts = case r.skipped > 0 {
    True -> list.append(parts, [dim <> "○ " <> int.to_string(r.skipped) <> " skipped" <> reset])
    False -> parts
  }

  string.join(parts, "  ")
}

// ============================================================================
// Failure details
// ============================================================================

fn get_failures(results: List(TestResult)) -> List(TestResult) {
  list.filter(results, fn(r) {
    case r {
      TestFailed(_, _, _) -> True
      _ -> False
    }
  })
}

fn print_failure(result: TestResult) -> Nil {
  case result {
    TestFailed(name, reason, _) -> {
      io.println("  " <> red <> "✖ " <> bold <> name <> reset)
      // Indent each line of the reason
      reason
      |> string.split("\n")
      |> list.each(fn(line) { io.println("    " <> line) })
    }
    _ -> Nil
  }
}

// ============================================================================
// Summary
// ============================================================================

fn print_summary(results: List(TestSuiteResult)) -> Nil {
  let total_passed =
    results |> list.map(fn(r) { r.passed }) |> list.fold(0, fn(a, n) { a + n })
  let total_failed =
    results |> list.map(fn(r) { r.failed }) |> list.fold(0, fn(a, n) { a + n })
  let total_skipped =
    results
    |> list.map(fn(r) { r.skipped })
    |> list.fold(0, fn(a, n) { a + n })
  let total = total_passed + total_failed + total_skipped

  let total_f = int.to_float(total)

  let pass_pct = format_pct(total_passed, total_f)
  let fail_pct = format_pct(total_failed, total_f)
  let skip_pct = format_pct(total_skipped, total_f)

  let files_count = list.length(results)
  let failed_files =
    list.count(results, fn(r) { r.failed > 0 })

  let separator = dim <> string.repeat("─", 44) <> reset

  io.println(separator)
  io.println(bold <> "Summary" <> reset)
  io.println("")

  io.println(
    "  Files:    "
    <> int.to_string(files_count)
    <> case failed_files > 0 {
      True -> "  " <> dim <> "(" <> int.to_string(failed_files) <> " with failures)" <> reset
      False -> ""
    },
  )
  io.println("  Total:    " <> int.to_string(total))
  io.println(
    "  "
    <> green
    <> "Passed:   "
    <> pad_left(int.to_string(total_passed), 4)
    <> "  ("
    <> pass_pct
    <> ")"
    <> reset,
  )
  io.println(
    "  "
    <> case total_failed > 0 {
      True -> red
      False -> green
    }
    <> "Failed:   "
    <> pad_left(int.to_string(total_failed), 4)
    <> "  ("
    <> fail_pct
    <> ")"
    <> reset,
  )
  io.println(
    "  "
    <> dim
    <> "Skipped:  "
    <> pad_left(int.to_string(total_skipped), 4)
    <> "  ("
    <> skip_pct
    <> ")"
    <> reset,
  )

  io.println(separator)
}

// ============================================================================
// Helpers
// ============================================================================

fn get_filename(path: String) -> String {
  path
  |> string.split("/")
  |> list.last
  |> result.unwrap(path)
}

fn pad_left(s: String, width: Int) -> String {
  let len = string.length(s)
  case len >= width {
    True -> s
    False -> string.repeat(" ", width - len) <> s
  }
}

fn format_pct(count: Int, total: Float) -> String {
  case total >. 0.0 {
    True -> {
      let pct = int.to_float(count) *. 100.0 /. total
      let rounded = float.round(pct *. 10.0) |> int.to_float |> fn(x) { x /. 10.0 }
      float.to_string(rounded) <> "%"
    }
    False -> "0%"
  }
}
