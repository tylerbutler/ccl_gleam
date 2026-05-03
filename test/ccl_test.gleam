import startest
import startest/expect

import ccl/hierarchy
import ccl/model
import ccl/model/nested_parser
import ccl/parser
import ccl/types.{
  BuildOptions, CclList, CclObject, CclString, Entry, LexicographicOrder, Model,
  ParseOptions, TabsAsContent, TabsAsWhitespace, default_parse_options,
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

/// `continuation_tab_to_space`: leading tabs on continuation lines map 1:1 to
/// spaces (OCaml-canonical semantics in ccl-test-data v1.0.0), not "strip all
/// leading whitespace when a tab is present".
pub fn parse_continuation_tabs_to_spaces_test() {
  let input = "section =\n\t\tindented_with_tabs\n\t\tanother_line"
  let result = parser.parse(input)
  result
  |> expect.to_equal(
    Ok([
      Entry(key: "section", value: "\n  indented_with_tabs\n  another_line"),
    ]),
  )
}

/// Mixed leading tab/space on continuation line: each tab becomes one space.
pub fn parse_continuation_mixed_tab_space_test() {
  let input = "section =\n \tmixed_indent\n\t another_line"
  let result = parser.parse(input)
  result
  |> expect.to_equal(
    Ok([
      Entry(key: "section", value: "\n  mixed_indent\n  another_line"),
    ]),
  )
}

pub fn parse_tabs_as_whitespace_replaces_value_tabs_test() {
  let opts =
    ParseOptions(..default_parse_options(), tab_handling: TabsAsWhitespace)

  let result = parser.parse_with("key = \tvalue\twith\ttabs", opts)

  result
  |> expect.to_equal(Ok([Entry(key: "key", value: "value with tabs")]))
}

pub fn parse_tabs_as_content_preserves_value_tabs_test() {
  let opts =
    ParseOptions(..default_parse_options(), tab_handling: TabsAsContent)

  let result = parser.parse_with("key = \tvalue\twith\ttabs", opts)

  result
  |> expect.to_equal(Ok([Entry(key: "key", value: "\tvalue\twith\ttabs")]))
}

/// `multiline_keys` feature: indented non-`=` continuation lines accumulate
/// into the pending key before a subsequent line starting with `=` completes
/// the entry. Trimmed continuations are joined with a single space.
pub fn parse_multiline_key_two_lines_test() {
  let result = parser.parse("my\n key\n= val")
  result
  |> expect.to_equal(Ok([Entry(key: "my key", value: "val")]))
}

pub fn parse_multiline_key_three_lines_test() {
  let result = parser.parse("a\n b\n c\n= val")
  result
  |> expect.to_equal(Ok([Entry(key: "a b c", value: "val")]))
}

/// Tab-indented `= val` completes the pending key (tab counts as whitespace
/// and the split yields an empty key, signalling combination).
pub fn parse_multiline_key_tab_equals_test() {
  let result = parser.parse("key\n\t= val")
  result
  |> expect.to_equal(Ok([Entry(key: "key", value: "val")]))
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
