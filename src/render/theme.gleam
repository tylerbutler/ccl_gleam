/// Theme definitions for rendering CCL content
import gleam/option.{type Option, None}
import shore/style

/// Theme for rendering CCL content
pub type Theme {
  Theme(
    key: style.Color,
    value: style.Color,
    separator: style.Color,
    whitespace: style.Color,
    punctuation: Option(style.Color),
  )
}

/// Default theme for CCL rendering
pub fn default() -> Theme {
  Theme(
    key: style.Cyan,
    value: style.White,
    separator: style.Blue,
    whitespace: style.White,
    punctuation: None,
  )
}

/// Get the color for a theme element, with fallback to default
pub fn get_punctuation(theme: Theme) -> Option(style.Color) {
  theme.punctuation
}
