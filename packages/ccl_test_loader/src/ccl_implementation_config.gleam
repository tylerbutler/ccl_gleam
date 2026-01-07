/// Centralized configuration for CCL implementation support
/// This module defines which features, behaviors, and variants are supported
/// by this CCL implementation, and provides filtering based on conflicts
import gleam/list
import gleam/result
import gleam/string
import simplifile
import tom

/// CCL implementation configuration
/// Supports function-based filtering with behaviors and conflict resolution
/// per the official test runner implementation guide
pub type ImplementationConfig {
  ImplementationConfig(
    /// Implementation completeness level (for sorting/comparison)
    level: Int,
    /// Supported functions (parse, make-objects, get-string, etc.)
    supported_functions: List(String),
    /// Supported optional features (comments, dotted-keys, unicode)
    supported_features: List(String),
    /// Implementation behaviors (crlf_normalize_to_lf, boolean_lenient, etc.)
    supported_behaviors: List(String),
    /// Behaviors to skip during test filtering (conflicts with implementation)
    skip_behaviors: List(String),
    /// Variant choice (proposed-behavior, reference-compliant)
    variant_choice: String,
  )
}

/// Full implementation with all CCL functions
pub fn full_implementation() -> ImplementationConfig {
  ImplementationConfig(
    level: 4,
    supported_functions: [
      "parse",
      "make-objects",
      "get-string",
      "get-int",
      "get-bool",
      "get-float",
      "get-list",
    ],
    supported_features: [
      "comments",
      "dotted-keys",
      "unicode",
    ],
    supported_behaviors: [
      "crlf_normalize_to_lf",
      "boolean_lenient",
      "indent_spaces",
    ],
    skip_behaviors: [
      "crlf_preserve_literal",
      "tabs_as_content",
      "indent_tabs",
    ],
    variant_choice: "proposed-behavior",
  )
}

/// Parsing-only implementation
pub fn parse_only() -> ImplementationConfig {
  ImplementationConfig(
    level: 1,
    supported_functions: ["parse"],
    supported_features: [],
    supported_behaviors: ["crlf_normalize_to_lf", "boolean_lenient"],
    skip_behaviors: ["crlf_preserve_literal", "tabs_as_content"],
    variant_choice: "reference-compliant",
  )
}

/// Basic implementation (parsing + object construction)
pub fn basic_implementation() -> ImplementationConfig {
  ImplementationConfig(
    level: 3,
    supported_functions: ["parse", "make-objects"],
    supported_features: ["dotted-keys"],
    supported_behaviors: ["crlf_normalize_to_lf", "boolean_lenient"],
    skip_behaviors: ["crlf_preserve_literal", "tabs_as_content"],
    variant_choice: "proposed-behavior",
  )
}

/// Reference-compliant full implementation
pub fn reference_compliant() -> ImplementationConfig {
  ImplementationConfig(
    level: 4,
    supported_functions: [
      "parse",
      "make-objects",
      "get-string",
      "get-int",
      "get-bool",
    ],
    supported_features: [],
    supported_behaviors: ["crlf_normalize_to_lf"],
    skip_behaviors: ["crlf_preserve_literal", "tabs_as_content"],
    variant_choice: "reference-compliant",
  )
}

/// Check if a function is supported by the implementation
pub fn supports_function(config: ImplementationConfig, function: String) -> Bool {
  list.contains(config.supported_functions, function)
}

/// Check if a feature is supported by the implementation
pub fn supports_feature(config: ImplementationConfig, feature: String) -> Bool {
  list.contains(config.supported_features, feature)
}

/// Check if a behavior is supported by the implementation
pub fn supports_behavior(config: ImplementationConfig, behavior: String) -> Bool {
  list.contains(config.supported_behaviors, behavior)
}

/// Check if a behavior should be skipped (conflicts with implementation)
pub fn should_skip_behavior(
  config: ImplementationConfig,
  behavior: String,
) -> Bool {
  list.contains(config.skip_behaviors, behavior)
}

/// Check if a test matches the implementation's variant choice
pub fn matches_variant(config: ImplementationConfig, variant: String) -> Bool {
  config.variant_choice == variant
}

/// Check if a test is compatible with the implementation
/// Returns True if the test can be run, False if it should be skipped
pub fn test_is_compatible(
  config: ImplementationConfig,
  required_functions: List(String),
  required_features: List(String),
  required_behaviors: List(String),
  test_conflicts: List(String),
) -> Bool {
  // Check all required functions are supported
  let functions_ok =
    list.all(required_functions, fn(f) { supports_function(config, f) })

  // Check all required features are supported
  let features_ok =
    list.all(required_features, fn(f) { supports_feature(config, f) })

  // Check all required behaviors are supported
  let behaviors_ok =
    list.all(required_behaviors, fn(b) { supports_behavior(config, b) })

  // Check that none of our behaviors conflict with the test
  // If any of our supported_behaviors appear in test_conflicts, skip the test
  let no_conflicts =
    !list.any(config.supported_behaviors, fn(our_behavior) {
      list.contains(test_conflicts, our_behavior)
    })

  // Check that none of the required behaviors are in our skip list
  let not_skipped =
    !list.any(required_behaviors, fn(b) { should_skip_behavior(config, b) })

  functions_ok && features_ok && behaviors_ok && no_conflicts && not_skipped
}

