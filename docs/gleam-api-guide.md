# Gleam CCL API Guide

Complete guide to using the Gleam CCL library for type-safe configuration parsing.

## Installation

Add to your `gleam.toml`:

```toml
[dependencies]
ccl = "1.0.0"
```

For core-only (zero dependencies):
```toml
[dependencies]
ccl_core = "1.0.0"
```

## Basic Usage

### Parsing CCL Text

```gleam
import ccl

let config_text = "
database.host = localhost
database.port = 5432
server.debug = true
"

case ccl.parse(config_text) {
  Ok(entries) -> {
    // Successfully parsed into Entry list
    let objects = ccl.make_objects(entries)
    // Now you can access nested values
  }
  Error(parse_error) -> {
    io.println("Parse failed: " <> parse_error.reason)
  }
}
```

### Accessing Configuration Values

```gleam
// Access strings
case ccl.get(config, "database.host") {
  Ok(ccl.CclString(host)) -> use_host(host)
  Ok(_) -> io.println("Expected string")
  Error(msg) -> io.println("Key not found: " <> msg)
}

// Type-safe integer access
case ccl.get_int(config, "database.port") {
  Ok(port) -> connect_on_port(port)
  Error(msg) -> {
    io.println("Port error: " <> msg)
    use_default_port()
  }
}

// Type-safe boolean access  
case ccl.get_bool(config, "server.debug") {
  Ok(True) -> enable_debug_mode()
  Ok(False) -> disable_debug_mode()
  Error(_) -> disable_debug_mode()  // default
}
```

## API Reference

### Core Types

```gleam
// Parsed entry from CCL text
pub type Entry {
  Entry(key: String, value: String)
}

// Parse errors with location info
pub type ParseError {
  ParseError(reason: String, line: Int, column: Int)
}

// Typed CCL values after object construction
pub type CclValue {
  CclString(String)
  CclList(List(String))  
  CclObject(CCL)
}

// Main CCL object type (map of string to CclValue)
pub type CCL = Dict(String, CclValue)
```

### Level 1: Core Parsing

```gleam
// Parse CCL text into flat entries
pub fn parse(text: String) -> Result(List(Entry), ParseError)

// Example usage
let assert Ok(entries) = ccl.parse("key = value\nother = data")
```

### Level 2: Entry Processing

```gleam
// Remove comment entries (keys starting with "/")
pub fn filter_comments(entries: List(Entry)) -> List(Entry)

// Compose two entry lists
pub fn compose_entries(left: List(Entry), right: List(Entry)) -> List(Entry)

// Example usage
let filtered = ccl.filter_comments(entries)
```

### Level 3: Object Construction

```gleam
// Build nested objects from flat entries
pub fn make_objects(entries: List(Entry)) -> CCL

// Access any value by path
pub fn get(ccl: CCL, path: String) -> Result(CclValue, String)

// Example usage
let config = ccl.make_objects(entries)
let host = ccl.get(config, "database.host")
```

### Level 4: Type-Safe Access

```gleam
// Type-specific accessor functions
pub fn get_string(ccl: CCL, path: String) -> Result(String, String)
pub fn get_int(ccl: CCL, path: String) -> Result(Int, String)
pub fn get_float(ccl: CCL, path: String) -> Result(Float, String)
pub fn get_bool(ccl: CCL, path: String) -> Result(Bool, String)

// Generic typed value access
pub fn get_typed_value(ccl: CCL, path: String) -> Result(CclValue, String)
```

## Advanced Usage Patterns

### Configuration Loading with Defaults

```gleam
pub fn load_config_with_defaults() -> AppConfig {
  case simplifile.read("config.ccl") {
    Ok(content) -> {
      case ccl.parse(content) {
        Ok(entries) -> {
          let config = ccl.make_objects(entries)
          build_app_config_with_defaults(config)
        }
        Error(_) -> default_app_config()
      }
    }
    Error(_) -> default_app_config()
  }
}

fn build_app_config_with_defaults(config: ccl.CCL) -> AppConfig {
  let host = ccl.get_string(config, "database.host")
    |> result.unwrap("localhost")
    
  let port = ccl.get_int(config, "database.port")
    |> result.unwrap(5432)
    
  let debug = ccl.get_bool(config, "server.debug")
    |> result.unwrap(False)
    
  AppConfig(db_host: host, db_port: port, debug: debug)
}
```

