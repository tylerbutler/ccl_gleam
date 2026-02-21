/// Shore TUI application setup for CCL test viewer.
import birch
import birch/handler
import gleam/erlang/process
import gleam/list
import shore
import shore/key
import simplifile
import test_loader
import test_types.{type ImplementationConfig}
import tui/model.{type FileInfo, FileInfo, Model}
import tui/update
import tui/view
import util

/// Start the TUI application.
pub fn start(
  test_dir: String,
  config: ImplementationConfig,
) -> Result(Nil, String) {
  birch.configure([birch.config_handlers([handler.null()])])

  let exit = process.new_subject()
  let files = load_files(test_dir)

  case files {
    [] -> Error("No test files found in directory: " <> test_dir)
    _ -> {
      let initial_model =
        model.init(test_dir, config)
        |> fn(m) { Model(..m, files: files) }

      let start_result =
        shore.spec(
          init: fn() { #(initial_model, []) },
          view: view.render,
          update: update.update,
          exit: exit,
          keybinds: custom_keybinds(),
          redraw: shore.on_update(),
        )
        |> shore.start

      case start_result {
        Ok(_actor) -> {
          process.receive_forever(exit)
          Ok(Nil)
        }
        Error(_) ->
          Error(
            "Failed to start TUI. Ensure you're running in an interactive terminal with OTP 28+.",
          )
      }
    }
  }
}

fn custom_keybinds() {
  shore.keybinds(
    exit: key.Char("q"),
    submit: key.Enter,
    focus_clear: key.Esc,
    focus_next: key.Tab,
    focus_prev: key.BackTab,
  )
}

fn load_files(test_dir: String) -> List(FileInfo) {
  case test_loader.list_test_files(test_dir) {
    Ok(files) ->
      files
      |> list.map(fn(path) {
        let name = util.get_filename(path)
        let count = get_test_count(path)
        let size = get_file_size(path)
        FileInfo(path: path, name: name, test_count: count, size: size)
      })
    Error(_) -> []
  }
}

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
