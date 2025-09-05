# CCL User Guide

Advanced configuration patterns and type-safe Gleam features.

## Complex Nested Structures

### Multi-Level Nesting

Build deeply nested configurations for complex applications:

```ccl
application =
  name = MyApp
  version = 2.1.0
  
  server =
    host = 0.0.0.0
    port = 8080
    
    ssl =
      enabled = true
      cert_file = /etc/ssl/cert.pem
      key_file = /etc/ssl/private.key
      
    middleware =
      cors =
        enabled = true
        origins =
          = https://app.example.com
          = https://admin.example.com
      
      rate_limiting =
        enabled = true
        requests_per_minute = 1000
        
  database =
    primary =
      host = db-primary.example.com
      port = 5432
      pool_size = 20
      
    replica =
      host = db-replica.example.com
      port = 5432
      pool_size = 10
```

### Environment-Specific Configuration

Structure configuration by environment using nested sections:

```ccl
development =
  debug = true
  log_level = debug
  
  database =
    host = localhost
    port = 5432
    pool_size = 5
  
  cache =
    enabled = false

production =
  debug = false
  log_level = warning
  
  database =
    host = prod-db.example.com
    port = 5432
    pool_size = 20
    ssl = true
  
  cache =
    enabled = true
    
    redis =
      host = redis-cluster.example.com
      port = 6379
```

Access environment-specific config in Gleam:

```gleam
pub fn load_env_config(config: ccl.CCL, environment: String) -> DatabaseConfig {
  let env_path = environment <> ".database"
  
  let host = ccl.get(config, env_path <> ".host")
    |> result.map(fn(val) { 
      case val { 
        ccl.CclString(h) -> h
        _ -> "localhost" 
      }
    })
    |> result.unwrap("localhost")
    
  let pool_size = ccl.get(config, env_path <> ".pool_size")
    |> result.try(fn(val) {
      case val {
        ccl.CclString(s) -> int.parse(s)
        _ -> Error(Nil)
      }
    })
    |> result.unwrap(10)
    
  DatabaseConfig(host: host, pool_size: pool_size)
}
```

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

The `get()` function returns typed values automatically:

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

## Advanced List Patterns

### Lists with Metadata

Combine lists with structured metadata:

```ccl
services =
  web_servers =
    = web-1.example.com
    = web-2.example.com
    = web-3.example.com
    
  server_config =
    web-1.example.com =
      region = us-east-1
      capacity = high
      
    web-2.example.com =
      region = us-west-2
      capacity = medium
      
    web-3.example.com =
      region = eu-west-1
      capacity = high

feature_flags =
  enabled =
    = user_registration
    = email_notifications
    = advanced_search
  
  beta =
    = new_dashboard
    = ai_recommendations
    
  config =
    user_registration =
      rollout_percentage = 100
      regions =
        = us-east-1
        = us-west-2
        
    new_dashboard =
      rollout_percentage = 25
      user_types =
        = premium
        = enterprise
```

### Complex List Processing

Process lists with associated metadata:

```gleam
pub fn load_servers_with_config(config: ccl.CCL) -> List(ServerInfo) {
  case ccl.get(config, "services.web_servers") {
    Ok(ccl.CclList(servers)) -> {
      list.map(servers, fn(server_name) {
        let config_path = "services.server_config." <> server_name
        
        let region = ccl.get(config, config_path <> ".region")
          |> result.map(fn(val) { 
            case val { ccl.CclString(r) -> r; _ -> "unknown" }
          })
          |> result.unwrap("unknown")
          
        let capacity = ccl.get(config, config_path <> ".capacity")
          |> result.map(fn(val) { 
            case val { ccl.CclString(c) -> c; _ -> "medium" }
          })
          |> result.unwrap("medium")
          
        ServerInfo(
          name: server_name,
          region: region, 
          capacity: capacity
        )
      })
    }
    _ -> []
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

## Documentation and Comments

### Comprehensive Documentation

Use comment keys for rich documentation:

```ccl
/= Application Configuration
/= Version: 2.1.0
/= Last updated: 2024-01-15
/= 
/= This configuration supports multiple environments
/= and automatic failover between database instances

api =
  /= Rate limiting configuration
  /= Controls the number of requests per minute per IP address
  rate_limit = 100
  
  /= Request timeout in seconds
  /= Increase this value if you have slow external API calls
  timeout = 30.0
  
  authentication =
    /= JWT secret key - MUST be changed in production
    /= Generate with: openssl rand -base64 32
    jwt_secret = your-super-secret-key-here
    
    /= Token expiration time in seconds (1 hour = 3600)
    jwt_expiration = 3600

database =
  /= Primary database connection
  /= This is the main read-write database
  primary =
    host = localhost
    port = 5432
    /= Maximum connections in the connection pool
    /= Adjust based on your application's concurrency needs
    pool_size = 20
    
  /= Read-only replica for scaling read operations  
  /= Automatically used for SELECT queries when available
  replica =
    host = replica.example.com
    port = 5432
    pool_size = 10
    /= Enable SSL for replica connections in production
    ssl_mode = prefer
```

### Comment Filtering

Filter out documentation when processing configuration:

```gleam
pub fn filter_comments(config: ccl.CCL) -> ccl.CCL {
  // Remove special comment keys
  let comment_keys = ["/", "//", "#", "/*", "doc", "comment"]
  ccl.filter_keys(config, comment_keys)
}

pub fn extract_documentation(config: ccl.CCL) -> List(#(String, String)) {
  ccl.get_all_paths(config)
  |> list.filter_map(fn(path) {
    case string.starts_with(path, "/") || string.starts_with(path, "#") {
      True -> {
        case ccl.get(config, path) {
          Ok(ccl.CclString(doc)) -> Ok(#(path, doc))
          _ -> Error(Nil)
        }
      }
      False -> Error(Nil)
    }
  })
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

## Migration Patterns

### Gradual Migration from JSON

Support both CCL and JSON during migration:

```gleam
pub type ConfigSource {
  CclSource(String)
  JsonSource(String)
}

pub fn load_config(source: ConfigSource) -> Result(AppConfig, String) {
  case source {
    CclSource(ccl_text) -> load_from_ccl(ccl_text)
    JsonSource(json_text) -> load_from_json(json_text)
  }
}

pub fn load_from_ccl(ccl_text: String) -> Result(AppConfig, String) {
  use entries <- result.try(ccl.parse(ccl_text))
  let config = ccl.make_objects(entries)
  
  use database_host <- result.try(ccl.get(config, "database.host"))
  use port_str <- result.try(ccl.get(config, "server.port"))
  use port <- result.try(case port_str {
    ccl.CclString(s) -> int.parse(s) |> result.map_error(fn(_) { "Invalid port" })
    _ -> Error("Port must be string")
  })
  
  case database_host {
    ccl.CclString(host) -> Ok(AppConfig(database_host: host, server_port: port))
    _ -> Error("Database host must be string")
  }
}
```

The Gleam CCL implementation provides powerful type-safe configuration loading with comprehensive error handling and flexible data access patterns.