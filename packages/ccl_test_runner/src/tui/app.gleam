/// Shore TUI application setup for CCL test viewer
import filepath
import gleam/erlang/process
import gleam/list
import shore
import shore/key
import test_runner/loader
import test_runner/types.{type ImplementationConfig}
import tui/model.{type FileInfo, FileInfo, Model}
import tui/update
import tui/view

/// Start the TUI application
pub fn start(
  test_dir: String,
  config: ImplementationConfig,
) -> Result(Nil, String) {
  // Create exit subject
  let exit = process.new_subject()

  // Load files synchronously before starting TUI
  let files = load_files(test_dir)

  case files {
    [] -> Error("No test files found in directory: " <> test_dir)
    _ -> {
      // Initialize model with files
      let initial_model =
        model.init(test_dir, config)
        |> fn(m) { Model(..m, files: files) }

      // Start shore app
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
          // Block until exit
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

/// Custom keybindings for the app
fn custom_keybinds() {
  shore.keybinds(
    exit: key.Char("q"),
    submit: key.Enter,
    focus_clear: key.Esc,
    focus_next: key.Tab,
    focus_prev: key.BackTab,
  )
}

/// Load file information from directory
fn load_files(test_dir: String) -> List(FileInfo) {
  case loader.list_test_files(test_dir) {
    Ok(files) ->
      files
      |> list.map(fn(path) {
        FileInfo(
          path: path,
          name: filepath.base_name(path),
          test_count: loader.test_count(path),
          size: loader.file_size(path),
        )
      })
    Error(_) -> []
  }
}
