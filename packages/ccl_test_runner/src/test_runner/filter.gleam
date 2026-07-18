/// Filter tests based on implementation capabilities
import gleam/list
import gleam/result
import gleam/string
import test_runner/types.{type ImplementationConfig, type TestCase}

/// Check if a test case is compatible with the implementation config.
pub fn is_compatible(config: ImplementationConfig, tc: TestCase) -> Bool {
  result.is_ok(get_skip_reason(config, tc))
}

/// Get skip reason if test case is not compatible.
/// config.behaviours lists ALL behaviours we can adapt to (both sides of
/// pairs); the runner derives the right options per-test. We only skip if a
/// test requires something we can't support at all.
pub fn get_skip_reason(
  config: ImplementationConfig,
  tc: TestCase,
) -> Result(Nil, String) {
  // The validation field is the actual function being tested, so it must be
  // in the supported functions list
  case list.contains(config.functions, tc.validation) {
    False -> Error("Unsupported validation function: " <> tc.validation)
    True -> get_skip_reason_inner(config, tc)
  }
}

fn get_skip_reason_inner(
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
    [] -> {
      // Check variants
      case tc.variants {
        [] -> check_behaviours_supported(config, tc)
        req_variants -> {
          let has_variant =
            list.any(req_variants, fn(v) { list.contains(config.variants, v) })
          case has_variant {
            True -> check_behaviours_supported(config, tc)
            False ->
              Error("Missing variant: " <> string.join(req_variants, ", "))
          }
        }
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
        False -> Error("Unsupported behaviour: " <> string.join(required, ", "))
      }
    }
  }
}

/// Create a full implementation config.
/// behaviours lists ALL behaviours we can adapt to (both sides of supported pairs).
/// The runner derives the right options per-test from each test's behaviours.
pub fn full_config() -> ImplementationConfig {
  types.ImplementationConfig(
    functions: [
      "parse", "parse_indented", "print", "build_hierarchy", "get_string",
      "get_int", "get_bool", "get_float", "get_list", "filter", "compose",
      "round_trip",
    ],
    behaviours: [
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
      // Delimiter strategy — both supported
      "delimiter_first_equals", "delimiter_prefer_spaced",
      // Output indentation
      "indent_spaces",
    ],
    variants: ["reference_compliant"],
    features: ["comments", "multiline", "empty_keys", "unicode"],
  )
}
