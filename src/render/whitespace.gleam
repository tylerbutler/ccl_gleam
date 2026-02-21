/// Whitespace visualization for CCL input rendering.
///
/// Provides functions to split strings into text/whitespace parts,
/// convert them to visible glyphs, and render with ANSI colors or shore nodes.
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import render/ansi
import shore
import shore/style
import shore/ui

/// Parts of a string with whitespace identified
pub type WhitespacePart {
  Text(String)
  Space
  Tab
  Newline
  CarriageReturn
}

/// Convert a string into parts with whitespace identified.
/// Uses utf_codepoints instead of graphemes so that \r\n is split
/// into separate CarriageReturn and Newline parts.
pub fn visualize(input: String) -> List(WhitespacePart) {
  input
  |> string.to_utf_codepoints
  |> list.map(string.utf_codepoint_to_int)
  |> list.fold([], fn(acc, cp) {
    case cp {
      0x20 -> [Space, ..acc]
      0x09 -> [Tab, ..acc]
      0x0A -> [Newline, ..acc]
      0x0D -> [CarriageReturn, ..acc]
      _ -> {
        let char = codepoint_to_string(cp)
        case acc {
          [Text(existing), ..rest] -> [Text(existing <> char), ..rest]
          _ -> [Text(char), ..acc]
        }
      }
    }
  })
  |> list.reverse
}

fn codepoint_to_string(cp: Int) -> String {
  let assert Ok(codepoint) = string.utf_codepoint(cp)
  string.from_utf_codepoints([codepoint])
}

/// Get the display glyph for a whitespace part.
pub fn glyph(part: WhitespacePart) -> String {
  case part {
    Text(s) -> s
    Space -> "·"
    Tab -> "→"
    Newline -> "↵"
    CarriageReturn -> "␍"
  }
}

/// Check if a part is whitespace.
pub fn is_whitespace(part: WhitespacePart) -> Bool {
  case part {
    Text(_) -> False
    _ -> True
  }
}

/// Convert parts to display string with glyphs.
pub fn to_display_string(parts: List(WhitespacePart)) -> String {
  parts
  |> list.map(glyph)
  |> string.concat
}

/// Convert parts back to original string (no glyphs).
pub fn to_original_string(parts: List(WhitespacePart)) -> String {
  parts
  |> list.map(fn(part) {
    case part {
      Text(s) -> s
      Space -> " "
      Tab -> "\t"
      Newline -> "\n"
      CarriageReturn -> "\r"
    }
  })
  |> string.concat
}

// ============================================================================
// Shared rendering: ANSI strings with visible whitespace
// ============================================================================

/// Render a string with visible whitespace glyphs as ANSI-colored text.
/// Whitespace chars use `ws_color`; text chars use `text_color`.
pub fn render_ansi(
  s: String,
  text_color: style.Color,
  ws_color: style.Color,
) -> String {
  s
  |> visualize
  |> list.map(fn(part) {
    case is_whitespace(part) {
      True -> ansi.fg(glyph(part), ws_color)
      False -> ansi.fg(glyph(part), text_color)
    }
  })
  |> string.concat
}

/// Render a string with visible whitespace glyphs using dim whitespace
/// and the given color for text.
pub fn render_ansi_dim_ws(s: String, text_color: style.Color) -> String {
  s
  |> visualize
  |> list.map(fn(part) {
    case is_whitespace(part) {
      True -> ansi.dim(glyph(part))
      False -> ansi.fg(glyph(part), text_color)
    }
  })
  |> string.concat
}

// ============================================================================
// Shared rendering: shore nodes with visible whitespace
// ============================================================================

/// Render a string with visible whitespace as shore TUI nodes.
pub fn render_shore(
  s: String,
  text_color: style.Color,
  ws_color: style.Color,
) -> shore.Node(a) {
  let parts =
    s
    |> visualize
    |> list.map(fn(part) {
      case is_whitespace(part) {
        True -> ui.text_styled(glyph(part), Some(ws_color), None)
        False -> ui.text_styled(glyph(part), Some(text_color), None)
      }
    })
  ui.row(parts)
}
