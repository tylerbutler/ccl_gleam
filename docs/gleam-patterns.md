# Advanced Gleam Patterns for CCL

Advanced configuration patterns using Gleam's type system and functional programming features.

## Type-Safe Configuration Structs

### Building Strongly-Typed Configuration

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

### Environment-Specific Configuration Loading

```gleam
import gleam/os

pub fn load_env_config(config: ccl.CCL, environment: String) -> Result(DatabaseConfig, String) {
  let env_path = environment <> ".database"
  
  use host <- result.try(ccl.get_string(config, env_path <> ".host"))
  use port <- result.try(ccl.get_int(config, env_path <> ".port"))
  
  // Optional settings with defaults
  let pool_size = ccl.get_int(config, env_path <> ".pool_size")
    |> result.unwrap(10)
    
  let ssl_enabled = ccl.get_bool(config, env_path <> ".ssl_enabled")
    |> result.unwrap(False)
    
  Ok(DatabaseConfig(
    host: host,
    port: port,
    username: "app", // from environment variable
    password: os.get_env("DB_PASSWORD") |> result.unwrap(""),
    ssl_enabled: ssl_enabled,
    pool_size: pool_size,
    timeout: 30.0
  ))
}

// Usage
pub fn load_for_environment() -> Result(DatabaseConfig, String) {
  let env = os.get_env("APP_ENV") |> result.unwrap("development")
  
  use content <- result.try(simplifile.read("config/" <> env <> ".ccl"))
  use entries <- result.try(ccl.parse(content))
  let config = ccl.build_hierarchy(entries)
  
  load_env_config(config, env)
}
```

## Advanced Error Handling

### Comprehensive Configuration Validation

```gleam
pub type ConfigError {
  ParseError(String)
  ValidationError(String, String)  // path, error message
  MissingRequired(String)
  TypeMismatch(String, String)     // path, expected type
}

pub fn validate_config(config_text: String) -> Result(AppConfig, List(ConfigError)) {
  case ccl.parse(config_text) {
    Error(parse_err) -> Error([ParseError("Failed to parse CCL: " <> parse_err.reason)])
    Ok(entries) -> {
      let config = ccl.build_hierarchy(entries)
      let errors = []
      
      // Validate required fields
      let errors = case ccl.get_string(config, "app.name") {
        Ok(_) -> errors
        Error(_) -> [MissingRequired("app.name"), ..errors]
      }
      
      // Validate types with custom constraints
      let errors = case ccl.get_int(config, "server.port") {
        Ok(port) if port > 0 && port < 65536 -> errors
        Ok(_) -> [ValidationError("server.port", "Port must be between 1 and 65535"), ..errors]
        Error(_) -> [TypeMismatch("server.port", "integer"), ..errors]
      }
      
      // Validate string patterns
      let errors = case ccl.get_string(config, "database.host") {
        Ok(host) if string.length(host) > 0 -> errors
        Ok(_) -> [ValidationError("database.host", "Host cannot be empty"), ..errors]
        Error(_) -> [MissingRequired("database.host"), ..errors]
      }
      
      case errors {
        [] -> Ok(build_config(config))
        _ -> Error(list.reverse(errors))
      }
    }
  }
}

// Usage with comprehensive error reporting
pub fn load_validated_config() -> AppConfig {
  case simplifile.read("app.ccl") {
    Ok(content) -> {
      case validate_config(content) {
        Ok(config) -> {
          io.println("✅ Configuration loaded successfully")
          config
        }
        Error(errors) -> {
          io.println("❌ Configuration errors:")
          list.each(errors, log_config_error)
          panic as "Fix configuration errors and restart"
        }
      }
    }
    Error(_) -> {
      io.println("❌ Could not read configuration file")
      panic as "Configuration file is required"
    }
  }
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

## Smart List Handling

### Flexible List Access Patterns

```gleam
pub fn get_string_list(config: ccl.CCL, path: String) -> List(String) {
  case ccl.get(config, path) {
    Ok(ccl.CclString(single_value)) -> [single_value]
    Ok(ccl.CclList(values)) -> values
    _ -> []
  }
}

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

