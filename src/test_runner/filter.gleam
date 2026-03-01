/// Filter tests based on implementation capabilities
import gleam/list
import test_runner/types.{type ImplementationConfig, type TestCase}

/// Check if a test case is compatible with the implementation config.
/// config.behaviors lists ALL behaviors we can adapt to (both sides of pairs).
/// The runner derives the right options per-test from the test's behaviors.
pub fn is_compatible(config: ImplementationConfig, tc: TestCase) -> Bool {
  // All required functions must be implemented
  let has_functions =
    list.all(tc.functions, fn(f) { list.contains(config.functions, f) })

  // Check variant compatibility (if test requires a variant, config must have it)
  let variant_ok = case tc.variants {
    [] -> True
    required -> list.any(required, fn(v) { list.contains(config.variants, v) })
  }

  // Check behavior compatibility — we must support at least one required behavior
  let behavior_ok = case tc.behaviors {
    [] -> True
    required ->
      list.any(required, fn(b) { list.contains(config.behaviors, b) })
  }

  has_functions && variant_ok && behavior_ok
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
  // No conflict checking — config.behaviors lists ALL behaviors we can adapt
  // to, and the runner derives the right options per-test. We only skip if a
  // test requires a behavior we can't support at all.

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
      // Check variants
      case tc.variants {
        [] -> check_behaviors_supported(config, tc)
        req_variants -> {
          let has_variant =
            list.any(req_variants, fn(v) {
              list.contains(config.variants, v)
            })
          case has_variant {
            True -> check_behaviors_supported(config, tc)
            False -> Error("Missing variant: " <> format_list(req_variants))
          }
        }
      }
    }
  }
}

/// Check that we support at least one of the test's required behaviors.
/// config.behaviors is the full set of behaviors we can adapt to.
fn check_behaviors_supported(
  config: ImplementationConfig,
  tc: TestCase,
) -> Result(Nil, String) {
  case tc.behaviors {
    [] -> Ok(Nil)
    required -> {
      let has_any =
        list.any(required, fn(b) { list.contains(config.behaviors, b) })
      case has_any {
        True -> Ok(Nil)
        False ->
          Error("Unsupported behavior: " <> format_list(required))
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
    behaviors: ["crlf_normalize_to_lf", "toplevel_indent_strip"],
    variants: ["reference_compliant"],
    features: [],
  )
}

/// Create a config for implementations with object construction
pub fn basic_config() -> ImplementationConfig {
  types.ImplementationConfig(
    functions: ["parse", "print", "build_hierarchy"],
    behaviors: ["crlf_normalize_to_lf", "toplevel_indent_strip"],
    variants: ["reference_compliant"],
    features: [],
  )
}

/// Create a full implementation config.
/// behaviors lists ALL behaviors we can adapt to (both sides of supported pairs).
/// The runner derives the right options per-test from each test's behaviors.
pub fn full_config() -> ImplementationConfig {
  types.ImplementationConfig(
    functions: [
      "parse", "parse_indented", "print", "build_hierarchy", "get_string",
      "get_int", "get_bool", "get_float", "get_list", "filter", "compose",
      "round_trip",
    ],
    behaviors: [
      // Line endings — both supported
      "crlf_normalize_to_lf", "crlf_preserve_literal",
      // Continuation baseline — both supported
      "toplevel_indent_strip", "toplevel_indent_preserve",
      // Boolean parsing — both supported
      "boolean_strict", "boolean_lenient",
      // Tab handling — both supported
      "tabs_as_whitespace", "tabs_as_content",
      // List coercion — both supported
      "list_coercion_disabled", "list_coercion_enabled",
      // Array ordering — both supported
      "array_order_insertion", "array_order_lexicographic",
      // Output indentation
      "indent_spaces",
    ],
    variants: ["reference_compliant"],
    features: ["comments", "multiline", "empty_keys", "unicode"],
  )
}
