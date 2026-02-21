/// Shared utility functions used across the codebase.
import gleam/list
import gleam/result
import gleam/string

/// Extract filename from a path (everything after last `/`).
pub fn get_filename(path: String) -> String {
  path
  |> string.split("/")
  |> list.last
  |> result.unwrap(path)
}

/// Pad a string on the right to a minimum width.
pub fn pad_right(s: String, width: Int) -> String {
  let len = string.length(s)
  case len >= width {
    True -> s
    False -> s <> string.repeat(" ", width - len)
  }
}

/// Pad a string on the left to a minimum width.
pub fn pad_left(s: String, width: Int) -> String {
  let len = string.length(s)
  case len >= width {
    True -> s
    False -> string.repeat(" ", width - len) <> s
  }
}

/// Truncate a string with "..." if it exceeds max_len.
pub fn truncate(s: String, max_len: Int) -> String {
  case string.length(s) > max_len {
    True -> string.slice(s, 0, max_len - 3) <> "..."
    False -> s
  }
}

/// Format a byte count as a human-readable size string.
pub fn format_size(bytes: Int) -> String {
  case bytes {
    b if b < 1024 -> string.inspect(b) <> "B"
    b if b < 1_048_576 -> string.inspect(b / 1024) <> "K"
    b -> string.inspect(b / 1_048_576) <> "M"
  }
}
