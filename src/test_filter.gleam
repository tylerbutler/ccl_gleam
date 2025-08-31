/// Filter tests based on implementation capabilities
import gleam/list
import test_types.{type ImplementationConfig, type TestCase}

/// Check if a test case is compatible with the implementation config
pub fn is_compatible(config: ImplementationConfig, tc: TestCase) -> Bool {
  // All required functions must be implemented
  let has_functions =
    list.all(tc.functions, fn(f) { list.contains(config.functions, f) })

  // Check behavior compatibility
  let behavior_ok = check_behaviors(config.behaviors, tc.behaviors)

  // Check variant compatibility (if test requires a variant, config must have it)
  let variant_ok = case tc.variants {
    [] -> True
    required -> list.any(required, fn(v) { list.contains(config.variants, v) })
  }

  has_functions && behavior_ok && variant_ok
}

/// Check that no conflicting behaviors exist
fn check_behaviors(
  config_behaviors: List(String),
  test_behaviors: List(String),
) -> Bool {
  case test_behaviors {
    [] -> True
    required -> {
      // Test specifies required behaviors, config must have at least one
      list.any(required, fn(b) { list.contains(config_behaviors, b) })
    }
  }
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
      // Check behaviors
      case tc.behaviors {
        [] -> Ok(Nil)
        required -> {
          let has_behavior =
            list.any(required, fn(b) { list.contains(config.behaviors, b) })
          case has_behavior {
            True -> {
              // Check variants
              case tc.variants {
                [] -> Ok(Nil)
                req_variants -> {
                  let has_variant =
                    list.any(req_variants, fn(v) {
                      list.contains(config.variants, v)
                    })
                  case has_variant {
                    True -> Ok(Nil)
                    False ->
                      Error("Missing variant: " <> format_list(req_variants))
                  }
                }
              }
            }
            False -> Error("Incompatible behavior: " <> format_list(required))
          }
        }
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
  test_types.ImplementationConfig(
    functions: ["parse", "print"],
    behaviors: ["crlf_normalize_to_lf", "toplevel_indent_strip"],
    variants: ["reference_compliant"],
    features: [],
  )
}

/// Create a config for implementations with object construction
pub fn basic_config() -> ImplementationConfig {
  test_types.ImplementationConfig(
    functions: ["parse", "print", "build_hierarchy"],
    behaviors: ["crlf_normalize_to_lf", "toplevel_indent_strip"],
    variants: ["reference_compliant"],
    features: [],
  )
}

/// Create a full implementation config
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
