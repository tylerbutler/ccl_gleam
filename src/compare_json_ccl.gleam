// Comparison: JSON vs CCL nested field access patterns

import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/io
import gleam/string
import ccl_core

// === JSON APPROACH ===

pub type JsonConfig {
  JsonConfig(name: String, database: JsonDatabase)
}

pub type JsonDatabase {
  JsonDatabase(host: String, port: Int)
}

// JSON decoder using nested field access
pub fn json_config_decoder() -> decode.Decoder(JsonConfig) {
  use name <- decode.field("name", decode.string)
  use database <- decode.field("database", json_database_decoder())  
  decode.success(JsonConfig(name:, database:))
}

pub fn json_database_decoder() -> decode.Decoder(JsonDatabase) {
  use host <- decode.field("host", decode.string)
  use port <- decode.field("port", decode.int)
  decode.success(JsonDatabase(host:, port:))
}

pub fn demonstrate_json_nested_access() {
  let json_text = "{
    \"name\": \"MyApp\",
    \"database\": {
      \"host\": \"localhost\",
      \"port\": 5432
    }
  }"
  
  io.println("=== JSON Nested Structure ===")
  io.println("Input JSON:")
  io.println(json_text)
  
  case json.parse(json_text, json_config_decoder()) {
    Ok(config) -> {
      io.println("\n✓ JSON parsing successful!")
      io.println("Name: " <> config.name)
      io.println("DB Host: " <> config.database.host)
      io.println("DB Port: " <> int.to_string(config.database.port))
    }
    Error(_err) -> {
      io.println("\n❌ JSON parsing failed")
    }
  }
}

// === CCL COMPARISON ===

pub fn demonstrate_ccl_flat_vs_nested() {
  io.println("\n" <> string.repeat("=", 60))
  io.println("=== CCL Flat Keys vs True Nesting ===")
  
  // Method 1: CCL with flat dot-notation keys
  let ccl_flat = "
name = MyApp
database.host = localhost
database.port = 5432
"

  // Method 2: CCL with true nested structure (indented)
  let ccl_nested = "
name = MyApp
database = 
    host = localhost
    port = 5432
"

  io.println("\nMethod 1 - Flat dot keys:")
  io.println(ccl_flat)
  
  case ccl_core.parse(ccl_flat) {
    Ok(entries) -> {
      let ccl_obj = ccl_core.make_objects(entries)
      let keys = ccl_core.get_keys(ccl_obj, "")
      io.println("Keys: " <> string.inspect(keys))
      
      // Try both access patterns
      case ccl_core.get_value(ccl_obj, "database.host") {
        Ok(value) -> io.println("database.host (direct): " <> value)
        Error(_) -> io.println("database.host (direct): NOT FOUND")
      }
      
      case ccl_core.get_nested(ccl_obj, "database") {
        Ok(_nested) -> io.println("database (nested): FOUND")
        Error(_) -> io.println("database (nested): NOT FOUND")
      }
    }
    Error(_) -> io.println("Parse error")
  }
  
  io.println("\nMethod 2 - True nested structure:")
  io.println(ccl_nested)
  
  case ccl_core.parse(ccl_nested) {
    Ok(entries) -> {
      let ccl_obj = ccl_core.make_objects(entries)
      let keys = ccl_core.get_keys(ccl_obj, "")
      io.println("Keys: " <> string.inspect(keys))
      
      // Try nested access
      case ccl_core.get_nested(ccl_obj, "database") {
        Ok(nested) -> {
          io.println("database (nested): FOUND")
          let nested_keys = ccl_core.get_keys(nested, "")
          io.println("Nested keys: " <> string.inspect(nested_keys))
          
          case ccl_core.get_value(nested, "host") {
            Ok(host) -> io.println("database.host (via nesting): " <> host)  
            Error(_) -> io.println("database.host (via nesting): NOT FOUND")
          }
        }
        Error(_) -> io.println("database (nested): NOT FOUND")
      }
    }
    Error(_) -> io.println("Parse error")
  }
}

pub fn main() {
  demonstrate_json_nested_access()
  demonstrate_ccl_flat_vs_nested()
}