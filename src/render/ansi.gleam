/// Shared ANSI terminal styling using gleam_community_ansi.
///
/// Bridges shore/style.Color to ANSI string formatting and provides
/// commonly-used style helpers. All ANSI escape usage is centralized here.
import gleam/string
import gleam_community/ansi
import shore/style

/// Apply a shore Color as foreground color to text.
pub fn fg(text: String, color: style.Color) -> String {
  case color {
    style.Black -> ansi.black(text)
    style.Red -> ansi.red(text)
    style.Green -> ansi.green(text)
    style.Yellow -> ansi.yellow(text)
    style.Blue -> ansi.blue(text)
    style.Magenta -> ansi.magenta(text)
    style.Cyan -> ansi.cyan(text)
    style.White -> ansi.white(text)
  }
}

/// Apply bold styling.
pub fn bold(text: String) -> String {
  ansi.bold(text)
}

/// Apply dim styling.
pub fn dim(text: String) -> String {
  ansi.dim(text)
}

/// Green background with black text.
pub fn bg_green(text: String) -> String {
  ansi.bg_green(ansi.black(text))
}

/// Red background with white text.
pub fn bg_red(text: String) -> String {
  ansi.bg_red(ansi.white(text))
}

/// Strip all ANSI escape sequences from a string.
pub fn strip(text: String) -> String {
  ansi.strip(text)
}

/// Calculate visible length of a string (ignoring ANSI escapes).
pub fn visible_length(text: String) -> Int {
  text |> strip |> string.length
}
