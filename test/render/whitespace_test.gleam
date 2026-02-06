import gleeunit/should
import render/whitespace.{CarriageReturn, Newline, Space, Tab, Text}

// --- visualize ---

pub fn visualize_plain_text_test() {
  whitespace.visualize("hello")
  |> should.equal([Text("hello")])
}

pub fn visualize_single_space_test() {
  whitespace.visualize(" ")
  |> should.equal([Space])
}

pub fn visualize_single_tab_test() {
  whitespace.visualize("\t")
  |> should.equal([Tab])
}

pub fn visualize_single_newline_test() {
  whitespace.visualize("\n")
  |> should.equal([Newline])
}

pub fn visualize_single_carriage_return_test() {
  whitespace.visualize("\r")
  |> should.equal([CarriageReturn])
}

pub fn visualize_mixed_content_test() {
  whitespace.visualize("a b")
  |> should.equal([Text("a"), Space, Text("b")])
}

pub fn visualize_consecutive_text_merges_test() {
  whitespace.visualize("abc")
  |> should.equal([Text("abc")])
}

pub fn visualize_empty_string_test() {
  whitespace.visualize("")
  |> should.equal([])
}

pub fn visualize_multiple_whitespace_types_test() {
  whitespace.visualize("a\t\nb")
  |> should.equal([Text("a"), Tab, Newline, Text("b")])
}

pub fn visualize_crlf_splits_into_cr_lf_test() {
  whitespace.visualize("\r\n")
  |> should.equal([CarriageReturn, Newline])
}

pub fn visualize_text_with_crlf_test() {
  whitespace.visualize("a\r\nb")
  |> should.equal([Text("a"), CarriageReturn, Newline, Text("b")])
}

pub fn visualize_multiple_crlf_test() {
  whitespace.visualize("\r\n\r\n")
  |> should.equal([CarriageReturn, Newline, CarriageReturn, Newline])
}

pub fn visualize_leading_trailing_spaces_test() {
  whitespace.visualize(" hi ")
  |> should.equal([Space, Text("hi"), Space])
}

// --- glyph ---

pub fn glyph_text_test() {
  whitespace.glyph(Text("hello"))
  |> should.equal("hello")
}

pub fn glyph_space_test() {
  whitespace.glyph(Space)
  |> should.equal("·")
}

pub fn glyph_tab_test() {
  whitespace.glyph(Tab)
  |> should.equal("→")
}

pub fn glyph_newline_test() {
  whitespace.glyph(Newline)
  |> should.equal("↵")
}

pub fn glyph_carriage_return_test() {
  whitespace.glyph(CarriageReturn)
  |> should.equal("␍")
}

// --- is_whitespace ---

pub fn is_whitespace_text_test() {
  whitespace.is_whitespace(Text("hello"))
  |> should.equal(False)
}

pub fn is_whitespace_space_test() {
  whitespace.is_whitespace(Space)
  |> should.equal(True)
}

pub fn is_whitespace_tab_test() {
  whitespace.is_whitespace(Tab)
  |> should.equal(True)
}

pub fn is_whitespace_newline_test() {
  whitespace.is_whitespace(Newline)
  |> should.equal(True)
}

pub fn is_whitespace_carriage_return_test() {
  whitespace.is_whitespace(CarriageReturn)
  |> should.equal(True)
}

// --- to_display_string ---

pub fn to_display_string_plain_test() {
  whitespace.visualize("hello")
  |> whitespace.to_display_string
  |> should.equal("hello")
}

pub fn to_display_string_with_spaces_test() {
  whitespace.visualize("a b")
  |> whitespace.to_display_string
  |> should.equal("a·b")
}

pub fn to_display_string_with_tabs_test() {
  whitespace.visualize("a\tb")
  |> whitespace.to_display_string
  |> should.equal("a→b")
}

pub fn to_display_string_with_newlines_test() {
  whitespace.visualize("a\nb")
  |> whitespace.to_display_string
  |> should.equal("a↵b")
}

pub fn to_display_string_all_whitespace_types_test() {
  whitespace.visualize(" \t\n\r")
  |> whitespace.to_display_string
  |> should.equal("·→↵␍")
}

pub fn to_display_string_crlf_test() {
  whitespace.visualize("a\r\nb")
  |> whitespace.to_display_string
  |> should.equal("a␍↵b")
}

// --- to_original_string ---

pub fn to_original_string_roundtrip_test() {
  let input = "hello world\tfoo\nbar\r\n"
  whitespace.visualize(input)
  |> whitespace.to_original_string
  |> should.equal(input)
}

pub fn to_original_string_empty_test() {
  whitespace.visualize("")
  |> whitespace.to_original_string
  |> should.equal("")
}

pub fn to_original_string_plain_text_test() {
  whitespace.visualize("abc")
  |> whitespace.to_original_string
  |> should.equal("abc")
}
