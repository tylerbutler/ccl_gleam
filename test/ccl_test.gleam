import startest
import startest/expect

import ccl/hierarchy
import ccl/model
import ccl/model/nested_parser
import ccl/parser
import ccl/types.{
  BuildOptions, CclList, CclObject, CclString, Entry, LexicographicOrder, Model,
  default_parse_options,
}
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

pub fn model_nested_parser_accepts_lf_multiline_value_test() {
  let result = nested_parser.parse("\n  child = value", default_parse_options())

  result
  |> expect.to_equal(Ok([Entry(key: "child", value: "value")]))
}

pub fn model_nested_parser_rejects_single_line_value_test() {
  let result = nested_parser.parse("plain value", default_parse_options())

  result
  |> expect.to_equal(Error(Nil))
}

pub fn model_nested_parser_rejects_multiline_value_without_equals_test() {
  let result =
    nested_parser.parse("\n  no delimiter here", default_parse_options())

  result
  |> expect.to_equal(Error(Nil))
}

pub fn parser_is_nested_value_true_for_multiline_with_equals_test() {
  parser.is_nested_value("\n  child = value")
  |> expect.to_equal(True)
}

pub fn parser_is_nested_value_false_for_multiline_without_equals_test() {
  parser.is_nested_value("\n  no delimiter here")
  |> expect.to_equal(False)
}

pub fn parser_is_nested_value_false_for_single_line_with_equals_test() {
  parser.is_nested_value("a = b")
  |> expect.to_equal(False)
}

pub fn parser_is_nested_value_false_for_empty_string_test() {
  parser.is_nested_value("")
  |> expect.to_equal(False)
}

pub fn parse_empty_input_test() {
  let result = parser.parse("")
  result
  |> expect.to_equal(Ok([]))
}

/// Issue #11 / ccl-test-data v1.0.0 `delimiter_spaced_empty_value`:
/// `delimiter_prefer_spaced` (the default strategy) splits on the first `=`
/// preceded by a space — a trailing space is NOT required, so an empty
/// value at end of line still counts as a spaced delimiter.
/// `== Section Header =` has its only space-preceded `=` at the end, so it
/// splits there: key `== Section Header`, empty value.
pub fn parse_prefer_spaced_falls_back_to_first_equals_test() {
  let result = parser.parse("== Section Header =")
  result
  |> expect.to_equal(Ok([Entry(key: "== Section Header", value: "")]))
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

pub fn hierarchy_reference_order_drops_empty_duplicate_values_test() {
  let entries = [
    Entry(key: "items", value: "spaced"),
    Entry(key: "items", value: "normal"),
    Entry(key: "items", value: ""),
    Entry(key: "items", value: ""),
  ]
  let result =
    hierarchy.build_hierarchy_with(
      entries,
      BuildOptions(array_order: LexicographicOrder),
      default_parse_options(),
    )

  // Lexicographic order mirrors the reference model, where list items are
  // map keys — empty items vanish (see list_with_whitespace_reference in
  // the conformance data). Insertion order keeps them.
  dict.get(result, "items")
  |> expect.to_equal(Ok(CclList([CclString("normal"), CclString("spaced")])))
}

pub fn build_model_terminal_value_becomes_leaf_key_test() {
  let result = model.build_model([Entry(key: "name", value: "Alice")])
  let empty = Model(dict.new())

  result
  |> expect.to_equal(
    Model(
      dict.from_list([
        #("name", Model(dict.from_list([#("Alice", empty)]))),
      ]),
    ),
  )
}

pub fn build_model_multiline_value_becomes_recursive_model_test() {
  let result =
    model.build_model([
      Entry(key: "server", value: "\n  host = localhost\n  port = 5432"),
    ])
  let empty = Model(dict.new())

  result
  |> expect.to_equal(
    Model(
      dict.from_list([
        #(
          "server",
          Model(
            dict.from_list([
              #("host", Model(dict.from_list([#("localhost", empty)]))),
              #("port", Model(dict.from_list([#("5432", empty)]))),
            ]),
          ),
        ),
      ]),
    ),
  )
}

pub fn build_model_duplicate_keys_merge_recursively_test() {
  let result =
    model.build_model([
      Entry(key: "env", value: "\n  db = primary"),
      Entry(key: "env", value: "\n  cache = redis"),
      Entry(key: "env", value: "\n  db = replica"),
    ])
  let empty = Model(dict.new())

  result
  |> expect.to_equal(
    Model(
      dict.from_list([
        #(
          "env",
          Model(
            dict.from_list([
              #(
                "db",
                Model(
                  dict.from_list([
                    #("primary", empty),
                    #("replica", empty),
                  ]),
                ),
              ),
              #("cache", Model(dict.from_list([#("redis", empty)]))),
            ]),
          ),
        ),
      ]),
    ),
  )
}

pub fn build_model_empty_nested_parse_falls_back_to_terminal_leaf_test() {
  let result = model.build_model([Entry(key: "blank", value: "\n")])
  let empty = Model(dict.new())

  result
  |> expect.to_equal(
    Model(
      dict.from_list([
        #("blank", Model(dict.from_list([#("\n", empty)]))),
      ]),
    ),
  )
}
