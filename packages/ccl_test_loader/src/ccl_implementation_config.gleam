/// Centralized configuration for CCL implementation support
/// This module defines which features, behaviors, and variants are supported
/// by this CCL implementation, and provides filtering based on conflicts
import gleam/list
import gleam/string

/// Simplified CCL implementation configuration
/// Focuses on essential filtering needs for progressive testing
pub type ImplementationConfig {
  ImplementationConfig(
    /// CCL implementation level (1-4)
    level: Int,
    /// Supported functions (parse, make-objects, get-string, etc.)
    supported_functions: List(String),
    /// Supported optional features (comments, dotted-keys, unicode)
    supported_features: List(String),
    /// Variant choice (proposed-behavior, reference-compliant)
    variant_choice: String,
  )
}

/// Level 4 implementation with all CCL functions
pub fn full_implementation() -> ImplementationConfig {
  ImplementationConfig(
    level: 4,
    supported_functions: [
      "parse",
      // Level 1: Basic parsing
      "make-objects",
      // Level 3: Hierarchy construction
      "get-string",
      // Level 4: Typed access
      "get-int",
      "get-bool",
      "get-float",
      "get-list",
    ],
    supported_features: [
      "comments",
      // Optional comment syntax
      "dotted-keys",
      // Dotted key expansion
      "unicode",
      // Unicode content support
    ],
    variant_choice: "proposed-behavior",
  )
}

/// Level 1 parsing-only implementation
pub fn parse_only() -> ImplementationConfig {
  ImplementationConfig(
    level: 1,
    supported_functions: ["parse"],
    supported_features: [],
    // No optional features
    variant_choice: "reference-compliant",
  )
}

/// Level 3 implementation (parsing + object construction)
pub fn basic_implementation() -> ImplementationConfig {
  ImplementationConfig(
    level: 3,
    supported_functions: ["parse", "make-objects"],
    supported_features: ["dotted-keys"],
    // Usually needed with objects
    variant_choice: "proposed-behavior",
  )
}

/// Reference-compliant Level 4 implementation
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
    // Minimal feature set
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

/// Check if a test matches the implementation's variant choice
pub fn matches_variant(config: ImplementationConfig, variant: String) -> Bool {
  config.variant_choice == variant
}

/// Get a concise summary of implementation capabilities
pub fn get_summary(config: ImplementationConfig) -> String {
  let function_count = list.length(config.supported_functions)
  let feature_count = list.length(config.supported_features)

  "CCL Level "
  <> string.inspect(config.level)
  <> " ("
  <> config.variant_choice
  <> ")\n"
  <> "  Functions: "
  <> string.inspect(function_count)
  <> " supported\n"
  <> "  Features: "
  <> string.inspect(feature_count)
  <> " optional\n"
}
