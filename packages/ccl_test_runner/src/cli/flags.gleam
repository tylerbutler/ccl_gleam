/// Shared flag definitions for CCL test runner CLI commands
import glint
import test_runner/config

/// Flag for specifying the path to ccl-config.yaml
pub fn config_flag() -> glint.Flag(String) {
  glint.string_flag("config")
  |> glint.flag_default(config.default_config_path)
  |> glint.flag_help(
    "Path to ccl-config.yaml file declaring implementation capabilities",
  )
}

/// Flag for specifying implemented CCL functions (overrides config file)
pub fn functions_flag() -> glint.Flag(List(String)) {
  glint.strings_flag("functions")
  |> glint.flag_default([])
  |> glint.flag_help(
    "Override functions from config file.
Available: parse, build_hierarchy, get_string, get_int, get_bool, get_float, get_list, filter, canonical_format",
  )
}

/// Flag for specifying supported behaviours (overrides config file)
pub fn behaviours_flag() -> glint.Flag(List(String)) {
  glint.strings_flag("behaviours")
  |> glint.flag_default([])
  |> glint.flag_help("Override behaviours from config file")
}

/// Flag for specifying supported features (overrides config file)
pub fn features_flag() -> glint.Flag(List(String)) {
  glint.strings_flag("features")
  |> glint.flag_default([])
  |> glint.flag_help("Override features from config file")
}

/// Flag for specifying supported variants (overrides config file)
pub fn variants_flag() -> glint.Flag(List(String)) {
  glint.strings_flag("variants")
  |> glint.flag_default([])
  |> glint.flag_help("Override variants from config file")
}
