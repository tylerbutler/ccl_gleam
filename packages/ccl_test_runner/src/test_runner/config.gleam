/// Load implementation configuration from a ccl-config.yaml file.
///
/// Reads the YAML file and maps it to an ImplementationConfig for test filtering.
/// The YAML format conforms to the ccl-config-schema.json defined in ccl-test-data.
import gleam/result
import simplifile
import test_runner/types.{type ImplementationConfig, ImplementationConfig}
import yay

/// Default path to ccl-config.yaml, relative to the project root
pub const default_config_path = "ccl-config.yaml"

/// Load an ImplementationConfig from a YAML file.
///
/// Returns Ok(config) on success, or Error(reason) if the file cannot be read
/// or parsed. The YAML file uses "behaviors" (US spelling) which is mapped to
/// the ImplementationConfig "behaviours" field (UK spelling) for consistency
/// with the rest of the codebase.
pub fn load_config(path: String) -> Result(ImplementationConfig, String) {
  use content <- result.try(
    simplifile.read(path)
    |> result.map_error(fn(e) {
      "Failed to read config file "
      <> path
      <> ": "
      <> simplifile.describe_error(e)
    }),
  )

  use docs <- result.try(
    yay.parse_string(content)
    |> result.map_error(fn(_e) { "Failed to parse YAML in " <> path }),
  )

  case docs {
    [doc] -> parse_config_doc(doc)
    _ -> Error("Expected exactly one YAML document in " <> path)
  }
}

/// Parse a YAML document into an ImplementationConfig.
fn parse_config_doc(doc: yay.Document) -> Result(ImplementationConfig, String) {
  let root = yay.document_root(doc)

  // functions is required
  use functions <- result.try(
    yay.extract_string_list(root, "functions")
    |> result.map_error(fn(_e) {
      "Missing or invalid 'functions' field in config"
    }),
  )

  // All other fields are optional, defaulting to empty lists
  let features = extract_optional_string_list(root, "features")
  let behaviours = extract_optional_string_list(root, "behaviors")
  let variants = extract_optional_string_list(root, "variants")

  Ok(ImplementationConfig(
    functions: functions,
    behaviours: behaviours,
    variants: variants,
    features: features,
  ))
}

/// Extract an optional string list field, defaulting to [] if missing.
fn extract_optional_string_list(root: yay.Node, key: String) -> List(String) {
  case yay.extract_string_list(root, key) {
    Ok(values) -> values
    Error(_) -> []
  }
}

/// Load config from the default path, returning a descriptive error if not found.
pub fn load_default_config() -> Result(ImplementationConfig, String) {
  load_config(default_config_path)
}