// Usage examples
let hosts = get_string_list(config, "database.hosts")
// Works with both single host and list of hosts

let primary_host = get_primary_value(config, "database.hosts")
// Always gets a single string, whether config has one host or many
```

### List Processing with Metadata

```gleam
pub type ServerInfo {
  ServerInfo(name: String, region: String, capacity: String)
}

pub fn load_servers_with_config(config: ccl.CCL) -> List(ServerInfo) {
  let server_names = get_string_list(config, "services.web_servers")
  
  list.map(server_names, fn(server_name) {
    let config_path = "services.server_config." <> server_name
    
    let region = ccl.get_string(config, config_path <> ".region")
      |> result.unwrap("unknown")
      
    let capacity = ccl.get_string(config, config_path <> ".capacity")
      |> result.unwrap("medium")
      
    ServerInfo(name: server_name, region: region, capacity: capacity)
  })
}
```

## Configuration Composition Patterns

### Multi-File Configuration Loading

```gleam
pub fn load_combined_config(
  base_file: String,
  override_file: String
) -> Result(ccl.CCL, String) {
  use base_content <- result.try(simplifile.read(base_file))
  use override_content <- result.try(simplifile.read(override_file))
  
  use base_entries <- result.try(ccl.parse(base_content))
  use override_entries <- result.try(ccl.parse(override_content))
  
  // Combine entries - overrides take precedence
  let combined = ccl.combine(base_entries, override_entries)
  let filtered = ccl.filter(combined)
  
  Ok(ccl.build_hierarchy(filtered))
}

// Environment-aware composition
pub fn load_config_with_overrides() -> Result(ccl.CCL, String) {
  let env = os.get_env("APP_ENV") |> result.unwrap("development")
  let base_file = "config/base.ccl"
  let env_file = "config/" <> env <> ".ccl"
  let local_file = "config/local.ccl"
  
  // Try base + environment + local (each layer optional except base)
  use base_config <- result.try(load_single_config(base_file))
  
  let with_env = case load_single_config(env_file) {
    Ok(env_config) -> merge_configs(base_config, env_config)
    Error(_) -> base_config
  }
  
  let final_config = case load_single_config(local_file) {
    Ok(local_config) -> merge_configs(with_env, local_config)
    Error(_) -> with_env
  }
  
  Ok(final_config)
}

fn load_single_config(file_path: String) -> Result(ccl.CCL, String) {
  use content <- result.try(simplifile.read(file_path))
  use entries <- result.try(ccl.parse(content))
  Ok(ccl.build_hierarchy(ccl.filter(entries)))
}

fn merge_configs(base: ccl.CCL, override: ccl.CCL) -> ccl.CCL {
  // Implementation would merge two CCL objects
  // Override values take precedence over base values
  dict.fold(override, base, fn(acc, key, value) {
    dict.insert(acc, key, value)
  })
}
```

## Functional Configuration Patterns

### Configuration Pipeline

```gleam
pub fn load_config_pipeline() -> Result(AppConfig, String) {
  "config/app.ccl"
  |> simplifile.read()
  |> result.try(ccl.parse)
  |> result.map(ccl.filter)
  |> result.map(ccl.build_hierarchy)
  |> result.try(validate_and_build_config)
}

fn validate_and_build_config(config: ccl.CCL) -> Result(AppConfig, String) {
  use app_name <- result.try(ccl.get_string(config, "app.name"))
  use server_port <- result.try(ccl.get_int(config, "server.port"))
  use database_config <- result.try(load_database_config(config))
  
  Ok(AppConfig(
    name: app_name,
    port: server_port,
    database: database_config
  ))
}
```

### Configuration Transformation

```gleam
pub fn transform_config(config: ccl.CCL) -> ccl.CCL {
  config
  |> expand_environment_variables()
  |> normalize_paths()
  |> apply_defaults()
}

