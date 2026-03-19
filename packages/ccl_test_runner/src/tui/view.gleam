/// Main view renderer that dispatches to specific view modules
import shore
import shore/key
import shore/ui
import tui/model.{type Model, FileListView, TestDetailView, TestListView}
import tui/msg.{
  type Msg, Back, GoToBottom, GoToTop, NavigateDown, NavigateUp, NextTest,
  PageDown, PageUp, PrevTest, Quit, Select,
}
import tui/views/file_list
import tui/views/test_detail
import tui/views/test_list

/// Render the current view based on model state
pub fn render(model: Model) -> shore.Node(Msg) {
  ui.col([
    // Main content based on current view
    case model.view {
      FileListView -> file_list.render(model)
      TestListView(path) -> test_list.render(model, path)
      TestDetailView(path, index) -> test_detail.render(model, path, index)
    },
    // Global keybindings
    global_keybinds(),
  ])
}

/// Global keybindings available in all views
fn global_keybinds() -> shore.Node(Msg) {
  ui.col([
    // Navigation keys (vim-style)
    ui.keybind(key.Char("j"), NavigateDown),
    ui.keybind(key.Down, NavigateDown),
    ui.keybind(key.Char("k"), NavigateUp),
    ui.keybind(key.Up, NavigateUp),

    // Page navigation
    ui.keybind(key.Ctrl("D"), PageDown),
    ui.keybind(key.PageDown, PageDown),
    ui.keybind(key.Ctrl("U"), PageUp),
    ui.keybind(key.PageUp, PageUp),

    // Jump to top/bottom
    ui.keybind(key.Char("g"), GoToTop),
    ui.keybind(key.Char("G"), GoToBottom),
    ui.keybind(key.Home, GoToTop),
    ui.keybind(key.End, GoToBottom),

    // Selection
    ui.keybind(key.Enter, Select),
    ui.keybind(key.Char("l"), Select),
    ui.keybind(key.Right, Select),

    // Back navigation
    ui.keybind(key.Esc, Back),
    ui.keybind(key.Char("h"), Back),
    ui.keybind(key.Left, Back),

    // Test detail navigation
    ui.keybind(key.Char("n"), NextTest),
    ui.keybind(key.Char("p"), PrevTest),

    // Quit (handled by shore keybinds, but also add explicit binding)
    ui.keybind(key.Char("q"), Quit),
  ])
}
