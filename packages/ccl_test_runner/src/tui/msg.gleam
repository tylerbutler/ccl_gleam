/// Message types for the CCL test viewer TUI
import test_runner/types.{type TestSuite}

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

  // Data loading
  SuiteLoaded(path: String, result: Result(TestSuite, String))

  // Navigation shortcuts
  NextTest
  PrevTest
}
