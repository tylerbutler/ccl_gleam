/// CLI command implementations for CCL test runner.
import birch
import cli/flags
import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import glint
import mock_implementation
import simplifile
import test_filter
import test_loader
import test_runner
import test_types.{
  type FailureGrouping, type ImplementationConfig, type TestCase, GroupByFile,
  GroupByValidation, ImplementationConfig,
}
import util

/// Result type for commands.
pub type CommandResult {
  Success
  Failure(message: String)
}

/// Build implementation config from flag values.
/// When no flags are provided, all fields default to empty lists —
/// the test runner assumes nothing is implemented. Pass an implementation's
/// config via `merge_with_impl_config` to use its declared capabilities
/// as the baseline.
pub fn build_config(
  functions: List(String),
  behaviors: List(String),
  features: List(String),
  variants: List(String),
) -> ImplementationConfig {
  ImplementationConfig(
    functions: functions,
    behaviors: behaviors,
    variants: variants,
    features: features,
  )
}

/// Merge CLI flag overrides with an implementation's declared config.
/// If a CLI flag list is non-empty, it overrides the implementation default;
/// otherwise the implementation's declared value is used.
pub fn merge_with_impl_config(
  cli_config: ImplementationConfig,
  impl_config: ImplementationConfig,
) -> ImplementationConfig {
  ImplementationConfig(
    functions: pick_non_empty(cli_config.functions, impl_config.functions),
    behaviors: pick_non_empty(cli_config.behaviors, impl_config.behaviors),
    variants: pick_non_empty(cli_config.variants, impl_config.variants),
    features: pick_non_empty(cli_config.features, impl_config.features),
  )
}

fn pick_non_empty(override: List(String), default: List(String)) -> List(String) {
  case override {
    [] -> default
    vals -> vals
  }
}

/// Run command - executes tests against the implementation.
pub fn run_command() -> glint.Command(CommandResult) {
  use <- glint.command_help(
    "Run CCL tests against an implementation.

Executes the test suite and reports results with pass/fail/skip counts.",
  )
  use test_dir <- glint.named_arg("directory")
  use functions <- glint.flag(flags.functions_flag())
  use behaviors <- glint.flag(flags.behaviors_flag())
  use features <- glint.flag(flags.features_flag())
  use variants <- glint.flag(flags.variants_flag())
  use group_by <- glint.flag(flags.group_by_flag())
  use named, _args, flags <- glint.command()

  let dir = test_dir(named)
  let assert Ok(funcs) = functions(flags)
  let assert Ok(behavs) = behaviors(flags)
  let assert Ok(feats) = features(flags)
  let assert Ok(vars) = variants(flags)
  let assert Ok(group_by_str) = group_by(flags)

  let cli_config = build_config(funcs, behavs, feats, vars)
  let config = merge_with_impl_config(cli_config, mock_implementation.config())
  let grouping = parse_grouping(group_by_str)
  run_tests(dir, config, grouping)
}

fn parse_grouping(s: String) -> FailureGrouping {
  case string.lowercase(s) {
    "validation" | "kind" -> GroupByValidation
    _ -> GroupByFile
  }
}

fn run_tests(
  test_dir: String,
  config: ImplementationConfig,
  grouping: FailureGrouping,
) -> CommandResult {
  let impl = mock_implementation.new()

  case test_runner.run_test_directory(test_dir, config, impl) {
    Ok(results) -> {
      test_runner.print_results(results, config, test_dir, grouping)

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

/// List command - lists test files with counts.
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

fn list_files(test_dir: String) -> CommandResult {
  case test_loader.list_test_files(test_dir) {
    Ok(files) -> {
      io.println("")
      io.println("CCL Test Files")
      io.println("==============")
      io.println("")

      let total_tests =
        files
        |> list.map(fn(file) {
          let count = get_test_count(file)
          let name = util.get_filename(file)
          let size = get_file_size(file)
          io.println(
            util.pad_right(name, 45)
            <> " "
            <> util.pad_left(int.to_string(count), 5)
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

/// Stats command - show detailed test suite statistics.
pub fn stats_command() -> glint.Command(CommandResult) {
  use <- glint.command_help(
    "Show detailed statistics about the test suite.

Displays counts by validation type, function tags, and behaviors.",
  )
  use test_dir <- glint.named_arg("directory")
  use functions <- glint.flag(flags.functions_flag())
  use behaviors <- glint.flag(flags.behaviors_flag())
  use features <- glint.flag(flags.features_flag())
  use variants <- glint.flag(flags.variants_flag())
  use named, _args, flags <- glint.command()

  let dir = test_dir(named)
  let assert Ok(funcs) = functions(flags)
  let assert Ok(behavs) = behaviors(flags)
  let assert Ok(feats) = features(flags)
  let assert Ok(vars) = variants(flags)

  let cli_config = build_config(funcs, behavs, feats, vars)
  let config = merge_with_impl_config(cli_config, mock_implementation.config())
  show_stats(dir, config)
}

fn show_stats(test_dir: String, config: ImplementationConfig) -> CommandResult {
  case test_loader.list_test_files(test_dir) {
    Ok(files) -> {
      io.println("")
      io.println("CCL Test Suite Statistics")
      io.println("=========================")
      io.println("")

      let all_suites =
        files
        |> list.filter_map(fn(file) {
          case test_loader.load_test_file(file) {
            Ok(suite) -> Ok(#(file, suite))
            Error(_) -> Error(Nil)
          }
        })

      let all_tests: List(TestCase) =
        all_suites
        |> list.flat_map(fn(pair) { { pair.1 }.tests })

      let total_count = list.length(all_tests)

      // Count by validation type
      let validations =
        all_tests |> list.group(fn(tc: TestCase) { tc.validation })

      io.println("By Validation Type:")
      validations
      |> dict.to_list
      |> list.each(fn(pair) {
        let #(validation, tests) = pair
        io.println(
          "  "
          <> util.pad_right(validation, 20)
          <> " "
          <> int.to_string(list.length(tests)),
        )
      })
      io.println("")

      // Count by function
      let function_counts =
        count_tags(all_tests, fn(tc: TestCase) { tc.functions })
      io.println("By Function:")
      function_counts
      |> list.each(fn(pair) {
        let #(func, count) = pair
        io.println(
          "  " <> util.pad_right(func, 20) <> " " <> int.to_string(count),
        )
      })
      io.println("")

      // Count compatible/incompatible
      let compatible =
        all_tests
        |> list.filter(fn(tc) { test_filter.is_compatible(config, tc) })
      let compatible_count = list.length(compatible)
      let skipped_count = total_count - compatible_count

      io.println("Compatibility (with current config):")
      io.println(
        "  "
        <> util.pad_right("Compatible", 20)
        <> " "
        <> int.to_string(compatible_count),
      )
      io.println(
        "  "
        <> util.pad_right("Would skip", 20)
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
  case test_loader.load_test_file(file) {
    Ok(suite) -> list.length(suite.tests)
    Error(_) -> 0
  }
}

fn get_file_size(path: String) -> String {
  case simplifile.file_info(path) {
    Ok(info) -> util.format_size(info.size)
    Error(_) -> "?"
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
  |> list.map(fn(pair) { #(pair.0, list.length(pair.1)) })
  |> list.sort(fn(a, b) { string.compare(a.0, b.0) })
}
