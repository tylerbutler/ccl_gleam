import gleeunit/should
import render/value

// --- to_string ---

pub fn to_string_plain_text_test() {
  value.to_string("hello")
  |> should.equal("hello")
}

pub fn to_string_with_spaces_test() {
  value.to_string("hello world")
  |> should.equal("hello·world")
}

pub fn to_string_with_tab_test() {
  value.to_string("a\tb")
  |> should.equal("a→b")
}

pub fn to_string_with_newline_test() {
  value.to_string("a\nb")
  |> should.equal("a↵b")
}

pub fn to_string_empty_test() {
  value.to_string("")
  |> should.equal("")
}

pub fn to_string_trailing_space_test() {
  value.to_string("hello ")
  |> should.equal("hello·")
}

pub fn to_string_leading_space_test() {
  value.to_string(" hello")
  |> should.equal("·hello")
}
