/// Centralized configuration for CCL implementation support
/// This module defines which features, behaviors, and variants are supported
/// by this CCL implementation, and provides filtering based on conflicts.
///
/// Function, behavior, feature, and variant names follow the official
/// ccl-test-data schema (generated-format.json).
import gleam/list
import gleam/result
import gleam/string
import simplifile
import tom

// Import official constants from generated_test_types
// These are used in presets and calculate_level
//
// Functions: CCL parsing and processing functions (parse, build_hierarchy, etc.)
// Behaviors: Implementation behaviors affecting parsing behavior (array order, booleans, etc.)
// Features: Optional language features (comments, multiline, unicode support)
// Variants: Implementation variants (proposed behavior vs reference compliant)
import generated_test_types.{
  behavior_array_order_insertion, behavior_array_order_lexicographic,
  behavior_boolean_lenient, behavior_boolean_strict,
  behavior_crlf_normalize_to_lf, behavior_crlf_preserve_literal,
  behavior_indent_spaces, behavior_indent_tabs, behavior_list_coercion_disabled,
  behavior_list_coercion_enabled, behavior_tabs_as_content,
  behavior_tabs_as_whitespace, behavior_toplevel_indent_preserve,
  behavior_toplevel_indent_strip, feature_comments, feature_multiline,
  feature_unicode, feature_whitespace, function_build_hierarchy,
  function_compose, function_filter, function_get_bool, function_get_float,
  function_get_int, function_get_list, function_get_string, function_parse,
  function_parse_indented, variant_proposed_behavior,
  variant_reference_compliant,
}

/// CCL implementation configuration
/// Supports function-based filtering with behaviors and conflict resolution
/// per the official test runner implementation guide
pub type ImplementationConfig {
  ImplementationConfig(
    /// Implementation completeness level (for sorting/comparison)
    level: Int,
    /// Supported functions (parse, build_hierarchy, get_string, etc.)
    /// Uses official function names from generated-format.json schema
    supported_functions: List(String),
    /// Supported optional features (comments, empty_keys, unicode, etc.)
    /// NOTE: Features are INFORMATIONAL only - used for gap reporting, not filtering
    supported_features: List(String),
    /// Implementation behaviors (crlf_normalize_to_lf, boolean_lenient, etc.)
    supported_behaviors: List(String),
    /// Behaviors to skip during test filtering (conflicts with implementation)
    skip_behaviors: List(String),
    /// Variant choices (proposed_behavior, reference_compliant)
    /// Tests conflicting with these variants will be skipped
    supported_variants: List(String),
  )
}

/// Full implementation with all CCL functions
pub fn full_implementation() -> ImplementationConfig {
  ImplementationConfig(
    level: 4,
    supported_functions: [
      function_parse,
      function_parse_indented,
      function_build_hierarchy,
      function_filter,
      function_compose,
      function_get_string,
      function_get_int,
      function_get_bool,
      function_get_float,
      function_get_list,
    ],
    // Features are informational only - list what we support for reporting
    supported_features: [
      feature_comments,
      feature_multiline,
      feature_unicode,
      feature_whitespace,
    ],
    supported_behaviors: [
      behavior_crlf_normalize_to_lf,
      behavior_boolean_lenient,
      behavior_indent_spaces,
      behavior_tabs_as_whitespace,
      behavior_list_coercion_disabled,
      behavior_array_order_insertion,
      behavior_toplevel_indent_strip,
    ],
    skip_behaviors: [
      behavior_crlf_preserve_literal,
      behavior_tabs_as_content,
      behavior_indent_tabs,
      behavior_boolean_strict,
      behavior_list_coercion_enabled,
      behavior_array_order_lexicographic,
      behavior_toplevel_indent_preserve,
    ],
    supported_variants: [variant_proposed_behavior],
  )
}

/// Parsing-only implementation
pub fn parse_only() -> ImplementationConfig {
  ImplementationConfig(
    level: 1,
    supported_functions: [function_parse],
    supported_features: [],
    supported_behaviors: [
      behavior_crlf_normalize_to_lf,
      behavior_tabs_as_whitespace,
      behavior_toplevel_indent_strip,
    ],
    skip_behaviors: [
      behavior_crlf_preserve_literal,
      behavior_tabs_as_content,
      behavior_toplevel_indent_preserve,
    ],
    supported_variants: [variant_reference_compliant],
  )
}

