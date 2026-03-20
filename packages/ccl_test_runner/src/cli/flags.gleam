/// Shared flag definitions for CCL test runner CLI commands
import glint

/// Flag for specifying implemented CCL functions
pub fn functions_flag() -> glint.Flag(List(String)) {
  glint.strings_flag("functions")
  |> glint.flag_default([])
  |> glint.flag_help(
    "Comma-separated list of implemented CCL functions.
Available: parse, print, build_hierarchy, get_string, get_int, get_bool, get_float, get_list, filter, compose, canonical_format",
  )
}

/// Flag for specifying supported behaviors
pub fn behaviors_flag() -> glint.Flag(List(String)) {
  glint.strings_flag("behaviors")
  |> glint.flag_default(["crlf_normalize_to_lf", "toplevel_indent_strip"])
  |> glint.flag_help("Comma-separated list of supported behaviors")
}

/// Flag for specifying supported features
pub fn features_flag() -> glint.Flag(List(String)) {
  glint.strings_flag("features")
  |> glint.flag_default([])
  |> glint.flag_help("Comma-separated list of supported features")
}

/// Flag for specifying supported variants
pub fn variants_flag() -> glint.Flag(List(String)) {
  glint.strings_flag("variants")
  |> glint.flag_default(["reference_compliant"])
  |> glint.flag_help("Comma-separated list of supported variants")
}
