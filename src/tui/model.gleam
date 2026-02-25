/// Model types for the CCL test viewer TUI
import gleam/dict.{type Dict}
import test_runner/types.{type ImplementationConfig, type TestSuite}

/// Current view state
pub type View {
  FileListView
  TestListView(file_path: String)
  TestDetailView(file_path: String, test_index: Int)
}

/// File information for display
pub type FileInfo {
  FileInfo(path: String, name: String, test_count: Int, size: String)
}

/// Filter state for test filtering
pub type FilterState {
  FilterState(text: String, active: Bool)
}

/// Main application model
pub type Model {
  Model(
    view: View,
    test_dir: String,
    files: List(FileInfo),
    loaded_suites: Dict(String, TestSuite),
    selected_index: Int,
    scroll_offset: Int,
    filter: FilterState,
    config: ImplementationConfig,
    terminal_height: Int,
    message: String,
  )
}

/// Create an initial model
pub fn init(test_dir: String, config: ImplementationConfig) -> Model {
  Model(
    view: FileListView,
    test_dir: test_dir,
    files: [],
    loaded_suites: dict.new(),
    selected_index: 0,
    scroll_offset: 0,
    filter: FilterState(text: "", active: False),
    config: config,
    terminal_height: 24,
    message: "",
  )
}

/// Create an empty filter state
pub fn empty_filter() -> FilterState {
  FilterState(text: "", active: False)
}

/// Get the visible window bounds for scrolling
pub fn visible_bounds(model: Model, item_count: Int) -> #(Int, Int) {
  // Reserve space for header (3 lines) and footer (2 lines)
  let visible_lines = model.terminal_height - 5
  let start = model.scroll_offset
  let end = int_min(start + visible_lines, item_count)
  #(start, end)
}

fn int_min(a: Int, b: Int) -> Int {
  case a < b {
    True -> a
    False -> b
  }
}

/// Adjust scroll to keep selected item visible
pub fn adjust_scroll(model: Model, _item_count: Int) -> Model {
  let visible_lines = model.terminal_height - 5
  let selected = model.selected_index

  let new_offset = case selected < model.scroll_offset {
    True -> selected
    False -> {
      case selected >= model.scroll_offset + visible_lines {
        True -> selected - visible_lines + 1
        False -> model.scroll_offset
      }
    }
  }

  Model(..model, scroll_offset: int_max(0, new_offset))
}

fn int_max(a: Int, b: Int) -> Int {
  case a > b {
    True -> a
    False -> b
  }
}