/// Basic implementation (parsing + object construction)
pub fn basic_implementation() -> ImplementationConfig {
  ImplementationConfig(
    level: 3,
    supported_functions: [function_parse, function_build_hierarchy],
    supported_features: [feature_multiline],
    supported_behaviors: [
      behavior_crlf_normalize_to_lf,
      behavior_tabs_as_whitespace,
      behavior_toplevel_indent_strip,
    ],
    skip_behaviors: [
      behavior_crlf_preserve_literal,
      behavior_tabs_as_content,
      behavior_toplevel_indent_preserve,
    ],
    supported_variants: [variant_proposed_behavior],
  )
}

/// Reference-compliant full implementation
pub fn reference_compliant() -> ImplementationConfig {
  ImplementationConfig(
    level: 4,
    supported_functions: [
      function_parse,
      function_build_hierarchy,
      function_get_string,
      function_get_int,
      function_get_bool,
    ],
    supported_features: [],
    supported_behaviors: [
      behavior_crlf_normalize_to_lf,
      behavior_tabs_as_whitespace,
      behavior_boolean_strict,
      behavior_toplevel_indent_strip,
    ],
    skip_behaviors: [
      behavior_crlf_preserve_literal,
      behavior_tabs_as_content,
      behavior_boolean_lenient,
      behavior_toplevel_indent_preserve,
    ],
    supported_variants: [variant_reference_compliant],
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

/// Check if a variant is supported by the implementation
pub fn supports_variant(config: ImplementationConfig, variant: String) -> Bool {
  list.contains(config.supported_variants, variant)
}

/// Check if a test variant conflicts with the implementation's variant choice
/// Returns True if the test variant is in our supported list (compatible)
pub fn matches_variant(config: ImplementationConfig, variant: String) -> Bool {
  list.contains(config.supported_variants, variant)
}

/// Check if a test is compatible with the implementation
/// Returns True if the test can be run, False if it should be skipped
///
/// Per the official test-selection-guide.md:
/// - Functions: Filter - skip tests requiring unsupported functions
/// - Features: INFORMATIONAL ONLY - do NOT filter (used for gap reporting)
/// - Behaviors: Filter via conflicts field
/// - Variants: Filter via conflicts field
pub fn test_is_compatible(
  config: ImplementationConfig,
  required_functions: List(String),
  _required_features: List(String),
  required_behaviors: List(String),
  test_conflicts_behaviors: List(String),
  test_conflicts_variants: List(String),
) -> Bool {
  // Check all required functions are supported
  let functions_ok =
    list.all(required_functions, fn(f) { supports_function(config, f) })

  // NOTE: Features are INFORMATIONAL ONLY - do NOT filter based on features
  // Features are used for gap reporting, not test selection
  // See test-selection-guide.md: "Features are for reporting, not filtering"

  // Check all required behaviors are supported
  let behaviors_ok =
    list.all(required_behaviors, fn(b) { supports_behavior(config, b) })

  // Check that none of our behaviors conflict with the test's conflict list
  // If any of our supported_behaviors appear in test_conflicts_behaviors, skip the test
  let no_behavior_conflicts =
    !list.any(config.supported_behaviors, fn(our_behavior) {
      list.contains(test_conflicts_behaviors, our_behavior)
    })

  // Check that none of our variants conflict with the test's conflict list
  // If any of our supported_variants appear in test_conflicts_variants, skip the test
  let no_variant_conflicts =
    !list.any(config.supported_variants, fn(our_variant) {
      list.contains(test_conflicts_variants, our_variant)
    })

  // Check that none of the required behaviors are in our skip list
  let not_skipped =
    !list.any(required_behaviors, fn(b) { should_skip_behavior(config, b) })

  functions_ok
  && behaviors_ok
  && no_behavior_conflicts
  && no_variant_conflicts
  && not_skipped
}

/// Check compatibility with the official generated test format (GeneratedTestCase)
/// This is the preferred function for the new flat format
pub fn test_is_compatible_generated(
  config: ImplementationConfig,
  test_case: generated_test_types.GeneratedTestCase,
) -> Bool {
  test_is_compatible(
    config,
    test_case.functions,
    test_case.features,
    test_case.behaviors,
    test_case.conflicts.behaviors,
    test_case.conflicts.variants,
  )
}

/// Get a concise summary of implementation capabilities
pub fn get_summary(config: ImplementationConfig) -> String {
  let function_count = list.length(config.supported_functions)
  let feature_count = list.length(config.supported_features)
  let behavior_count = list.length(config.supported_behaviors)
  let skip_count = list.length(config.skip_behaviors)
  let variant_str = string.join(config.supported_variants, ", ")

  "CCL Implementation (variants: "
  <> variant_str
  <> ")\n"
  <> "  Functions: "
  <> string.inspect(function_count)
  <> " supported\n"
  <> "  Features: "
  <> string.inspect(feature_count)
  <> " (informational only)\n"
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
  let has_parse = list.contains(functions, function_parse)
  let has_build_hierarchy = list.contains(functions, function_build_hierarchy)
  let has_typed_access =
    list.contains(functions, function_get_string)
    || list.contains(functions, function_get_int)
    || list.contains(functions, function_get_bool)

  case has_parse, has_build_hierarchy, has_typed_access {
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
/// functions = ["parse", "build_hierarchy", "get_string"]
/// features = ["comments", "multiline"]  # informational only
/// behaviors = ["crlf_normalize_to_lf", "boolean_lenient"]
///
/// [test_selection]
/// skip_behaviors = ["tabs_as_content", "crlf_preserve_literal"]
/// variants = ["proposed_behavior"]
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

  // Helper to extract string array from TOML
  let get_string_array = fn(path: List(String)) {
    tom.get_array(parsed, path)
    |> result.map(fn(arr) {
      list.filter_map(arr, fn(item) {
        case item {
          tom.String(s) -> Ok(s)
          _ -> Error(Nil)
        }
      })
    })
    |> result.unwrap([])
  }

  // Extract capabilities
  let functions = get_string_array(["capabilities", "functions"])
  let features = get_string_array(["capabilities", "features"])
  let behaviors = get_string_array(["capabilities", "behaviors"])

  // Extract test_selection
  let skip_behaviors = get_string_array(["test_selection", "skip_behaviors"])

  // Support both "variants" (array) and legacy "variant" (single string)
  let variants = case get_string_array(["test_selection", "variants"]) {
    [] -> {
      // Fall back to legacy single variant
      case tom.get_string(parsed, ["test_selection", "variant"]) {
        Ok(v) -> [v]
        Error(_) -> [variant_proposed_behavior]
      }
    }
    v -> v
  }

  Ok(ImplementationConfig(
    level: calculate_level(functions),
    supported_functions: functions,
    supported_features: features,
    supported_behaviors: behaviors,
    skip_behaviors: skip_behaviors,
    supported_variants: variants,
  ))
}

/// Save implementation config to a TOML file
pub fn save_to_toml(
  config: ImplementationConfig,
  file_path: String,
) -> Result(Nil, String) {
  // Helper to format string array for TOML
  let format_array = fn(items: List(String)) {
    items
    |> list.map(fn(s) { "\"" <> s <> "\"" })
    |> string.join(", ")
  }

  let toml_content =
    "# CCL Implementation Configuration\n"
    <> "# Function/behavior/variant names follow the official ccl-test-data schema\n"
    <> "implementation_name = \"ccl_gleam\"\n"
    <> "\n"
    <> "[capabilities]\n"
    <> "functions = ["
    <> format_array(config.supported_functions)
    <> "]\n"
    <> "features = ["
    <> format_array(config.supported_features)
    <> "]  # informational only\n"
    <> "behaviors = ["
    <> format_array(config.supported_behaviors)
    <> "]\n"
    <> "\n"
    <> "[test_selection]\n"
    <> "skip_behaviors = ["
    <> format_array(config.skip_behaviors)
    <> "]\n"
    <> "variants = ["
    <> format_array(config.supported_variants)
    <> "]\n"

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
