import gleam/list
import gleam/string
import gleeunit/should
import render/ccl_input.{Key, Separator, Value, Whitespace}
import render/whitespace.{Space}

// --- to_parts ---

pub fn to_parts_simple_entry_test() {
  let result = ccl_input.to_parts("name=alice")
  result
  |> should.equal([[Key("name"), Separator, Value("alice")]])
}

pub fn to_parts_entry_with_spaces_test() {
  let result = ccl_input.to_parts("name = alice")
  result
  |> should.equal([
    [
      Key("name"),
      Whitespace(Space),
      Separator,
      Whitespace(Space),
      Value("alice"),
    ],
  ])
}

pub fn to_parts_multiline_test() {
  let result = ccl_input.to_parts("a=1\nb=2")
  // Should produce two lines of parts
  let assert 2 = list.length(result)
}

pub fn to_parts_no_separator_test() {
  let result = ccl_input.to_parts("just text")
  result
  |> should.equal([
    [Value("just"), Whitespace(Space), Value("text")],
  ])
}

// --- to_string ---

pub fn to_string_simple_test() {
  ccl_input.to_string("name=alice")
  |> should.equal("name=alice")
}

pub fn to_string_spaces_visualized_test() {
  ccl_input.to_string("name = alice")
  |> should.equal("name·=·alice")
}

pub fn to_string_multiline_has_newline_glyphs_test() {
  let result = ccl_input.to_string("a=1\nb=2")
  // Lines should be joined with ↵ glyph
  let assert True = string.contains(result, "↵")
}

pub fn to_string_tab_visualized_test() {
  ccl_input.to_string("name\t=\talice")
  |> should.equal("name→=→alice")
}

pub fn to_string_no_trailing_newline_test() {
  let result = ccl_input.to_string("a=1")
  should.be_false(string.ends_with(result, "\n"))
}
