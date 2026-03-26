/// CLI command implementations for CCL test runner.
///
/// No more mock implementation — calls ccl/ library directly via test_runner.
import birch
import cli/flags
import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import glint
import simplifile
import test_runner/filter
import test_runner/loader
import test_runner/runner
import test_runner/types.{
  type ImplementationConfig, type TestCase, ImplementationConfig,
}

/// Result type for commands
pub type CommandResult {
  Success
  Failure(message: String)
}

/// Build implementation config from flag values
pub fn build_config(
  functions: List(String),
  behaviours: List(String),
  features: List(String),
  variants: List(String),
) -> ImplementationConfig {
  let final_functions = case functions {
    [] -> [
      "parse", "print", "build_hierarchy", "canonical_format", "get_string",
      "get_int", "get_bool", "get_float", "get_list",
    ]
    funcs -> funcs
  }

  let final_behaviours = case behaviours {
    [] -> [
      "crlf_normalize_to_lf", "toplevel_indent_strip", "boolean_strict",
      "tabs_as_whitespace", "list_coercion_disabled", "array_order_insertion",
      "indent_spaces",
    ]
    behavs -> behavs
  }

  ImplementationConfig(
    functions: final_functions,
    behaviours: final_behaviours,
    variants: variants,
    features: features,
  )
}

/// Run command - executes tests against the implementation
pub fn run_command() -> glint.Command(CommandResult) {
  use <- glint.command_help(
    "Run CCL tests against the implementation.

Executes the test suite and reports results with pass/fail/skip counts.",
  )
  use test_dir <- glint.named_arg("directory")
  use functions <- glint.flag(flags.functions_flag())
  use behaviours <- glint.flag(flags.behaviours_flag())
  use features <- glint.flag(flags.features_flag())
  use variants <- glint.flag(flags.variants_flag())
  use named, _args, cmd_flags <- glint.command()

  let dir = test_dir(named)
  let assert Ok(funcs) = functions(cmd_flags)
  let assert Ok(behavs) = behaviours(cmd_flags)
  let assert Ok(feats) = features(cmd_flags)
  let assert Ok(vars) = variants(cmd_flags)

  let config = build_config(funcs, behavs, feats, vars)
  run_tests(dir, config)
}