/// Get a concise summary of implementation capabilities
pub fn get_summary(config: ImplementationConfig) -> String {
  let function_count = list.length(config.supported_functions)
  let feature_count = list.length(config.supported_features)
  let behavior_count = list.length(config.supported_behaviors)
  let skip_count = list.length(config.skip_behaviors)

  "CCL Implementation ("
  <> config.variant_choice
  <> ")\n"
  <> "  Functions: "
  <> string.inspect(function_count)
  <> " supported\n"
  <> "  Features: "
  <> string.inspect(feature_count)
  <> " optional\n"
  <> "  Behaviors: "
  <> string.inspect(behavior_count)
  <> " active, "
  <> string.inspect(skip_count)
  <> " skipped\n"
}

// === TOML CONFIGURATION FILE SUPPORT ===
// TOML is more human-friendly for configuration files

/// Calculate implementation level based on supported functions
fn calculate_level(functions: List(String)) -> Int {
  let has_parse = list.contains(functions, "parse")
  let has_make_objects = list.contains(functions, "make-objects")
  let has_typed_access =
    list.contains(functions, "get-string")
    || list.contains(functions, "get-int")
    || list.contains(functions, "get-bool")

  case has_parse, has_make_objects, has_typed_access {
    True, True, True -> 4
    True, True, False -> 3
    True, False, False -> 1
    _, _, _ -> 0
  }
}

/// TOML configuration file structure
/// Example:
/// ```toml
/// implementation_name = "my_ccl_parser"
///
/// [capabilities]
/// functions = ["parse", "make-objects", "get-string"]
/// features = ["dotted-keys", "comments"]
/// behaviors = ["crlf_normalize_to_lf", "boolean_lenient"]
///
/// [test_selection]
/// skip_behaviors = ["tabs_as_content", "crlf_preserve_literal"]
/// variant = "proposed-behavior"
/// ```
/// Load implementation config from a TOML file
pub fn load_from_toml(file_path: String) -> Result(ImplementationConfig, String) {
  use content <- result.try(
    simplifile.read(file_path)
    |> result.map_error(fn(_) { "Could not read config file: " <> file_path }),
  )

  use parsed <- result.try(
    tom.parse(content)
    |> result.map_error(fn(err) {
      "TOML parsing failed for " <> file_path <> ": " <> string.inspect(err)
    }),
  )

  // Extract capabilities
  let functions =
    tom.get_array(parsed, ["capabilities", "functions"])
    |> result.map(fn(arr) {
      list.filter_map(arr, fn(item) {
        case item {
          tom.String(s) -> Ok(s)
          _ -> Error(Nil)
        }
      })
    })
    |> result.unwrap([])

  let features =
    tom.get_array(parsed, ["capabilities", "features"])
    |> result.map(fn(arr) {
      list.filter_map(arr, fn(item) {
        case item {
          tom.String(s) -> Ok(s)
          _ -> Error(Nil)
        }
      })
    })
    |> result.unwrap([])

  let behaviors =
    tom.get_array(parsed, ["capabilities", "behaviors"])
    |> result.map(fn(arr) {
      list.filter_map(arr, fn(item) {
        case item {
          tom.String(s) -> Ok(s)
          _ -> Error(Nil)
        }
      })
    })
    |> result.unwrap([])

  // Extract test_selection
  let skip_behaviors =
    tom.get_array(parsed, ["test_selection", "skip_behaviors"])
    |> result.map(fn(arr) {
      list.filter_map(arr, fn(item) {
        case item {
          tom.String(s) -> Ok(s)
          _ -> Error(Nil)
        }
      })
    })
    |> result.unwrap([])

  let variant =
    tom.get_string(parsed, ["test_selection", "variant"])
    |> result.unwrap("proposed-behavior")

  Ok(ImplementationConfig(
    level: calculate_level(functions),
    supported_functions: functions,
    supported_features: features,
    supported_behaviors: behaviors,
    skip_behaviors: skip_behaviors,
    variant_choice: variant,
  ))
}

/// Save implementation config to a TOML file
pub fn save_to_toml(
  config: ImplementationConfig,
  file_path: String,
) -> Result(Nil, String) {
  let functions_str =
    config.supported_functions
    |> list.map(fn(s) { "\"" <> s <> "\"" })
    |> string.join(", ")

  let features_str =
    config.supported_features
    |> list.map(fn(s) { "\"" <> s <> "\"" })
    |> string.join(", ")

  let behaviors_str =
    config.supported_behaviors
    |> list.map(fn(s) { "\"" <> s <> "\"" })
    |> string.join(", ")

  let skip_behaviors_str =
    config.skip_behaviors
    |> list.map(fn(s) { "\"" <> s <> "\"" })
    |> string.join(", ")

  let toml_content =
    "# CCL Implementation Configuration\n"
    <> "implementation_name = \"ccl_gleam\"\n"
    <> "\n"
    <> "[capabilities]\n"
    <> "functions = ["
    <> functions_str
    <> "]\n"
    <> "features = ["
    <> features_str
    <> "]\n"
    <> "behaviors = ["
    <> behaviors_str
    <> "]\n"
    <> "\n"
    <> "[test_selection]\n"
    <> "skip_behaviors = ["
    <> skip_behaviors_str
    <> "]\n"
    <> "variant = \""
    <> config.variant_choice
    <> "\"\n"

  simplifile.write(file_path, toml_content)
  |> result.map_error(fn(_) { "Could not write config file: " <> file_path })
}

/// Load config from TOML or use default if file doesn't exist
pub fn load_or_default(
  file_path: String,
  default: ImplementationConfig,
) -> ImplementationConfig {
  case load_from_toml(file_path) {
    Ok(config) -> config
    Error(_) -> default
  }
}
