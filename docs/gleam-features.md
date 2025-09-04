# Gleam-Specific CCL Features

Type-safe parsing, advanced error handling, and Gleam-specific utilities.

## Type-Safe Parsing

### Smart Type Detection

The Gleam CCL library provides type-aware parsing functions:

```ccl
server =
  port = 8080
  timeout = 30.5
  debug = true
  name = MyServer
```

```gleam
import ccl

let assert Ok(entries) = ccl.parse(config_text)
let config = ccl.make_objects(entries)

// Type-safe accessors with automatic conversion
let port = ccl.get_int(config, "server.port")        // Ok(8080)
let timeout = ccl.get_float(config, "server.timeout") // Ok(30.5)
let debug = ccl.get_bool(config, "server.debug")      // Ok(True)
let name = ccl.get_string(config, "server.name")      // Ok("MyServer")
```

**Available Type Functions:**
- `get_string()` - Returns string value
- `get_int()` - Parses integers  
- `get_float()` - Parses floating-point numbers
- `get_bool()` - Parses booleans (`true`/`false`, `yes`/`no`, `on`/`off`)

### Unified Access API

The new `get()` function returns typed values automatically:

```gleam
// Single function handles all types
case ccl.get(config, "server.port") {
  Ok(ccl.CclString(port_str)) -> {
    case int.parse(port_str) {
      Ok(port) -> start_server_on_port(port)
      Error(_) -> io.println("Invalid port number")
    }
  }
  Ok(ccl.CclList(ports)) -> {
    // Handle multiple ports
    list.each(ports, start_server_on_port)
  }
  Ok(ccl.CclObject(server_config)) -> {
    // Handle nested server config
    configure_advanced_server(server_config)
  }
  Error(msg) -> io.println("Server config error: " <> msg)
}
```

### Type-Safe Configuration Structs

Build strongly-typed configuration from CCL:

```ccl
database =
  host = localhost
  port = 5432
  username = admin
  password = secret123
  ssl_enabled = true
  pool_size = 20
  timeout = 30.0
```

```gleam
pub type DatabaseConfig {
  DatabaseConfig(
    host: String,
    port: Int,
    username: String,
    password: String,
    ssl_enabled: Bool,
    pool_size: Int,
    timeout: Float
  )
}

pub fn load_database_config(config: ccl.CCL) -> Result(DatabaseConfig, String) {
  use host <- result.try(ccl.get_string(config, "database.host"))
  use port <- result.try(ccl.get_int(config, "database.port"))
  use username <- result.try(ccl.get_string(config, "database.username"))
  use password <- result.try(ccl.get_string(config, "database.password"))
  use ssl_enabled <- result.try(ccl.get_bool(config, "database.ssl_enabled"))
  use pool_size <- result.try(ccl.get_int(config, "database.pool_size"))
  use timeout <- result.try(ccl.get_float(config, "database.timeout"))
  
  Ok(DatabaseConfig(
    host: host,
    port: port,
    username: username,
    password: password,
    ssl_enabled: ssl_enabled,
    pool_size: pool_size,
    timeout: timeout
  ))
}
```

## Advanced Error Handling

### Graceful Defaults

Handle missing configuration with type-safe defaults:

```gleam
pub fn load_server_config_with_defaults(config: ccl.CCL) -> ServerConfig {
  let host = ccl.get_string(config, "server.host") 
    |> result.unwrap("localhost")
    
  let port = ccl.get_int(config, "server.port")
    |> result.unwrap(3000)
    
  let timeout = ccl.get_float(config, "server.timeout")
    |> result.unwrap(30.0)
    
  let debug = ccl.get_bool(config, "server.debug")
    |> result.unwrap(False)
    
  ServerConfig(host: host, port: port, timeout: timeout, debug: debug)
}
```

### Comprehensive Error Reporting

Collect and report all configuration errors at once:

```gleam
pub type ConfigError {
  ParseError(String)
  ValidationError(String, String)  // path, error message
  MissingRequired(String)
  TypeMismatch(String, String)     // path, expected type
}

pub fn validate_config(config_text: String) -> Result(AppConfig, List(ConfigError)) {
  case ccl.parse(config_text) {
    Error(parse_err) -> Error([ParseError("Failed to parse CCL: " <> string.inspect(parse_err))])
    Ok(entries) -> {
      let config = ccl.make_objects(entries)
      let errors = []
      
      // Validate required fields
      let errors = case ccl.get_string(config, "app.name") {
        Ok(_) -> errors
        Error(_) -> [MissingRequired("app.name"), ..errors]
      }
      
      // Validate types with custom error messages  
      let errors = case ccl.get_int(config, "server.port") {
        Ok(port) if port > 0 && port < 65536 -> errors
        Ok(_) -> [ValidationError("server.port", "Port must be between 1 and 65535"), ..errors]
        Error(_) -> [TypeMismatch("server.port", "integer"), ..errors]
      }
      
      let errors = case ccl.get_bool(config, "server.debug") {
        Ok(_) -> errors
        Error(_) -> [TypeMismatch("server.debug", "boolean"), ..errors]
      }
      
      case errors {
        [] -> Ok(build_config(config))
        _ -> Error(list.reverse(errors))
      }
    }
  }
}

// Usage with detailed error reporting
case validate_config(config_text) {
  Ok(config) -> {
    io.println("✅ Configuration loaded successfully")
    start_application(config)
  }
  Error(errors) -> {
    io.println("❌ Configuration errors:")
    list.each(errors, fn(error) {
      case error {
        ParseError(msg) -> io.println("  Parse error: " <> msg)
        ValidationError(path, msg) -> io.println("  " <> path <> ": " <> msg)
        MissingRequired(path) -> io.println("  Missing required: " <> path)
        TypeMismatch(path, expected) -> io.println("  " <> path <> ": expected " <> expected)
      }
    })
    io.println("Fix these errors and try again.")
  }
}
```

## Configuration Composition

### Merging Multiple Files

Combine base configuration with environment-specific overrides:

```gleam
pub fn load_composed_config(
  base_file: String, 
  override_file: String
) -> Result(ccl.CCL, String) {
  use base_content <- result.try(simplifile.read(base_file))
  use override_content <- result.try(simplifile.read(override_file))
  
  use base_entries <- result.try(ccl.parse(base_content))
  use override_entries <- result.try(ccl.parse(override_content))
  
  // Combine entries - overrides take precedence
  let combined = list.append(base_entries, override_entries)
  
  Ok(ccl.make_objects(combined))
}

// Usage
let config = case load_composed_config("base.ccl", "production.ccl") {
  Ok(config) -> config
  Error(err) -> {
    io.println("Failed to load config: " <> err)
    panic as "Configuration error"
  }
}
```

### Environment-Specific Loading

Load configuration based on environment variables:

```gleam
import gleam/os

pub fn load_environment_config() -> Result(ccl.CCL, String) {
  let environment = os.get_env("APP_ENV") |> result.unwrap("development")
  let config_file = "config/" <> environment <> ".ccl"
  
  use content <- result.try(simplifile.read(config_file))
  use entries <- result.try(ccl.parse(content))
  
  Ok(ccl.make_objects(entries))
}

// With fallback to base configuration
pub fn load_config_with_fallback() -> ccl.CCL {
  case load_environment_config() {
    Ok(config) -> config
    Error(_) -> {
      io.println("Loading fallback configuration...")
      case load_composed_config("config/base.ccl", "config/local.ccl") {
        Ok(config) -> config
        Error(_) -> {
          io.println("Using minimal default configuration")
          ccl.make_objects([])  // Empty config
        }
      }
    }
  }
}
```

## Smart List Handling

### Flexible List Access

Handle both single values and lists uniformly:

```ccl
# Single email
notification_email = admin@example.com

# Multiple emails  
notification_emails =
  = admin@example.com
  = alerts@example.com
  = ops@example.com
```

```gleam
pub fn get_email_list(config: ccl.CCL, path: String) -> List(String) {
  case ccl.get(config, path) {
    Ok(ccl.CclString(single_email)) -> [single_email]
    Ok(ccl.CclList(email_list)) -> email_list
    _ -> []
  }
}

// Use with either single or multiple values
let notification_emails = get_email_list(config, "notification_email")
let admin_emails = get_email_list(config, "notification_emails")
```