/// Run tests and return result
fn run_tests(test_dir: String, config: ImplementationConfig) -> CommandResult {
  birch.info_m("Starting test runner", [
    #("dir", test_dir),
    #("functions", string.join(config.functions, ", ")),
  ])

  case runner.run_test_directory(test_dir, config) {
    Ok(results) -> {
      runner.print_results(results)

      let total_failed =
        results
        |> list.map(fn(r) { r.failed })
        |> list.fold(0, fn(acc, n) { acc + n })

      case total_failed > 0 {
        True -> Failure("Tests failed: " <> int.to_string(total_failed))
        False -> Success
      }
    }
    Error(e) -> {
      birch.error_m("Failed to run tests", [#("error", e)])
      Failure(e)
    }
  }
}

/// List command - lists test files with counts
pub fn list_command() -> glint.Command(CommandResult) {
  use <- glint.command_help(
    "List test files in a directory with test counts.

Displays each JSON test file with its number of tests.",
  )
  use test_dir <- glint.named_arg("directory")
  use named, _args, _flags <- glint.command()

  let dir = test_dir(named)
  list_files(dir)
}

/// List test files with counts
fn list_files(test_dir: String) -> CommandResult {
  case loader.list_test_files(test_dir) {
    Ok(files) -> {
      io.println("")
      io.println("CCL Test Files")
      io.println("==============")
      io.println("")

      let total_tests =
        files
        |> list.map(fn(file) {
          let count = get_test_count(file)
          let name = get_filename(file)
          let size = get_file_size(file)
          io.println(
            pad_right(name, 45)
            <> " "
            <> pad_left(int.to_string(count), 5)
            <> " tests  "
            <> size,
          )
          count
        })
        |> list.fold(0, fn(acc, n) { acc + n })

      io.println("")
      io.println(
        "Total: "
        <> int.to_string(list.length(files))
        <> " files, "
        <> int.to_string(total_tests)
        <> " tests",
      )
      io.println("")
      Success
    }
    Error(e) -> Failure(e)
  }
}

/// Stats command - show detailed test suite statistics
pub fn stats_command() -> glint.Command(CommandResult) {
  use <- glint.command_help(
    "Show detailed statistics about the test suite.

Displays counts by validation type, function tags, and behaviours.",
  )
  use test_dir <- glint.named_arg("directory")
  use functions <- glint.flag(flags.functions_flag())
  use behaviours <- glint.flag(flags.behaviours_flag())
  use features <- glint.flag(flags.features_flag())
  use variants <- glint.flag(flags.variants_flag())
  use named, _args, cmd_flags <- glint.command()

  let dir = test_dir(named)
  let assert Ok(funcs) = functions(cmd_flags)
  let assert Ok(behavs) = behaviours(cmd_flags)
  let assert Ok(feats) = features(cmd_flags)
  let assert Ok(vars) = variants(cmd_flags)

  let config = build_config(funcs, behavs, feats, vars)
  show_stats(dir, config)
}

/// Show detailed statistics
fn show_stats(test_dir: String, config: ImplementationConfig) -> CommandResult {
  case loader.list_test_files(test_dir) {
    Ok(files) -> {
      io.println("")
      io.println("CCL Test Suite Statistics")
      io.println("=========================")
      io.println("")

      let all_suites: List(#(String, types.TestSuite)) =
        files
        |> list.filter_map(fn(file) {
          case loader.load_test_file(file) {
            Ok(suite) -> Ok(#(file, suite))
            Error(_) -> Error(Nil)
          }
        })

      let all_tests: List(TestCase) =
        all_suites
        |> list.flat_map(fn(pair: #(String, types.TestSuite)) {
          { pair.1 }.tests
        })

      let total_count = list.length(all_tests)

      let validations: dict.Dict(String, List(TestCase)) =
        all_tests
        |> list.group(fn(tc: TestCase) { tc.validation })

      io.println("By Validation Type:")
      validations
      |> dict.to_list
      |> list.each(fn(pair: #(String, List(TestCase))) {
        let #(validation, tests) = pair
        io.println(
          "  "
          <> pad_right(validation, 20)
          <> " "
          <> int.to_string(list.length(tests)),
        )
      })

      io.println("")

      let function_counts =
        count_tags(all_tests, fn(tc: TestCase) { tc.functions })
      io.println("By Function:")
      function_counts
      |> list.each(fn(pair: #(String, Int)) {
        let #(func, count) = pair
        io.println("  " <> pad_right(func, 20) <> " " <> int.to_string(count))
      })

      io.println("")

      let compatible =
        all_tests
        |> list.filter(fn(tc) { filter.is_compatible(config, tc) })
      let compatible_count = list.length(compatible)
      let skipped_count = total_count - compatible_count

      io.println("Compatibility (with current config):")
      io.println(
        "  "
        <> pad_right("Compatible", 20)
        <> " "
        <> int.to_string(compatible_count),
      )
      io.println(
        "  "
        <> pad_right("Would skip", 20)
        <> " "
        <> int.to_string(skipped_count),
      )

      io.println("")
      io.println(
        "Total: "
        <> int.to_string(list.length(files))
        <> " files, "
        <> int.to_string(total_count)
        <> " tests",
      )
      io.println("")
      Success
    }
    Error(e) -> Failure(e)
  }
}

// Helper functions

fn get_test_count(file: String) -> Int {
  case loader.load_test_file(file) {
    Ok(suite) -> list.length(suite.tests)
    Error(_) -> 0
  }
}

fn get_filename(path: String) -> String {
  path
  |> string.split("/")
  |> list.last
  |> result.unwrap(path)
}

fn get_file_size(path: String) -> String {
  case simplifile.file_info(path) {
    Ok(info) -> format_size(info.size)
    Error(_) -> "?"
  }
}

fn format_size(bytes: Int) -> String {
  case bytes {
    b if b < 1024 -> int.to_string(b) <> "B"
    b if b < 1_048_576 -> {
      let kb = b / 1024
      int.to_string(kb) <> "K"
    }
    b -> {
      let mb = b / 1_048_576
      int.to_string(mb) <> "M"
    }
  }
}

fn pad_right(s: String, width: Int) -> String {
  let len = string.length(s)
  case len >= width {
    True -> s
    False -> s <> string.repeat(" ", width - len)
  }
}

fn pad_left(s: String, width: Int) -> String {
  let len = string.length(s)
  case len >= width {
    True -> s
    False -> string.repeat(" ", width - len) <> s
  }
}

fn count_tags(
  tests: List(TestCase),
  get_tags: fn(TestCase) -> List(String),
) -> List(#(String, Int)) {
  tests
  |> list.flat_map(get_tags)
  |> list.group(fn(tag) { tag })
  |> dict.to_list
  |> list.map(fn(pair: #(String, List(String))) {
    #(pair.0, list.length(pair.1))
  })
  |> list.sort(fn(a, b) { string.compare(a.0, b.0) })
}
