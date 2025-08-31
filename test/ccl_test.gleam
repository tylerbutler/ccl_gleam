//// test/ccl_test.gleam
import gleeunit
import gleeunit/should
import ccl

pub fn main() {
  gleeunit.main()
}

// --- BASIC PAIRS ---
pub fn basic_pairs_test() {
  let input = "name = Alice\nage = 42\n"
  let expected = [
    ccl.Entry("name", "Alice"),
    ccl.Entry("age", "42"),
  ]
  ccl.parse(input)
  |> should.equal(Ok(expected))
}

// --- EQUALS IN VALUES ---
pub fn equals_in_values_test() {
  let input = "msg = k=v pairs live happily here\nmore = a=b=c=d\n"
  let expected = [
    ccl.Entry("msg", "k=v pairs live happily here"),
    ccl.Entry("more", "a=b=c=d"),
  ]
  ccl.parse(input)
  |> should.equal(Ok(expected))
}

// --- TRIMMING RULES ---
pub fn trimming_rules_test() {
  let input = "  spaces around key   =    value with leading spaces removed and trailing tabs kept? \t\t\n"
  let expected = [
    ccl.Entry("spaces around key", "value with leading spaces removed and trailing tabs kept?"),
  ]
  ccl.parse(input)
  |> should.equal(Ok(expected))
}

// --- MULTILINE VALUES ---
pub fn multiline_values_test() {
  let input =
    "description = First\n  Second line\n  Third line\n" <>
    "done = yes\n"
  let expected = [
    ccl.Entry("description", "First\nSecond line\nThird line"),
    ccl.Entry("done", "yes"),
  ]
  ccl.parse(input)
  |> should.equal(Ok(expected))
}

// --- BLANK LINES IN VALUES ---
pub fn blank_lines_in_values_test() {
  let input = "body = Line one\n\n  Line three after a blank line\n"
  let expected = [
    ccl.Entry("body", "Line one\n\nLine three after a blank line"),
  ]
  ccl.parse(input)
  |> should.equal(Ok(expected))
}

// --- COMMENT EXTENSION ---
pub fn comment_extension_test() {
  let input =
    "/= This is an environment section\n" <>
    "port = 8080\n" <>
    "serve = index.html\n" <>
    "/= Database section\n" <>
    "mode = in-memory\n" <>
    "connections = 16\n"
  let expected = [
    ccl.Entry("/", "This is an environment section"),
    ccl.Entry("port", "8080"),
    ccl.Entry("serve", "index.html"),
    ccl.Entry("/", "Database section"),
    ccl.Entry("mode", "in-memory"),
    ccl.Entry("connections", "16"),
  ]
  ccl.parse(input)
  |> should.equal(Ok(expected))
}

// --- COMPOSITION STABILITY ---
pub fn composition_stability_test() {
  let a = "a = 1\nb = 2\n"
  let b = "b = 20\nc = 3\n"
  let concat_ab = a <> b
  let concat_ba = b <> a

  let expected_ab = [
    ccl.Entry("a", "1"),
    ccl.Entry("b", "2"),
    ccl.Entry("b", "20"),
    ccl.Entry("c", "3"),
  ]
  let expected_ba = [
    ccl.Entry("b", "20"),
    ccl.Entry("c", "3"),
    ccl.Entry("a", "1"),
    ccl.Entry("b", "2"),
  ]

  ccl.parse(concat_ab) |> should.equal(Ok(expected_ab))
  ccl.parse(concat_ba) |> should.equal(Ok(expected_ba))
}

// --- EDGE CASES ---

// Keys with tabs
pub fn key_with_tabs_test() {
  let input = "\tkey\t=\tvalue\n"
  let expected = [
    ccl.Entry("key", "value"),
  ]
  ccl.parse(input)
  |> should.equal(Ok(expected))
}

// Lines starting with "=" are continuations
pub fn equals_start_continuation_test() {
  let input = "a = first\n= not a key\n"
  let expected = [
    ccl.Entry("a", "first\n= not a key"),
  ]
  ccl.parse(input)
  |> should.equal(Ok(expected))
}

// Value that is only whitespace
pub fn whitespace_only_value_test() {
  let input = "onlyspaces =     \n"
  let expected = [
    ccl.Entry("onlyspaces", ""),
  ]
  ccl.parse(input)
  |> should.equal(Ok(expected))
}

// Unicode grapheme handling
pub fn unicode_graphemes_test() {
  let input = "emoji = 😀😃😄\n"
  let expected = [
    ccl.Entry("emoji", "😀😃😄"),
  ]
  ccl.parse(input)
  |> should.equal(Ok(expected))
}