### Environment-Specific Configuration

```gleam
import gleam/os

pub fn load_environment_config() -> Result(ccl.CCL, String) {
  let env = os.get_env("APP_ENV") |> result.unwrap("development")
  let config_file = "config/" <> env <> ".ccl"
  
  use content <- result.try(simplifile.read(config_file))
  use entries <- result.try(ccl.parse(content))
  
  Ok(ccl.make_objects(entries))
}

// Usage
case load_environment_config() {
  Ok(config) -> {
    let db_host = ccl.get_string(config, "database.host")
      |> result.unwrap("localhost")
    start_app_with_config(db_host)
  }
  Error(msg) -> {
    io.println("Config error: " <> msg)
    start_app_with_defaults()
  }
}
```

### Comprehensive Error Handling

```gleam
pub type ConfigError {
  ParseError(String)
  ValidationError(String, String)  // path, error
  MissingRequired(String)
  TypeMismatch(String, String)     // path, expected type
}

pub fn validate_app_config(config_text: String) -> Result(AppConfig, List(ConfigError)) {
  case ccl.parse(config_text) {
    Error(err) -> Error([ParseError(err.reason)])
    Ok(entries) -> {
      let config = ccl.make_objects(entries)
      let errors = []
      
      // Check required fields
      let errors = case ccl.get_string(config, "app.name") {
        Ok(_) -> errors  
        Error(_) -> [MissingRequired("app.name"), ..errors]
      }
      
      // Validate types and constraints
      let errors = case ccl.get_int(config, "server.port") {
        Ok(port) if port > 0 && port < 65536 -> errors
        Ok(_) -> [ValidationError("server.port", "Must be 1-65535"), ..errors]
        Error(_) -> [TypeMismatch("server.port", "integer"), ..errors]
      }
      
      case errors {
        [] -> Ok(build_app_config(config))
        _ -> Error(list.reverse(errors))
      }
    }
  }
}
```

### Working with Lists

```gleam
// Access lists safely
case ccl.get(config, "allowed_hosts") {
  Ok(ccl.CclList(hosts)) -> {
    list.each(hosts, fn(host) {
      io.println("Allowed: " <> host)
    })
  }
  Ok(ccl.CclString(single_host)) -> {
    // Handle case where config has single value instead of list
    io.println("Single host: " <> single_host)
  }
  _ -> io.println("No hosts configured")
}

// Convert single values to lists uniformly  
pub fn get_string_list(config: ccl.CCL, path: String) -> List(String) {
  case ccl.get(config, path) {
    Ok(ccl.CclList(items)) -> items
    Ok(ccl.CclString(single)) -> [single]
    _ -> []
  }
}

// Usage
let hosts = get_string_list(config, "database.hosts")
let backup_hosts = get_string_list(config, "database.backup_host")
```

### Configuration Composition

```gleam
pub fn load_composed_config(
  base_file: String,
  override_file: String
) -> Result(ccl.CCL, String) {
  use base_content <- result.try(simplifile.read(base_file))
  use override_content <- result.try(simplifile.read(override_file))
  
  use base_entries <- result.try(ccl.parse(base_content))
  use override_entries <- result.try(ccl.parse(override_content))
  
  // Combine entries - later entries override earlier ones
  let combined = ccl.compose_entries(base_entries, override_entries)
  let filtered = ccl.filter_comments(combined)
  
  Ok(ccl.make_objects(filtered))
}

// Usage
let config = case load_composed_config("base.ccl", "production.ccl") {
  Ok(config) -> config
  Error(err) -> {
    io.println("Config error: " <> err)
    panic as "Failed to load configuration"
  }
}
```

## Testing Configuration Code

### Unit Testing Configuration Parsing

