/// Renderer for ExpectedValue (single string values).
import render/theme.{type Theme}
import render/whitespace
import shore

/// Render a string value with visible whitespace to plain string.
pub fn to_string(value: String) -> String {
  value
  |> whitespace.visualize
  |> whitespace.to_display_string
}

/// Render a string value with visible whitespace to ANSI colored string.
pub fn to_ansi(value: String, theme: Theme) -> String {
  whitespace.render_ansi(value, theme.value, theme.whitespace)
}

/// Render a string value with visible whitespace to shore nodes (TUI).
pub fn to_shore(value: String, theme: Theme) -> shore.Node(a) {
  whitespace.render_shore(value, theme.value, theme.whitespace)
}
