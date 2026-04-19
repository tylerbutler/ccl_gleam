/// Filter tests based on implementation capabilities
import gleam/list
import test_runner/types.{type ImplementationConfig, type TestCase}

/// Check if a test case is compatible with the implementation config.
/// config.behaviours lists ALL behaviours we can adapt to (both sides of pairs).
/// The runner derives the right options per-test from the test's behaviours.
pub fn is_compatible(config: ImplementationConfig, tc: TestCase) -> Bool {
  // All required functions must be implemented
  let has_functions =
    list.all(tc.functions, fn(f) { list.contains(config.functions, f) })

  // All required features must be declared (features are capabilities, not paired choices)
  let has_features =
    list.all(tc.features, fn(f) { list.contains(config.features, f) })

  // Check variant compatibility (if test requires a variant, config must have it)
  let variant_ok = case tc.variants {
    [] -> True
    required -> list.any(required, fn(v) { list.contains(config.variants, v) })
  }

  // Check behaviour compatibility — we must support at least one required behaviour
  let behaviour_ok = case tc.behaviours {
    [] -> True
    required ->
      list.any(required, fn(b) { list.contains(config.behaviours, b) })
  }

  has_functions && has_features && variant_ok && behaviour_ok
}

/// Filter a list of tests to only those compatible with the config
pub fn filter_tests(
  config: ImplementationConfig,
  tests: List(TestCase),
) -> List(TestCase) {
  list.filter(tests, fn(tc) { is_compatible(config, tc) })
}

/// Get skip reason if test case is not compatible
pub fn get_skip_reason(
  config: ImplementationConfig,
  tc: TestCase,
) -> Result(Nil, String) {
  // Check validation type: the validation field is the actual function being
  // tested, so it must be in the supported functions list
  case list.contains(config.functions, tc.validation) {
    False -> Error("Unsupported validation function: " <> tc.validation)
    True -> get_skip_reason_inner(config, tc)
  }
}

fn get_skip_reason_inner(
  config: ImplementationConfig,
  tc: TestCase,
) -> Result(Nil, String) {
  // No conflict checking — config.behaviours lists ALL behaviours we can adapt
  // to, and the runner derives the right options per-test. We only skip if a
  // test requires a behaviour we can't support at all.

  // Check functions
  let missing_functions =
    tc.functions
    |> list.filter(fn(f) { !list.contains(config.functions, f) })

  case missing_functions {
    [first, ..rest] -> {
      let funcs = [first, ..rest]
      Error("Missing functions: " <> format_list(funcs))
    }
    [] -> {
      // Check features — features are capability declarations (not paired choices),
      // so every feature the test requires must be declared in the config.
      let missing_features =
        tc.features
        |> list.filter(fn(f) { !list.contains(config.features, f) })
      case missing_features {
        [first, ..rest] ->
          Error("Missing features: " <> format_list([first, ..rest]))
        [] -> check_variants_and_behaviours(config, tc)
      }
    }
  }
}

fn check_variants_and_behaviours(
  config: ImplementationConfig,
  tc: TestCase,
) -> Result(Nil, String) {
  case tc.variants {
    [] -> check_behaviours_supported(config, tc)
    req_variants -> {
      let has_variant =
        list.any(req_variants, fn(v) { list.contains(config.variants, v) })
      case has_variant {
        True -> check_behaviours_supported(config, tc)
        False -> Error("Missing variant: " <> format_list(req_variants))
      }
    }
  }
}

/// Check that we support at least one of the test's required behaviours.
/// config.behaviours is the full set of behaviours we can adapt to.
fn check_behaviours_supported(
  config: ImplementationConfig,
  tc: TestCase,
) -> Result(Nil, String) {
  case tc.behaviours {
    [] -> Ok(Nil)
    required -> {
      let has_any =
        list.any(required, fn(b) { list.contains(config.behaviours, b) })
      case has_any {
        True -> Ok(Nil)
        False -> Error("Unsupported behaviour: " <> format_list(required))
      }
    }
  }
}

fn format_list(items: List(String)) -> String {
  case items {
    [] -> ""
    [x] -> x
    [x, y] -> x <> ", " <> y
    [x, ..rest] -> x <> ", " <> format_list(rest)
  }
}

/// Create a basic config for parse-only implementations
pub fn parse_only_config() -> ImplementationConfig {
  types.ImplementationConfig(
    functions: ["parse", "print"],
    behaviours: ["crlf_normalize_to_lf"],
    variants: ["reference_compliant"],
    features: ["toplevel_indent_strip"],
  )
}

/// Create a config for implementations with object construction
pub fn basic_config() -> ImplementationConfig {
  types.ImplementationConfig(
    functions: ["parse", "parse_indented", "print", "build_hierarchy"],
    behaviours: ["crlf_normalize_to_lf"],
    variants: ["reference_compliant"],
    features: ["toplevel_indent_strip"],
  )
}

/// Create a full implementation config.
/// behaviours lists ALL behaviours we can adapt to (both sides of supported pairs).
/// The runner derives the right options per-test from each test's behaviours.
pub fn full_config() -> ImplementationConfig {
  types.ImplementationConfig(
    functions: [
      "parse", "parse_indented", "print", "build_hierarchy", "get_string",
      "get_int", "get_bool", "get_float", "get_list", "filter", "compose",
      "round_trip", "canonical_format",
    ],
    behaviours: [
      // Line endings — both supported
      "crlf_normalize_to_lf", "crlf_preserve_literal",
      // Boolean parsing — both supported
      "boolean_strict", "boolean_lenient",
      // Continuation tab handling — both supported
      "continuation_tab_preserve", "continuation_tab_to_space",
      // List coercion — both supported
      "list_coercion_disabled", "list_coercion_enabled",
      // Array ordering — both supported
      "array_order_insertion", "array_order_lexicographic",
      // Delimiter strategy — both supported
      "delimiter_first_equals", "delimiter_prefer_spaced",
      // Output indentation — both supported
      "indent_spaces", "indent_tabs",
      // Multi-line value semantics
      "multiline_values",
      // Path traversal in typed accessors
      "path_traversal",
    ],
    variants: ["reference_compliant"],
    features: [
      "comments", "empty_keys", "multiline_continuation",
      "optional_typed_accessors", "toplevel_indent_strip", "unicode",
      "whitespace",
    ],
  )
}
