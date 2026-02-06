import gleam/string
import gleeunit/should
import render/error

pub fn to_string_test() {
  error.to_string()
  |> should.equal("[ERROR]")
}

pub fn to_ansi_contains_error_text_test() {
  let result = error.to_ansi()
  // ANSI output should contain [ERROR] text
  let assert True = string.contains(result, "[ERROR]")
}

pub fn to_ansi_has_red_color_test() {
  let result = error.to_ansi()
  // Should contain ANSI red color code (31)
  let assert True = string.contains(result, "\u{001b}[31m")
}

pub fn to_ansi_has_reset_test() {
  let result = error.to_ansi()
  // Should contain ANSI reset
  let assert True = string.contains(result, "\u{001b}[0m")
}
