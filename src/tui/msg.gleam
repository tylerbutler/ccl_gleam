/// Message types for the CCL test viewer TUI
import test_types.{type TestSuite}

/// Messages for TUI state updates
pub type Msg {
  // Navigation
  NavigateUp
  NavigateDown
  PageUp
  PageDown
  GoToTop
  GoToBottom
  Select
  Back

  // View transitions
  GoToFileList
  GoToTestList(file_path: String)
  GoToTestDetail(file_path: String, test_index: Int)

  // Filter
  StartFilter
  UpdateFilter(text: String)
  ClearFilter
  CancelFilter

  // Data loading
  FilesLoaded(files: List(#(String, Int, String)))
  SuiteLoaded(path: String, result: Result(TestSuite, String))

  // Navigation shortcuts
  NextTest
  PrevTest

  // App control
  Quit
  Noop
}
