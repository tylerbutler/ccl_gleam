/// CCL Test Runner CLI
///
/// A CLI application for running and viewing CCL test suites.
///
/// Commands:
///   run <dir>    Run tests against an implementation
///   list <dir>   List test files with counts
///   stats <dir>  Show test suite statistics
///   view <dir>   Launch interactive TUI viewer
import argv
import birch
import birch/handler/console
import birch/level
import cli/commands.{
  type CommandResult, Failure, Success, build_config, merge_with_impl_config,
}
import mock_implementation
import cli/flags
import glint
import tui/app

pub fn main() {
  birch.configure([
    birch.config_level(level.Info),
    birch.config_handlers([console.fancy_handler()]),
  ])

  glint.new()
  |> glint.with_name("ccl_test_runner")
  |> glint.pretty_help(glint.default_pretty_help())
  |> glint.global_help(
    "CCL Test Runner - Run and explore CCL test suites.

A CLI tool for validating CCL implementations against the official test suite.",
  )
  |> glint.add(at: ["run"], do: commands.run_command())
  |> glint.add(at: ["list"], do: commands.list_command())
  |> glint.add(at: ["stats"], do: commands.stats_command())
  |> glint.add(at: ["view"], do: view_command())
  |> glint.run_and_handle(argv.load().arguments, handle_result)
}

/// View command - launches interactive TUI viewer
fn view_command() -> glint.Command(CommandResult) {
  use <- glint.command_help(
    "Launch interactive TUI viewer for exploring test cases.

Navigate through test files, view test details, and filter tests interactively.

Keys:
  j/k, Up/Down    Navigate list
  Enter, l        Select/Open
  Esc, h          Go back
  n/p             Next/Previous test (in detail view)
  q               Quit",
  )
  use test_dir <- glint.named_arg("directory")
  use functions <- glint.flag(flags.functions_flag())
  use behaviors <- glint.flag(flags.behaviors_flag())
  use features <- glint.flag(flags.features_flag())
  use variants <- glint.flag(flags.variants_flag())
  use named, _args, cmd_flags <- glint.command()

  let dir = test_dir(named)
  let assert Ok(funcs) = functions(cmd_flags)
  let assert Ok(behavs) = behaviors(cmd_flags)
  let assert Ok(feats) = features(cmd_flags)
  let assert Ok(vars) = variants(cmd_flags)

  let cli_config = build_config(funcs, behavs, feats, vars)
  let config = merge_with_impl_config(cli_config, mock_implementation.config())

  case app.start(dir, config) {
    Ok(_) -> Success
    Error(e) -> Failure("TUI error: " <> e)
  }
}

fn handle_result(result: CommandResult) -> Nil {
  case result {
    Success -> Nil
    Failure(msg) -> {
      birch.error_m("Command failed", [#("error", msg)])
      halt(1)
    }
  }
}

@external(erlang, "erlang", "halt")
fn halt(code: Int) -> Nil
