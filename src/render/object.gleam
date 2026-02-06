/// Renderer for ExpectedObject (nested objects) in JSON format
import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import render/theme.{type Theme}
import render/whitespace
import shore
import shore/style
import shore/ui
import test_types.{type ExpectedNode, NodeList, NodeObject, NodeString}

/// Render an object to plain string (JSON format)
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
    NodeString(s) -> "\"" <> visualize_string(s) <> "\""
    NodeList(items) -> render_list_string(items)
    NodeObject(nested) -> render_object_string(nested, indent)
  }
}

fn render_list_string(items: List(String)) -> String {
  let rendered =
    items
    |> list.map(fn(item) { "\"" <> visualize_string(item) <> "\"" })
    |> string.join(", ")
  "[" <> rendered <> "]"
}

fn visualize_string(s: String) -> String {
  s
  |> whitespace.visualize
  |> whitespace.to_display_string
}

/// Render an object to ANSI colored string (JSON format)
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
      <> ansi_color(theme.key)
      <> "\""
      <> key
      <> "\""
      <> ansi_reset()
      <> ": "
      <> render_node_ansi(value, indent + 1, theme)
    })
    |> string.join(",\n")

  "{\n" <> entries <> "\n" <> prefix <> "}"
}

fn render_node_ansi(node: ExpectedNode, indent: Int, theme: Theme) -> String {
  case node {
    NodeString(s) ->
      ansi_color(theme.value)
      <> "\""
      <> visualize_string_ansi(s, theme)
      <> "\""
      <> ansi_reset()
    NodeList(items) -> render_list_ansi(items, theme)
    NodeObject(nested) -> render_object_ansi(nested, indent, theme)
  }
}

fn render_list_ansi(items: List(String), theme: Theme) -> String {
  let rendered =
    items
    |> list.map(fn(item) {
      ansi_color(theme.value)
      <> "\""
      <> visualize_string_ansi(item, theme)
      <> "\""
      <> ansi_reset()
    })
    |> string.join(", ")
  "[" <> rendered <> "]"
}

fn visualize_string_ansi(s: String, theme: Theme) -> String {
  s
  |> whitespace.visualize
  |> list.map(fn(part) {
    case whitespace.is_whitespace(part) {
      True ->
        ansi_reset()
        <> ansi_color(theme.whitespace)
        <> whitespace.glyph(part)
        <> ansi_reset()
        <> ansi_color(theme.value)
      False -> whitespace.glyph(part)
    }
  })
  |> string.concat
}

fn ansi_color(color: style.Color) -> String {
  let code = case color {
    style.Black -> "30"
    style.Red -> "31"
    style.Green -> "32"
    style.Yellow -> "33"
    style.Blue -> "34"
    style.Magenta -> "35"
    style.Cyan -> "36"
    style.White -> "37"
  }
  "\u{001b}[" <> code <> "m"
}

fn ansi_reset() -> String {
  "\u{001b}[0m"
}

/// Render an object to shore nodes (TUI, JSON format)
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
        ui.text(": "),
        ui.text("\""),
        render_string_shore(s, theme),
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
        render_string_shore(item, theme),
        ui.text("\"" <> comma),
      ])
    })

  ui.row([ui.text("["), ..list.append(rendered, [ui.text("]")])])
}

fn render_string_shore(s: String, theme: Theme) -> shore.Node(a) {
  let parts =
    s
    |> whitespace.visualize
    |> list.map(fn(part) {
      case whitespace.is_whitespace(part) {
        True ->
          ui.text_styled(whitespace.glyph(part), Some(theme.whitespace), None)
        False -> ui.text_styled(whitespace.glyph(part), Some(theme.value), None)
      }
    })

  ui.row(parts)
}