```gleam
import gleeunit/should

pub fn test_database_config_parsing() {
  let config_text = "
    database.host = testdb
    database.port = 5433
    database.ssl = true
  "
  
  let assert Ok(entries) = ccl.parse(config_text)
  let config = ccl.make_objects(entries)
  
  ccl.get_string(config, "database.host")
  |> should.equal(Ok("testdb"))
  
  ccl.get_int(config, "database.port")  
  |> should.equal(Ok(5433))
  
  ccl.get_bool(config, "database.ssl")
  |> should.equal(Ok(True))
}

pub fn test_missing_configuration() {
  let config_text = "database.host = localhost"
  
  let assert Ok(entries) = ccl.parse(config_text)
  let config = ccl.make_objects(entries)
  
  ccl.get_string(config, "database.port")
  |> should.be_error()
}
```

### Property-Based Testing

```gleam
pub fn test_parse_roundtrip_property() {
  // Property: parsing should be deterministic
  let config = generate_random_ccl_config()
  
  let assert Ok(entries1) = ccl.parse(config)
  let assert Ok(entries2) = ccl.parse(config)
  
  entries1 |> should.equal(entries2)
}

pub fn test_object_construction_idempotent() {
  // Property: make_objects should be idempotent for already-constructed data
  let config_text = "key = value\nnested.key = nested_value"
  
  let assert Ok(entries) = ccl.parse(config_text)
  let objects1 = ccl.make_objects(entries)
  
  // Converting back to entries and reconstructing should be identical
  let reconstructed_entries = ccl.to_entries(objects1)
  let objects2 = ccl.make_objects(reconstructed_entries)
  
  objects1 |> should.equal(objects2)
}
```

## Performance Considerations

### Lazy Object Construction

```gleam
// For large configurations, consider lazy construction
pub type LazyConfig {
  LazyConfig(entries: List(ccl.Entry), constructed: Option(ccl.CCL))
}

pub fn create_lazy_config(entries: List(ccl.Entry)) -> LazyConfig {
  LazyConfig(entries: entries, constructed: None)
}

pub fn lazy_get(lazy_config: LazyConfig, path: String) -> Result(ccl.CclValue, String) {
  case lazy_config.constructed {
    Some(ccl_obj) -> ccl.get(ccl_obj, path)
    None -> {
      // Construct on first access
      let ccl_obj = ccl.make_objects(lazy_config.entries)
      ccl.get(ccl_obj, path)
    }
  }
}
```

### Memory-Efficient Parsing

```gleam
// For very large config files, consider streaming
pub fn parse_stream(file_path: String) -> Iterator(ccl.Entry) {
  // Implementation would read and parse line by line
  // This is just a conceptual example
  file_path
  |> simplifile.read_lines()
  |> iterator.from_list()
  |> iterator.filter_map(fn(line) {
    case string.contains(line, "=") {
      True -> {
        case ccl.parse_single_line(line) {
          Ok(entry) -> Some(entry)
          Error(_) -> None
        }
      }
      False -> None
    }
  })
}
```

## Integration Patterns

### Web Application Configuration

```gleam
pub type WebConfig {
  WebConfig(
    server_port: Int,
    database_url: String,
    redis_url: String,
    debug: Bool,
    allowed_origins: List(String)
  )
}

pub fn load_web_config() -> Result(WebConfig, String) {
  use content <- result.try(simplifile.read("web.ccl"))
  use entries <- result.try(ccl.parse(content))
  let config = ccl.make_objects(ccl.filter_comments(entries))
  
  use server_port <- result.try(ccl.get_int(config, "server.port"))
  use database_url <- result.try(ccl.get_string(config, "database.url"))
  use redis_url <- result.try(ccl.get_string(config, "redis.url"))
  
  let debug = ccl.get_bool(config, "debug") |> result.unwrap(False)
  let allowed_origins = case ccl.get(config, "cors.allowed_origins") {
    Ok(ccl.CclList(origins)) -> origins
    Ok(ccl.CclString(origin)) -> [origin]
    _ -> ["http://localhost:3000"]  // default
  }
  
  Ok(WebConfig(
    server_port: server_port,
    database_url: database_url,
    redis_url: redis_url,
    debug: debug,
    allowed_origins: allowed_origins
  ))
}
```

The Gleam CCL library provides a robust, type-safe way to handle configuration files with excellent error handling and functional programming patterns.