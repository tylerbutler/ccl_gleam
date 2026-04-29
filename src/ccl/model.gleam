/// CCL canonical model — OCaml-style fixed-point recursive map.
///
/// `build_model` mirrors the OCaml reference's `fix` function:
/// `type t = Fix of t KeyMap.t` with `String v -> Fix (singleton v empty)`.
///
/// Terminal string values become keys pointing to the empty model;
/// duplicate keys merge recursively. The result has no strings or lists
/// at the value level — every leaf is `Model(empty)`.
///
/// `build_hierarchy` is the JSON-friendly projection of this model;
/// see issue tylerbutler/ccl-test-data#142 for the layering.
import ccl/parser
import ccl/types.{
  type Entry, type Model, type ParseOptions, Model,
}
import gleam/dict.{type Dict}
import gleam/string

pub fn build_model(entries: List(Entry)) -> Model {
  build_model_with(entries, types.default_parse_options())
}

pub fn build_model_with(
  entries: List(Entry),
  parse_options: ParseOptions,
) -> Model {
  Model(build_entries(entries, dict.new(), parse_options))
}

fn build_entries(
  entries: List(Entry),
  acc: Dict(String, Model),
  parse_options: ParseOptions,
) -> Dict(String, Model) {
  case entries {
    [] -> acc
    [entry, ..rest] -> {
      let value_model = resolve_value(entry.value, parse_options)
      let new_acc = case dict.get(acc, entry.key) {
        Error(_) -> dict.insert(acc, entry.key, value_model)
        Ok(existing) ->
          dict.insert(acc, entry.key, merge(existing, value_model))
      }
      build_entries(rest, new_acc, parse_options)
    }
  }
}

fn resolve_value(raw_value: String, parse_options: ParseOptions) -> Model {
  let is_multiline =
    string.starts_with(raw_value, "\n") || string.starts_with(raw_value, "\r\n")
  case is_multiline {
    True ->
      case parser.parse_value_with(raw_value, parse_options) {
        Ok([]) -> singleton_leaf(raw_value)
        Ok(nested_entries) -> build_model_with(nested_entries, parse_options)
        Error(_) -> singleton_leaf(raw_value)
      }
    False -> singleton_leaf(raw_value)
  }
}

fn singleton_leaf(s: String) -> Model {
  Model(dict.from_list([#(s, Model(dict.new()))]))
}

pub fn merge(a: Model, b: Model) -> Model {
  let Model(da) = a
  let Model(db) = b
  Model(
    dict.fold(db, da, fn(acc, k, v_b) {
      case dict.get(acc, k) {
        Error(_) -> dict.insert(acc, k, v_b)
        Ok(v_a) -> dict.insert(acc, k, merge(v_a, v_b))
      }
    }),
  )
}
