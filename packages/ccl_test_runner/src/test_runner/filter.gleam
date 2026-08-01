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

  // Check variant compatibility (if test requires a variant, config must have it)
  let variant_ok = case tc.variants {
    [] -> True
    required -> list.any(required, fn(v) { list.contains(config.variants, v) })
  }

  // Check behaviour compatibility — a test's behaviours are the specific
  // combination it exercises, so we must support all of them, not just one.
  let behaviour_ok = case tc.behaviours {
    [] -> True
    required ->
      list.all(required, fn(b) { list.contains(config.behaviours, b) })
  }

  // Features are declarative for capability reporting — not a filter gate.
  // Tests requiring undeclared features still run; failures surface the gap.
  has_functions && variant_ok && behaviour_ok
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
      // Features are declarative (capability reporting), not a filter gate:
      // tests requiring features we don't declare still run, and any failures
      // surface the capability gap.
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
  }
}

/// Check that we support every behaviour a test declares. A test's
/// `behaviours` list is the specific combination it exercises (e.g.
/// `["indent_tabs", "multiline_values"]` means both at once), not a menu of
/// alternatives — so one unsupported behaviour (e.g. `indent_tabs`, which
/// this implementation doesn't declare) must skip the test even when other
/// listed behaviours are supported.
fn check_behaviours_supported(
  config: ImplementationConfig,
  tc: TestCase,
) -> Result(Nil, String) {
  case tc.behaviours {
    [] -> Ok(Nil)
    required -> {
      let missing =
        list.filter(required, fn(b) { !list.contains(config.behaviours, b) })
      case missing {
        [] -> Ok(Nil)
        _ -> Error("Unsupported behaviour: " <> format_list(missing))
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
      "parse", "parse_indented", "print", "build_hierarchy", "build_model",
      "get_string", "get_int", "get_bool", "get_float", "get_list", "filter",
      "compose", "round_trip", "canonical_format",
    ],
    behaviours: [
      // Line endings — both supported
      "crlf_normalize_to_lf", "crlf_preserve_literal",
      // Boolean parsing — both supported
      "boolean_strict", "boolean_lenient",
      // Continuation tab handling — both supported
      "continuation_tab_preserve", "continuation_tab_to_space",
      // Value tab handling — both supported
      "tabs_as_content", "tabs_as_whitespace",
      // List coercion — both supported
      "list_coercion_disabled", "list_coercion_enabled",
      // Array ordering — both supported
      "array_order_insertion", "array_order_lexicographic",
      // Delimiter strategy — both supported
      "delimiter_first_equals", "delimiter_prefer_spaced",
      // Output indentation — only space-indentation is implemented;
      // `indent_tabs` has no test that passes and is deliberately not
      // declared (see CLAUDE.md Known gaps)
      "indent_spaces",
      // Top-level baseline — both supported (also declared as a feature;
      // ccl-test-data v1.0.0 tags it both ways depending on the test)
      "toplevel_indent_strip", "toplevel_indent_preserve",
      // Multi-line value semantics
      "multiline_values",
      // Path traversal in typed accessors
      "path_traversal",
    ],
    variants: ["reference_compliant"],
    features: [
      "comments", "empty_keys", "multiline_continuation", "multiline_keys",
      "optional_typed_accessors", "toplevel_indent_strip", "unicode",
      "whitespace",
    ],
  )
}
