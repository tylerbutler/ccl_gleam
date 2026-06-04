import startest
import startest/expect

import ccl/hierarchy
import ccl/parser
import ccl/types.{CclObject, CclString, Entry}
import gleam/dict

pub fn main() {
  startest.run(startest.default_config())
}

pub fn parse_basic_key_value_test() {
  let input = "key = value"
  let result = parser.parse(input)
  result
  |> expect.to_equal(Ok([Entry(key: "key", value: "value")]))
}

pub fn parse_empty_input_test() {
  let result = parser.parse("")
  result
  |> expect.to_equal(Ok([]))
}

/// Issue #3: Values containing `=` (like semver ranges `>=18`) should not be
/// recursively parsed as nested key-value pairs.
pub fn hierarchy_value_with_equals_not_reparsed_test() {
  let input = "peer_dependencies =\n  react = >=18"
  let assert Ok(entries) = parser.parse(input)
  let result = hierarchy.build_hierarchy(entries)

  // react should be CclString(">=18"), NOT a nested object
  let assert Ok(peer_deps) = dict.get(result, "peer_dependencies")
  let assert CclObject(inner) = peer_deps
  let assert Ok(react_val) = dict.get(inner, "react")
  react_val
  |> expect.to_equal(CclString(">=18"))
}

/// Verify single-line values with `=` are always terminal strings.
pub fn hierarchy_single_line_equals_is_string_test() {
  let input = "url = https://example.com?foo=bar"
  let assert Ok(entries) = parser.parse(input)
  let result = hierarchy.build_hierarchy(entries)

  let assert Ok(url_val) = dict.get(result, "url")
  url_val
  |> expect.to_equal(CclString("https://example.com?foo=bar"))
}

/// Issue #3: Multiple nested values with `=` in content should all remain strings.
pub fn hierarchy_multiple_semver_ranges_test() {
  let input = "deps =\n  react = >=18\n  node = >=16.0.0\n  typescript = ~=5.0"
  let assert Ok(entries) = parser.parse(input)
  let result = hierarchy.build_hierarchy(entries)

  let assert Ok(deps) = dict.get(result, "deps")
  let assert CclObject(inner) = deps
  dict.get(inner, "react") |> expect.to_equal(Ok(CclString(">=18")))
  dict.get(inner, "node") |> expect.to_equal(Ok(CclString(">=16.0.0")))
  dict.get(inner, "typescript") |> expect.to_equal(Ok(CclString("~=5.0")))
}

/// Issue #12: an unindented no-`=` line following an *empty-key* entry folds
/// into the KEY of the next `key = value` entry (joined with `\n`), rather than
/// being emitted as a standalone entry or being dropped.
pub fn multiline_keys_fold_into_next_key_test() {
  let opts =
    types.ParseOptions(
      ..types.default_parse_options(),
      delimiter_strategy: types.DelimiterFirstEquals,
    )
  let input = "== Section Header =\nprefix for next key\nkey = value"
  parser.parse_with(input, opts)
  |> expect.to_equal(
    Ok([
      Entry(key: "", value: "= Section Header ="),
      Entry(key: "prefix for next key\nkey", value: "value"),
    ]),
  )
}

/// Issue #12: an unindented no-`=` line following a *named-key* entry does NOT
/// fold forward; it becomes its own entry with an empty value (and is not
/// dropped). Mirrors the `list_multiline_values` fixture.
pub fn multiline_keys_non_merging_line_is_standalone_entry_test() {
  let opts =
    types.ParseOptions(
      ..types.default_parse_options(),
      delimiter_strategy: types.DelimiterFirstEquals,
    )
  let input =
    "descriptions = First line\nsecond line\ndescriptions = Another item\ndescriptions = Third item"
  parser.parse_with(input, opts)
  |> expect.to_equal(
    Ok([
      Entry(key: "descriptions", value: "First line"),
      Entry(key: "second line", value: ""),
      Entry(key: "descriptions", value: "Another item"),
      Entry(key: "descriptions", value: "Third item"),
    ]),
  )
}

/// Single-line value containing ` = ` is still a terminal string in hierarchy.
pub fn hierarchy_value_with_spaced_equals_test() {
  let input = "config =\n  formula = a = b + c"
  let assert Ok(entries) = parser.parse(input)
  let result = hierarchy.build_hierarchy(entries)

  let assert Ok(config) = dict.get(result, "config")
  let assert CclObject(inner) = config
  let assert Ok(formula_val) = dict.get(inner, "formula")
  // "a = b + c" is single-line, so resolve_value treats it as terminal
  formula_val
  |> expect.to_equal(CclString("a = b + c"))
}
