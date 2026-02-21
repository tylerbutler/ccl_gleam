import gleam/string
import gleam_community/ansi
import gleeunit/should
import render/error

pub fn to_string_test() {
  error.to_string()
  |> should.equal("[ERROR]")
}

pub fn to_ansi_contains_error_text_test() {
  let result = error.to_ansi()
  // ANSI output should contain [ERROR] text when stripped
  ansi.strip(result)
  |> should.equal("[ERROR]")
}

pub fn to_ansi_has_red_color_test() {
  let result = error.to_ansi()
  // Should contain ANSI red color code (31)
  let assert True = string.contains(result, "\u{001b}[31m")
}
