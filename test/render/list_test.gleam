import gleam/string
import gleeunit/should
import render/list

// --- to_string ---

pub fn to_string_single_item_test() {
  list.to_string(["apple"])
  |> should.equal("= apple")
}

pub fn to_string_multiple_items_test() {
  list.to_string(["apple", "banana", "cherry"])
  |> should.equal("= apple\n= banana\n= cherry")
}

pub fn to_string_empty_list_test() {
  list.to_string([])
  |> should.equal("")
}

pub fn to_string_item_with_spaces_test() {
  list.to_string(["hello world"])
  |> should.equal("= hello·world")
}

pub fn to_string_item_with_tab_test() {
  list.to_string(["a\tb"])
  |> should.equal("= a→b")
}

pub fn to_string_no_trailing_newline_test() {
  let result = list.to_string(["a", "b"])
  // Should not end with newline
  should.be_false(string.ends_with(result, "\n"))
}
