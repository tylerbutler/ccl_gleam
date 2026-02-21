/// Renderer for ExpectedObject (nested objects) in JSON format.
import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import render/ansi
import render/theme.{type Theme}
import render/whitespace
import shore
import shore/ui
import test_types.{type ExpectedNode, NodeList, NodeObject, NodeString}

// ============================================================================
// Plain string rendering
// ============================================================================

/// Render an object to plain string (JSON format).
pub fn to_string(obj: Dict(String, ExpectedNode)) -> String {
  render_object_string(obj, 0)
}

fn render_object_string(obj: Dict(String, ExpectedNode), indent: Int) -> String {
  let prefix = string.repeat("  ", indent)
  let inner_prefix = string.repeat("  ", indent + 1)

  let entries =
    obj
    |> dict.to_list
    |> list.map(fn(pair) {
      let #(key, value) = pair
      inner_prefix
      <> "\""
      <> key
      <> "\": "
      <> render_node_string(value, indent + 1)
    })
    |> string.join(",\n")

  "{\n" <> entries <> "\n" <> prefix <> "}"
}

fn render_node_string(node: ExpectedNode, indent: Int) -> String {
  case node {
    NodeString(s) -> "\"" <> visualize_plain(s) <> "\""
    NodeList(items) -> render_list_string(items)
    NodeObject(nested) -> render_object_string(nested, indent)
  }
}

fn render_list_string(items: List(String)) -> String {
  let rendered =
    items
    |> list.map(fn(item) { "\"" <> visualize_plain(item) <> "\"" })
    |> string.join(", ")
  "[" <> rendered <> "]"
}

fn visualize_plain(s: String) -> String {
  s |> whitespace.visualize |> whitespace.to_display_string
}

// ============================================================================
// ANSI colored string rendering
// ============================================================================

/// Render an object to ANSI colored string (JSON format).
pub fn to_ansi(obj: Dict(String, ExpectedNode), theme: Theme) -> String {
  render_object_ansi(obj, 0, theme)
}

fn render_object_ansi(
  obj: Dict(String, ExpectedNode),
  indent: Int,
  theme: Theme,
) -> String {
  let prefix = string.repeat("  ", indent)
  let inner_prefix = string.repeat("  ", indent + 1)

  let entries =
    obj
    |> dict.to_list
    |> list.map(fn(pair) {
      let #(key, value) = pair
      inner_prefix
      <> ansi.fg("\"" <> key <> "\"", theme.key)
      <> ": "
      <> render_node_ansi(value, indent + 1, theme)
    })
    |> string.join(",\n")

  "{\n" <> entries <> "\n" <> prefix <> "}"
}

fn render_node_ansi(node: ExpectedNode, indent: Int, theme: Theme) -> String {
  case node {
    NodeString(s) ->
      ansi.fg(
        "\"" <> whitespace.render_ansi(s, theme.value, theme.whitespace) <> "\"",
        theme.value,
      )
    NodeList(items) -> render_list_ansi(items, theme)
    NodeObject(nested) -> render_object_ansi(nested, indent, theme)
  }
}

fn render_list_ansi(items: List(String), theme: Theme) -> String {
  let rendered =
    items
    |> list.map(fn(item) {
      ansi.fg("\"", theme.value)
      <> whitespace.render_ansi(item, theme.value, theme.whitespace)
      <> ansi.fg("\"", theme.value)
    })
    |> string.join(", ")
  "[" <> rendered <> "]"
}

// ============================================================================
// Shore TUI rendering
// ============================================================================

/// Render an object to shore nodes (TUI, JSON format).
pub fn to_shore(obj: Dict(String, ExpectedNode), theme: Theme) -> shore.Node(a) {
  render_object_shore(obj, 0, theme)
}

fn render_object_shore(
  obj: Dict(String, ExpectedNode),
  indent: Int,
  theme: Theme,
) -> shore.Node(a) {
  let prefix = string.repeat("  ", indent)
  let inner_prefix = string.repeat("  ", indent + 1)

  let entries =
    obj
    |> dict.to_list
    |> list.index_map(fn(pair, idx) {
      let #(key, value) = pair
      let is_last = idx == dict.size(obj) - 1
      let comma = case is_last {
        True -> ""
        False -> ","
      }
      render_entry_shore(key, value, inner_prefix, comma, indent + 1, theme)
    })

  ui.col([
    ui.text("{"),
    ui.col(entries),
    ui.text(prefix <> "}"),
  ])
}

fn render_entry_shore(
  key: String,
  value: ExpectedNode,
  prefix: String,
  comma: String,
  indent: Int,
  theme: Theme,
) -> shore.Node(a) {
  case value {
    NodeString(s) ->
      ui.row([
        ui.text(prefix),
        ui.text_styled("\"" <> key <> "\"", Some(theme.key), None),
        ui.text(": \""),
        whitespace.render_shore(s, theme.value, theme.whitespace),
        ui.text("\"" <> comma),
      ])
    NodeList(items) ->
      ui.row([
        ui.text(prefix),
        ui.text_styled("\"" <> key <> "\"", Some(theme.key), None),
        ui.text(": "),
        render_list_shore(items, theme),
        ui.text(comma),
      ])
    NodeObject(nested) ->
      ui.col([
        ui.row([
          ui.text(prefix),
          ui.text_styled("\"" <> key <> "\"", Some(theme.key), None),
          ui.text(": {"),
        ]),
        render_object_entries_shore(nested, indent, theme),
        ui.text(string.repeat("  ", indent) <> "}" <> comma),
      ])
  }
}

fn render_object_entries_shore(
  obj: Dict(String, ExpectedNode),
  indent: Int,
  theme: Theme,
) -> shore.Node(a) {
  let inner_prefix = string.repeat("  ", indent + 1)

  let entries =
    obj
    |> dict.to_list
    |> list.index_map(fn(pair, idx) {
      let #(key, value) = pair
      let is_last = idx == dict.size(obj) - 1
      let comma = case is_last {
        True -> ""
        False -> ","
      }
      render_entry_shore(key, value, inner_prefix, comma, indent + 1, theme)
    })

  ui.col(entries)
}

fn render_list_shore(items: List(String), theme: Theme) -> shore.Node(a) {
  let rendered =
    items
    |> list.index_map(fn(item, idx) {
      let is_last = idx == list.length(items) - 1
      let comma = case is_last {
        True -> ""
        False -> ", "
      }
      ui.row([
        ui.text("\""),
        whitespace.render_shore(item, theme.value, theme.whitespace),
        ui.text("\"" <> comma),
      ])
    })

  ui.row([ui.text("["), ..list.append(rendered, [ui.text("]")])])
}