### Smart Value Access

Get the primary value from flexible configuration:

```gleam
pub fn get_primary_value(config: ccl.CCL, path: String) -> Result(String, String) {
  case ccl.get(config, path) {
    Ok(ccl.CclString(value)) -> Ok(value)
    Ok(ccl.CclList(values)) -> {
      case values {
        [first, ..] -> Ok(first)  // Return first item from list
        [] -> Error("Empty list at " <> path)
      }
    }
    Ok(_) -> Error("Expected string or list at " <> path)
    Error(err) -> Error(err)
  }
}

// Usage
let primary_database = get_primary_value(config, "database.hosts")
// Works with both "database.hosts = localhost" and "database.hosts = [localhost, replica]"
```

## Debugging and Introspection

### Configuration Inspection

Explore configuration structure programmatically:

```gleam
pub fn inspect_config(config: ccl.CCL) {
  io.println("Configuration structure:")
  
  let paths = ccl.get_all_paths(config)
  list.each(paths, fn(path) {
    case ccl.get(config, path) {
      Ok(ccl.CclString(value)) -> {
        io.println("  " <> path <> " = " <> value <> " (string)")
      }
      Ok(ccl.CclList(values)) -> {
        let count = list.length(values) |> int.to_string()
        io.println("  " <> path <> " = [" <> count <> " items] (list)")
      }
      Ok(ccl.CclObject(_)) -> {
        io.println("  " <> path <> " = {...} (object)")
      }
      Error(_) -> {
        io.println("  " <> path <> " = <error>")
      }
    }
  })
}

// Node type inspection
pub fn analyze_path(config: ccl.CCL, path: String) {
  let node_type = ccl.node_type(config, path)
  case node_type {
    ccl.SingleValue -> io.println(path <> " is a single value")
    ccl.ListValue -> io.println(path <> " is a list")
    ccl.ObjectValue -> io.println(path <> " is a nested object")
    ccl.Missing -> io.println(path <> " does not exist")
  }
}
```

### Pretty Printing

Format configuration for debugging:

```gleam
pub fn debug_config(config: ccl.CCL) {
  let formatted = ccl.pretty_print_ccl(config)
  io.println("Current configuration:")
  io.println(formatted)
}
```

## Best Practices

### Configuration Validation Pipeline

Create a robust configuration loading pipeline:

```gleam
pub fn load_validated_config() -> AppConfig {
  let config_text = simplifile.read("app.ccl") 
    |> result.unwrap("")
    
  config_text
  |> validate_config()
  |> result.map_error(fn(errors) {
    list.each(errors, log_config_error)
    panic as "Invalid configuration"
  })
  |> result.unwrap()
}

fn log_config_error(error: ConfigError) {
  case error {
    ParseError(msg) -> io.println("🔴 Parse error: " <> msg)
    ValidationError(path, msg) -> io.println("🟡 " <> path <> ": " <> msg)
    MissingRequired(path) -> io.println("🔴 Missing required field: " <> path)
    TypeMismatch(path, expected) -> io.println("🟠 " <> path <> " should be " <> expected)
  }
}
```

### Testing Configuration Loading

Write tests for your configuration code:

```gleam
import gleeunit/should

pub fn test_database_config_loading() {
  let config_text = "
  database =
    host = testdb
    port = 5433
    ssl_enabled = true
  "
  
  let assert Ok(entries) = ccl.parse(config_text)
  let config = ccl.make_objects(entries)
  
  let assert Ok(db_config) = load_database_config(config)
  
  db_config.host |> should.equal("testdb")
  db_config.port |> should.equal(5433)
  db_config.ssl_enabled |> should.equal(True)
}

pub fn test_config_with_missing_fields() {
  let config_text = "database.host = testdb"
  
  let assert Ok(entries) = ccl.parse(config_text)
  let config = ccl.make_objects(entries)
  
  case load_database_config(config) {
    Ok(_) -> should.fail()  // Should not succeed with missing fields
    Error(msg) -> {
      string.contains(msg, "port") |> should.be_true()
    }
  }
}
```

The Gleam CCL implementation provides powerful type-safe configuration loading with comprehensive error handling and flexible data access patterns.