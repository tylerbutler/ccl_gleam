import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import simplifile

/// Configuration for test runner
pub type TestConfig {
  TestConfig(
    /// Paths to test files or directories
    test_paths: List(String),
    /// Whether to search directories recursively
    recursive: Bool,
    /// Filter for specific test suites
    suite_filter: Option(String),
    /// Filter for specific test tags
    tag_filter: Option(List(String)),
  )
}

/// Default test configuration
pub fn default_config() -> TestConfig {
  TestConfig(
    test_paths: ["../ccl-test-data/tests"],
    recursive: False,
    suite_filter: None,
    tag_filter: None,
  )
}

/// Create a config from a single file path
pub fn from_file(path: String) -> TestConfig {
  TestConfig(
    test_paths: [path],
    recursive: False,
    suite_filter: None,
    tag_filter: None,
  )
}

/// Create a config from a directory path
pub fn from_directory(path: String) -> TestConfig {
  TestConfig(
    test_paths: [path],
    recursive: False,
    suite_filter: None,
    tag_filter: None,
  )
}

/// Create a config from multiple paths
pub fn from_paths(paths: List(String)) -> TestConfig {
  TestConfig(
    test_paths: paths,
    recursive: False,
    suite_filter: None,
    tag_filter: None,
  )
}

/// Add a path to the configuration
pub fn add_path(config: TestConfig, path: String) -> TestConfig {
  TestConfig(..config, test_paths: list.append(config.test_paths, [path]))
}

/// Set whether to search recursively
pub fn set_recursive(config: TestConfig, recursive: Bool) -> TestConfig {
  TestConfig(..config, recursive: recursive)
}

/// Set suite filter
pub fn set_suite_filter(config: TestConfig, filter: String) -> TestConfig {
  TestConfig(..config, suite_filter: Some(filter))
}

/// Set tag filter
pub fn set_tag_filter(config: TestConfig, tags: List(String)) -> TestConfig {
  TestConfig(..config, tag_filter: Some(tags))
}

/// Discover all test files based on configuration
pub fn discover_test_files(config: TestConfig) -> List(String) {
  config.test_paths
  |> list.flat_map(fn(path) { discover_files_in_path(path, config.recursive) })
  |> list.unique
}

/// Discover test files in a specific path
fn discover_files_in_path(path: String, recursive: Bool) -> List(String) {
  // Check if path is a file or directory
  case string.ends_with(path, ".json") {
    True -> {
      // It's a file, check if it exists
      case simplifile.is_file(path) {
        Ok(True) -> [path]
        _ -> []
      }
    }
    False -> {
      // It's a directory, list files
      case simplifile.read_directory(path) {
        Ok(entries) -> {
          entries
          |> list.flat_map(fn(entry) {
            let full_path = path <> "/" <> entry
            case string.ends_with(entry, ".json") {
              True -> {
                // Skip schema and pretty-print files
                case
                  string.starts_with(entry, "schema")
                  || string.starts_with(entry, "pretty-print")
                {
                  True -> []
                  False -> [full_path]
                }
              }
              False -> {
                // If recursive and it's a directory, explore it
                case recursive {
                  True -> {
                    case simplifile.is_directory(full_path) {
                      Ok(True) -> discover_files_in_path(full_path, True)
                      _ -> []
                    }
                  }
                  False -> []
                }
              }
            }
          })
        }
        Error(_) -> []
      }
    }
  }
}

/// Get config from environment variables
pub fn from_env() -> TestConfig {
  // Check for CCL_TEST_PATH environment variable
  case get_env("CCL_TEST_PATH") {
    Some(path) -> {
      // Split by colon for multiple paths (Unix-style)
      let paths = string.split(path, ":")
      TestConfig(
        test_paths: paths,
        recursive: get_env_bool("CCL_TEST_RECURSIVE", False),
        suite_filter: get_env("CCL_TEST_SUITE"),
        tag_filter: case get_env("CCL_TEST_TAGS") {
          Some(tags) -> Some(string.split(tags, ","))
          None -> None
        },
      )
    }
    None -> default_config()
  }
}

/// Helper to get environment variable (simplified for now)
fn get_env(_name: String) -> Option(String) {
  // In a real implementation, we'd use erlang:get_env or similar
  // For now, return None to use defaults
  None
}

/// Helper to get boolean environment variable
fn get_env_bool(_name: String, default: Bool) -> Bool {
  // In a real implementation, we'd check the env var
  default
}