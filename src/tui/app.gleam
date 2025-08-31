/// Shore TUI application setup for CCL test viewer
import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import shore
import shore/key
import simplifile
import test_loader
import test_types.{type ImplementationConfig}
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
  case test_loader.list_test_files(test_dir) {
    Ok(files) ->
      files
      |> list.map(fn(path) {
        let name = get_filename(path)
        let count = get_test_count(path)
        let size = get_file_size(path)
        FileInfo(path: path, name: name, test_count: count, size: size)
      })
    Error(_) -> []
  }
}

fn get_filename(path: String) -> String {
  path
  |> string.split("/")
  |> list.last
  |> result.unwrap(path)
}

fn get_test_count(file: String) -> Int {
  case test_loader.load_test_file(file) {
    Ok(suite) -> list.length(suite.tests)
    Error(_) -> 0
  }
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
