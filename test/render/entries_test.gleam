import gleam/string
import gleeunit/should
import render/entries.{CloseParen, Comma, Key, Newline, OpenParen, Value}
import test_types.{TestEntry}

// --- to_parts ---

pub fn to_parts_single_entry_test() {
  let input = [TestEntry(key: "name", value: "alice")]
  entries.to_parts(input)
  |> should.equal([
    OpenParen,
    Key("name"),
    Comma,
    Value("alice"),
    CloseParen,
    Newline,
  ])
}

pub fn to_parts_multiple_entries_test() {
  let input = [
    TestEntry(key: "a", value: "1"),
    TestEntry(key: "b", value: "2"),
  ]
  entries.to_parts(input)
  |> should.equal([
    OpenParen,
    Key("a"),
    Comma,
    Value("1"),
    CloseParen,
    Newline,
    OpenParen,
    Key("b"),
    Comma,
    Value("2"),
    CloseParen,
    Newline,
  ])
}

pub fn to_parts_empty_test() {
  entries.to_parts([])
  |> should.equal([])
}

// --- to_string ---

pub fn to_string_single_entry_test() {
  let input = [TestEntry(key: "name", value: "alice")]
  entries.to_string(input)
  |> should.equal("(name, alice)")
}

pub fn to_string_multiple_entries_test() {
  let input = [
    TestEntry(key: "a", value: "1"),
    TestEntry(key: "b", value: "2"),
  ]
  entries.to_string(input)
  |> should.equal("(a, 1)\n(b, 2)")
}

pub fn to_string_no_trailing_newline_test() {
  let input = [TestEntry(key: "x", value: "y")]
  let result = entries.to_string(input)
  // The string should NOT end with a newline
  should.be_false(string.ends_with(result, "\n"))
}

pub fn to_string_empty_test() {
  entries.to_string([])
  |> should.equal("")
}

pub fn to_string_empty_key_value_test() {
  let input = [TestEntry(key: "", value: "")]
  entries.to_string(input)
  |> should.equal("(, )")
}

// --- tuples_to_string ---

pub fn tuples_to_string_single_test() {
  entries.tuples_to_string([#("name", "alice")])
  |> should.equal("(name, alice)")
}

pub fn tuples_to_string_multiple_test() {
  entries.tuples_to_string([#("a", "1"), #("b", "2")])
  |> should.equal("(a, 1)\n(b, 2)")
}

pub fn tuples_to_string_no_trailing_newline_test() {
  let result = entries.tuples_to_string([#("x", "y")])
  should.be_false(string.ends_with(result, "\n"))
}

pub fn tuples_to_string_empty_test() {
  entries.tuples_to_string([])
  |> should.equal("")
}