fn expand_environment_variables(config: ccl.CCL) -> ccl.CCL {
  // Replace ${VAR} patterns with environment variable values
  dict.map_values(config, fn(value) {
    case value {
      ccl.CclString(str) -> ccl.CclString(expand_env_vars(str))
      ccl.CclList(strings) -> ccl.CclList(list.map(strings, expand_env_vars))
      ccl.CclObject(nested) -> ccl.CclObject(expand_environment_variables(nested))
    }
  })
}

fn expand_env_vars(text: String) -> String {
  // Simple ${VAR} expansion implementation
  case string.contains(text, "${") {
    True -> {
      // Implementation would find and replace ${VAR} patterns
      text  // placeholder
    }
    False -> text
  }
}
```

## Testing Patterns

### Property-Based Configuration Testing

```gleam
import gleam_community/maths/float as float_maths

pub fn test_config_defaults_property() {
  // Property: Default values should always be valid
  let config_with_minimal_fields = "app.name = TestApp"
  
  case ccl.parse(config_with_minimal_fields) {
    Ok(entries) -> {
      let config = ccl.build_hierarchy(entries)
      let app_config = build_app_config_with_defaults(config)
      
      // Assert that defaults produce valid configuration
      app_config.port |> should_be_positive_int()
      app_config.timeout |> should_be_positive_float()
      string.length(app_config.host) |> should_be_greater_than(0)
    }
    Error(_) -> should.fail()
  }
}

pub fn test_config_composition_associativity() {
  // Property: Configuration composition should be associative
  let config_a = "key1 = a\nshared = from_a"
  let config_b = "key2 = b\nshared = from_b"  
  let config_c = "key3 = c\nshared = from_c"
  
  let assert Ok(entries_a) = ccl.parse(config_a)
  let assert Ok(entries_b) = ccl.parse(config_b)
  let assert Ok(entries_c) = ccl.parse(config_c)
  
  // (A + B) + C should equal A + (B + C)
  let left = ccl.combine(ccl.combine(entries_a, entries_b), entries_c)
  let right = ccl.combine(entries_a, ccl.combine(entries_b, entries_c))
  
  ccl.build_hierarchy(left) |> should.equal(ccl.build_hierarchy(right))
}

// Helper validation functions
fn should_be_positive_int(value: Int) {
  case value > 0 {
    True -> Nil
    False -> panic as "Expected positive integer"
  }
}

fn should_be_positive_float(value: Float) {
  case float_maths.compare(value, 0.0) {
    order.Gt -> Nil
    _ -> panic as "Expected positive float"
  }
}

fn should_be_greater_than(actual: Int, expected: Int) {
  case actual > expected {
    True -> Nil
    False -> panic as "Expected greater than"
  }
}
```

### Mock Configuration for Testing

```gleam
pub fn create_test_config() -> ccl.CCL {
  let test_config_text = "
    app.name = TestApp
    app.version = 1.0.0
    
    database.host = test-db
    database.port = 5433
    database.name = test_db
    
    server.port = 3001
    server.debug = true
    
    features.enabled =
      = feature_a
      = feature_b
  "
  
  let assert Ok(entries) = ccl.parse(test_config_text)
  ccl.build_hierarchy(ccl.filter(entries))
}

pub fn test_feature_flag_loading() {
  let config = create_test_config()
  
  let enabled_features = get_string_list(config, "features.enabled")
  
  enabled_features |> should.contain("feature_a")
  enabled_features |> should.contain("feature_b")
  list.length(enabled_features) |> should.equal(2)
}
```

These advanced patterns demonstrate how Gleam's type system and functional programming features can be leveraged to create robust, maintainable configuration handling code with CCL.