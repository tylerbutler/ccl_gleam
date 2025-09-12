import ccl_core
import gleam/io
import gleeunit
import gleeunit/should

pub fn main() {
  print_test_overview()
  gleeunit.main()
}

fn print_test_overview() {
  io.println("=== CCL Test Suite Overview ===")
  io.println("Simple CCL test runner focused on feature-based filtering")
  io.println("")
}

// Test for error handling - ensures ParseError type is properly used
pub fn parse_error_type_test() {
  // This test verifies error handling for invalid CCL syntax
  case ccl_core.parse("invalid\nno equals") {
    Error(_) -> should.equal(True, True)
    // Just check that it's an error
    Ok(_) -> should.fail()
  }
}

// Basic CCL parsing test
pub fn basic_ccl_parse_test() {
  case ccl_core.parse("key = value") {
    Ok(entries) -> should.equal(1, length(entries))
    Error(_) -> should.fail()
  }
}

// Helper function to avoid importing list
fn length(list) {
  case list {
    [] -> 0
    [_, ..rest] -> 1 + length(rest)
  }
}
