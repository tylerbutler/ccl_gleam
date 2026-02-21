/// Filter tests based on implementation capabilities.
/// 
/// Follows the CCL test runner implementation guide:
/// - Check that all required functions are implemented
/// - Check that all required features are supported
/// - Check behavior compatibility (test requires at least one matching behavior)
/// - Check variant compatibility
/// - Check behavior conflicts (skip tests that conflict with chosen behaviors)
import gleam/list
import gleam/string
import test_types.{
  type Conflicts, type ImplementationConfig, type TestCase, Conflicts,
  NoConflicts,
}

/// Check if a test case is compatible with the implementation config.
pub fn is_compatible(config: ImplementationConfig, tc: TestCase) -> Bool {
  let has_functions =
    list.all(tc.functions, fn(f) { list.contains(config.functions, f) })

  let has_features =
    list.all(tc.features, fn(f) { list.contains(config.features, f) })

  let behavior_ok = check_behaviors(config.behaviors, tc.behaviors)
  let variant_ok = check_variants_bool(config.variants, tc.variants)
  let no_conflicts = check_no_conflicts(config.behaviors, tc.conflicts)

  has_functions && has_features && behavior_ok && variant_ok && no_conflicts
}

fn check_behaviors(
  config_behaviors: List(String),
  test_behaviors: List(String),
) -> Bool {
  case test_behaviors {
    [] -> True
    required -> list.any(required, fn(b) { list.contains(config_behaviors, b) })
  }
}

fn check_variants_bool(
  config_variants: List(String),
  test_variants: List(String),
) -> Bool {
  case test_variants {
    [] -> True
    required -> list.any(required, fn(v) { list.contains(config_variants, v) })
  }
}

/// Check that none of the implementation's chosen behaviors appear in the
/// test's conflicts list.
fn check_no_conflicts(
  config_behaviors: List(String),
  conflicts: Conflicts,
) -> Bool {
  case conflicts {
    NoConflicts -> True
    Conflicts(conflicting_behaviors) ->
      !list.any(conflicting_behaviors, fn(b) {
        list.contains(config_behaviors, b)
      })
  }
}

/// Filter a list of tests to only those compatible with the config.
pub fn filter_tests(
  config: ImplementationConfig,
  tests: List(TestCase),
) -> List(TestCase) {
  list.filter(tests, fn(tc) { is_compatible(config, tc) })
}

/// Get skip reason if test case is not compatible.
pub fn get_skip_reason(
  config: ImplementationConfig,
  tc: TestCase,
) -> Result(Nil, String) {
  // Check functions
  let missing_functions =
    tc.functions
    |> list.filter(fn(f) { !list.contains(config.functions, f) })

  case missing_functions {
    [_, ..] ->
      Error("Missing functions: " <> string.join(missing_functions, ", "))
    [] -> check_features_skip(config, tc)
  }
}

fn check_features_skip(
  config: ImplementationConfig,
  tc: TestCase,
) -> Result(Nil, String) {
  let missing_features =
    tc.features
    |> list.filter(fn(f) { !list.contains(config.features, f) })

  case missing_features {
    [_, ..] ->
      Error("Missing features: " <> string.join(missing_features, ", "))
    [] -> check_behaviors_skip(config, tc)
  }
}

fn check_behaviors_skip(
  config: ImplementationConfig,
  tc: TestCase,
) -> Result(Nil, String) {
  case tc.behaviors {
    [] -> check_conflicts_skip(config, tc)
    required -> {
      let has_behavior =
        list.any(required, fn(b) { list.contains(config.behaviors, b) })
      case has_behavior {
        True -> check_conflicts_skip(config, tc)
        False ->
          Error("Incompatible behavior: " <> string.join(required, ", "))
      }
    }
  }
}

fn check_conflicts_skip(
  config: ImplementationConfig,
  tc: TestCase,
) -> Result(Nil, String) {
  case tc.conflicts {
    NoConflicts -> check_variants_skip(config, tc)
    Conflicts(conflicting_behaviors) -> {
      let has_conflict =
        list.any(conflicting_behaviors, fn(b) {
          list.contains(config.behaviors, b)
        })
      case has_conflict {
        True ->
          Error(
            "Behavior conflict: "
            <> string.join(conflicting_behaviors, ", "),
          )
        False -> check_variants_skip(config, tc)
      }
    }
  }
}

fn check_variants_skip(
  config: ImplementationConfig,
  tc: TestCase,
) -> Result(Nil, String) {
  case tc.variants {
    [] -> Ok(Nil)
    req_variants -> {
      let has_variant =
        list.any(req_variants, fn(v) { list.contains(config.variants, v) })
      case has_variant {
        True -> Ok(Nil)
        False -> Error("Missing variant: " <> string.join(req_variants, ", "))
      }
    }
  }
}

/// Create an empty config that assumes nothing is implemented.
/// Use this as a base and let the implementation provide its own config.
pub fn empty_config() -> ImplementationConfig {
  test_types.ImplementationConfig(
    functions: [],
    behaviors: [],
    variants: [],
    features: [],
  )
}

/// Create a basic config for parse-only implementations.
pub fn parse_only_config() -> ImplementationConfig {
  test_types.ImplementationConfig(
    functions: ["parse", "print"],
    behaviors: ["crlf_normalize_to_lf", "toplevel_indent_strip"],
    variants: ["reference_compliant"],
    features: [],
  )
}

/// Create a config for implementations with object construction.
pub fn basic_config() -> ImplementationConfig {
  test_types.ImplementationConfig(
    functions: ["parse", "print", "build_hierarchy"],
    behaviors: ["crlf_normalize_to_lf", "toplevel_indent_strip"],
    variants: ["reference_compliant"],
    features: [],
  )
}

/// Create a full implementation config.
pub fn full_config() -> ImplementationConfig {
  test_types.ImplementationConfig(
    functions: [
      "parse", "print", "canonical_format", "build_hierarchy", "get_string",
      "get_int", "get_bool", "get_float", "get_list", "filter", "compose",
    ],
    behaviors: [
      "crlf_normalize_to_lf",
      "toplevel_indent_strip",
      "boolean_strict",
      "list_coercion_disabled",
    ],
    variants: ["reference_compliant"],
    features: ["comments", "multiline", "empty_keys", "unicode"],
  )
}
