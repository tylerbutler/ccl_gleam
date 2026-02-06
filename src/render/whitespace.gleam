/// Whitespace visualization for CCL input rendering
import gleam/list
import gleam/string

/// Parts of a string with whitespace identified
pub type WhitespacePart {
  Text(String)
  Space
  Tab
  Newline
  CarriageReturn
}

/// Convert a string into parts with whitespace identified
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
        // Merge consecutive text characters
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

/// Get the display glyph for a whitespace character
pub fn glyph(part: WhitespacePart) -> String {
  case part {
    Text(s) -> s
    Space -> "·"
    Tab -> "→"
    Newline -> "↵"
    CarriageReturn -> "␍"
  }
}

/// Check if a part is whitespace
pub fn is_whitespace(part: WhitespacePart) -> Bool {
  case part {
    Text(_) -> False
    _ -> True
  }
}

/// Convert parts back to display string with glyphs
pub fn to_display_string(parts: List(WhitespacePart)) -> String {
  parts
  |> list.map(glyph)
  |> string.concat
}

/// Convert parts back to original string (no glyphs)
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
