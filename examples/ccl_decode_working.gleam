// CCL High-Level Decode API - Working Version  
// Simplified but functional approach to demonstrate the concept

import ccl_core
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

// === DECODE TYPES ===

pub type DecodeError {
  FieldNotFound(field: String)
  InvalidFormat(value: String, expected_type: String)
}

pub type Decoder(a) =
  fn(ccl_core.CCL, String) -> Result(a, DecodeError)

// === CORE DECODERS ===

pub fn string_decoder() -> Decoder(String) {
  fn(ccl: ccl_core.CCL, path: String) -> Result(String, DecodeError) {
    case ccl_core.get_value(ccl, path) {
      Ok(value) -> Ok(value)
      Error(_) -> Error(FieldNotFound(path))
    }
  }
}

pub fn int_decoder() -> Decoder(Int) {
  fn(ccl: ccl_core.CCL, path: String) -> Result(Int, DecodeError) {
    case ccl_core.get_value(ccl, path) {
      Ok(value) ->
        case int.parse(string.trim(value)) {
          Ok(parsed_int) -> Ok(parsed_int)
          Error(_) -> Error(InvalidFormat(value, "Int"))
        }
      Error(_) -> Error(FieldNotFound(path))
    }
  }
}

pub fn bool_decoder() -> Decoder(Bool) {
  fn(ccl: ccl_core.CCL, path: String) -> Result(Bool, DecodeError) {
    case ccl_core.get_value(ccl, path) {
      Ok(value) -> {
        case string.lowercase(string.trim(value)) {
          "true" | "yes" | "1" | "on" -> Ok(True)
          "false" | "no" | "0" | "off" -> Ok(False)
          _ -> Error(InvalidFormat(value, "Bool"))
        }
      }
      Error(_) -> Error(FieldNotFound(path))
    }
  }
}

// === CONFIGURATION TYPES ===

pub type DatabaseConfig {
  DatabaseConfig(host: String, port: Int, ssl: Bool, timeout_ms: Option(Int))
}

pub type AppConfig {
  AppConfig(name: String, debug: Bool, database: DatabaseConfig)
}

// === DECODERS ===

pub fn database_config_decoder() -> Decoder(DatabaseConfig) {
  fn(ccl: ccl_core.CCL, base_path: String) -> Result(
    DatabaseConfig,
    DecodeError,
  ) {
    let make_path = fn(field: String) {
      case base_path {
        "" -> "database." <> field
        // For flat structure, always use database prefix
        _ -> base_path <> ".database." <> field
      }
    }

    case string_decoder()(ccl, make_path("host")) {
      Ok(host) ->
        case int_decoder()(ccl, make_path("port")) {
          Ok(port) ->
            case bool_decoder()(ccl, make_path("ssl")) {
              Ok(ssl) -> {
                let timeout_ms = case
                  int_decoder()(ccl, make_path("timeout_ms"))
                {
                  Ok(timeout) -> Some(timeout)
                  Error(_) -> None
                }
                Ok(DatabaseConfig(host:, port:, ssl:, timeout_ms:))
              }
              Error(err) -> Error(err)
            }
          Error(err) -> Error(err)
        }
      Error(err) -> Error(err)
    }
  }
}

pub fn app_config_decoder() -> Decoder(AppConfig) {
  fn(ccl: ccl_core.CCL, _base_path: String) -> Result(AppConfig, DecodeError) {
    case string_decoder()(ccl, "name") {
      Ok(name) ->
        case bool_decoder()(ccl, "debug") {
          Ok(debug) ->
            case database_config_decoder()(ccl, "") {
              // Pass empty path since decoder handles prefix
              Ok(database) -> Ok(AppConfig(name:, debug:, database:))
              Error(err) -> Error(err)
            }
          Error(err) -> Error(err)
        }
      Error(err) -> Error(err)
    }
  }
}

// === MAIN DECODE FUNCTION ===

pub fn decode_ccl(ccl_text: String, decoder: Decoder(a)) -> Result(a, String) {
  case ccl_core.parse(ccl_text) {
    Ok(entries) -> {
      let ccl_obj = ccl_core.make_objects(entries)
      case decoder(ccl_obj, "") {
        Ok(decoded) -> Ok(decoded)
        Error(decode_error) -> Error(decode_error_to_string(decode_error))
      }
    }
    Error(parse_error) -> Error("Parse error: " <> parse_error.reason)
  }
}

fn decode_error_to_string(error: DecodeError) -> String {
  case error {
    FieldNotFound(field) -> "Field not found: " <> field
    InvalidFormat(value, expected_type) ->
      "Invalid " <> expected_type <> " format: " <> value
  }
}

// === DEMONSTRATION ===

pub fn example() -> Result(AppConfig, String) {
  let ccl_text =
    "
name = My Application
debug = true

database.host = localhost
database.port = 5432
database.ssl = false
database.timeout_ms = 30000
"

  decode_ccl(ccl_text, app_config_decoder())
}

pub fn debug_ccl_structure() {
  let ccl_text =
    "
name = My Application
debug = true

database.host = localhost
database.port = 5432
database.ssl = false
database.timeout_ms = 30000
"

  case ccl_core.parse(ccl_text) {
    Ok(entries) -> {
      io.println("=== Parsed Entries ===")
      list.each(entries, fn(entry) {
        io.println(
          "Key: '" <> entry.key <> "' -> Value: '" <> entry.value <> "'",
        )
      })

      let ccl_obj = ccl_core.make_objects(entries)
      io.println("\n=== CCL Object Structure ===")

      // Test what keys exist at root level
      let root_keys = ccl_core.get_keys(ccl_obj, "")
      io.println("Root keys: " <> string.inspect(root_keys))

      // Test getting values
      case ccl_core.get_value(ccl_obj, "name") {
        Ok(value) -> io.println("name: " <> value)
        Error(err) -> io.println("name error: " <> err)
      }

      // Test direct key access (should work since it's a flat key)
      case ccl_core.get_value(ccl_obj, "database.host") {
        Ok(value) -> io.println("database.host: " <> value)
        Error(err) -> io.println("database.host error: " <> err)
      }

      // Check if the root keys contain our values as flat keys
      io.println("Looking for database.host in keys...")
      case list.contains(root_keys, "database.host") {
        True -> io.println("✓ database.host found as flat key!")
        False -> io.println("✗ database.host not found")
      }
    }
    Error(err) -> io.println("Parse error: " <> err.reason)
  }
}

pub fn main() {
  debug_ccl_structure()
  io.println("\n" <> string.repeat("=", 50) <> "\n")

  case example() {
    Ok(config) -> {
      io.println("=== CCL High-Level Decode API Demo ===")
      io.println("✓ Successfully decoded CCL into typed structure!")
      io.println("App name: " <> config.name)
      io.println(
        "Debug mode: "
        <> case config.debug {
          True -> "enabled"
          False -> "disabled"
        },
      )
      io.println("Database host: " <> config.database.host)
      io.println("Database port: " <> int.to_string(config.database.port))
      io.println(
        "SSL enabled: "
        <> case config.database.ssl {
          True -> "yes"
          False -> "no"
        },
      )
      io.println(
        "Timeout: "
        <> case config.database.timeout_ms {
          Some(timeout) -> int.to_string(timeout) <> "ms"
          None -> "not set"
        },
      )
    }
    Error(error) -> {
      io.println("❌ Decode failed: " <> error)
    }
  }
}
