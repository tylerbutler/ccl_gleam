# Migration Guide to CCL

How to migrate from JSON, YAML, TOML, and environment variables to CCL.

## Why Migrate to CCL?

CCL offers several advantages over traditional configuration formats:

- **Comments and Documentation** - Unlike JSON, CCL supports rich inline documentation
- **Simpler Syntax** - Less verbose than XML or TOML, cleaner than YAML
- **Type Safety** - With Gleam, get compile-time configuration validation
- **Hierarchical Organization** - Better structure than environment variables
- **Duplicate Key Handling** - Unique merge semantics for flexible configuration

## From JSON to CCL

### Basic Structure Migration

**Before (config.json):**
```json
{
  "app": {
    "name": "MyApplication", 
    "version": "1.2.3",
    "debug": true
  },
  "server": {
    "host": "localhost",
    "port": 8080,
    "ssl": {
      "enabled": true,
      "cert_file": "/path/to/cert.pem"
    }
  },
  "database": {
    "connections": [
      "postgres://db1.example.com/myapp",
      "postgres://db2.example.com/myapp"
    ]
  }
}
```

**After (config.ccl):**
```ccl
/= Application Configuration
app.name = MyApplication
app.version = 1.2.3
app.debug = true

/= Server Configuration  
server.host = localhost
server.port = 8080
server.ssl.enabled = true
server.ssl.cert_file = /path/to/cert.pem

/= Database Configuration
database.connections =
  = postgres://db1.example.com/myapp
  = postgres://db2.example.com/myapp
```

### Migration Code

Convert JSON programmatically to CCL:

```gleam
import gleam/json
import gleam/dynamic

pub fn json_to_ccl_entries(json_string: String) -> Result(List(ccl.Entry), String) {
  case json.decode(json_string, dynamic.dynamic) {
    Ok(json_value) -> {
      flatten_json_value("", json_value, [])
      |> Ok()
    }
    Error(_) -> Error("Invalid JSON")
  }
}

fn flatten_json_value(prefix: String, value: Dynamic, acc: List(ccl.Entry)) -> List(ccl.Entry) {
  case dynamic.classify(value) {
    "String" -> {
      let string_val = dynamic.string(value) |> result.unwrap("")
      [ccl.Entry(prefix, string_val), ..acc]
    }
    "Int" -> {
      let int_val = dynamic.int(value) |> result.unwrap(0) |> int.to_string()
      [ccl.Entry(prefix, int_val), ..acc]
    }
    "Bool" -> {
      let bool_val = dynamic.bool(value) |> result.unwrap(False) |> bool.to_string()
      [ccl.Entry(prefix, bool_val), ..acc]
    }
    "List" -> {
      let list_val = dynamic.list(dynamic.dynamic)(value) |> result.unwrap([])
      flatten_json_list(prefix, list_val, acc)
    }
    "Dict" -> {
      let dict_val = dynamic.dict(dynamic.string, dynamic.dynamic)(value) |> result.unwrap([])
      flatten_json_dict(prefix, dict_val, acc)
    }
    _ -> acc
  }
}

fn flatten_json_dict(prefix: String, dict: List(#(String, Dynamic)), acc: List(ccl.Entry)) -> List(ccl.Entry) {
  list.fold(dict, acc, fn(entry_acc, item) {
    let #(key, value) = item
    let new_prefix = case prefix {
      "" -> key
      _ -> prefix <> "." <> key
    }
    flatten_json_value(new_prefix, value, entry_acc)
  })
}

fn flatten_json_list(prefix: String, json_list: List(Dynamic), acc: List(ccl.Entry)) -> List(ccl.Entry) {
  list.fold(json_list, acc, fn(entry_acc, item) {
    case dynamic.string(item) {
      Ok(str_val) -> [ccl.Entry(prefix, str_val), ..entry_acc]
      Error(_) -> entry_acc
    }
  })
}
```

## From YAML to CCL

### Hierarchical Structure

**Before (config.yaml):**
```yaml
# Application settings
app:
  name: MyApplication
  version: "1.2.3"
  debug: true
  
# Server settings
server:
  host: localhost
  port: 8080
  middlewares:
    - cors
    - authentication
    - logging
    
# Database settings
database:
  primary:
    host: db1.example.com
    port: 5432
  replica:
    host: db2.example.com  
    port: 5432
```

**After (config.ccl):**
```ccl
/= Application settings
app.name = MyApplication
app.version = 1.2.3
app.debug = true

/= Server settings
server.host = localhost
server.port = 8080
server.middlewares =
  = cors
  = authentication
  = logging

/= Database settings
database.primary.host = db1.example.com
database.primary.port = 5432
database.replica.host = db2.example.com
database.replica.port = 5432
```

### Alternative: Nested Sections

You can also use CCL's nested section syntax for complex hierarchies:

```ccl
/= Application settings
app =
  name = MyApplication
  version = 1.2.3
  debug = true

/= Server settings  
server =
  host = localhost
  port = 8080
  middlewares =
    = cors
    = authentication
    = logging

/= Database settings
database =
  primary =
    host = db1.example.com
    port = 5432
  replica =
    host = db2.example.com
    port = 5432
```

**Key Differences from YAML:**
- YAML indentation becomes either dot notation OR CCL nested sections (your choice)
- YAML lists (`- item`) become CCL lists (`= item`)
- YAML comments (`#`) must become CCL comment keys (`/=`, `#=`)
- YAML's null values need explicit handling in CCL

**Processing Differences:**
- **Dot notation**: Works directly with `ccl.parse()`, keys are literal strings
- **Nested sections**: Require `ccl.make_objects()` to process hierarchical structure
- **Result**: Both produce the same accessible data after processing

## From TOML to CCL

### Section-Based Configuration

**Before (config.toml):**
```toml
[app]
name = "MyApplication"
version = "1.2.3"
debug = true

[server]
host = "localhost"
port = 8080

[server.ssl]
enabled = true
cert_file = "/path/to/cert.pem"

[database]
hosts = ["localhost", "replica.example.com"]

[database.primary]
host = "localhost"
port = 5432
```

**After (config.ccl):**
```ccl
/= Application configuration
app.name = MyApplication
app.version = 1.2.3
app.debug = true

/= Server configuration
server.host = localhost
server.port = 8080
server.ssl.enabled = true
server.ssl.cert_file = /path/to/cert.pem

/= Database configuration
database.hosts =
  = localhost
  = replica.example.com

database.primary.host = localhost
database.primary.port = 5432
```

**Migration Patterns:**
- TOML sections (`[database]`) become CCL prefixes (`database.`) or nested sections
- TOML arrays become CCL list syntax (`= item`)
- TOML quoted strings lose quotes in CCL (all values are strings)
- TOML nested sections (`[server.ssl]`) become dot notation (`server.ssl.`) or nested sections

**Processing Choice:**
- **Dot notation approach**: Direct key conversion, works with `ccl.parse()` alone
- **Nested section approach**: Requires `ccl.make_objects()` but provides better structure

## From Environment Variables to CCL

### Flat to Hierarchical

**Before (.env):**
```bash
APP_NAME=MyApplication
APP_VERSION=1.2.3  
APP_DEBUG=true
SERVER_HOST=localhost
SERVER_PORT=8080
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_NAME=myapp_dev
DATABASE_URLS=postgres://db1:5432/myapp,postgres://db2:5432/myapp
```

**After (config.ccl):**
```ccl
/= Application Configuration
app.name = MyApplication
app.version = 1.2.3
app.debug = true

/= Server Configuration
server.host = localhost
server.port = 8080

/= Database Configuration  
database.host = localhost
database.port = 5432
database.name = myapp_dev
database.urls =
  = postgres://db1:5432/myapp
  = postgres://db2:5432/myapp
```

### Environment Variable Migration Code

Convert environment variables programmatically:

```gleam
import gleam/os
import gleam/string

pub fn env_to_ccl_entries(prefix: String) -> List(ccl.Entry) {
  os.get_env()
  |> dict.to_list()
  |> list.filter_map(fn(entry) {
    let #(key, value) = entry
    case string.starts_with(key, prefix) {
      True -> {
        let ccl_key = key
          |> string.drop_left(string.length(prefix))
          |> string.lowercase()
          |> string.replace("_", ".")
        
        Ok(ccl.Entry(ccl_key, value))
      }
      False -> Error(Nil)
    }
  })
}

// Usage: Convert all APP_ environment variables to CCL
let app_entries = env_to_ccl_entries("APP_")
let config = ccl.make_objects(app_entries)
```

## Gradual Migration Strategy

### Phase 1: Parallel Configuration

Run both old and new configuration systems simultaneously:

```gleam
pub type ConfigSource {
  JsonConfig(String)
  CclConfig(String)
}

pub fn load_config(source: ConfigSource) -> Result(AppConfig, String) {
  case source {
    JsonConfig(json_text) -> load_from_json(json_text)
    CclConfig(ccl_text) -> load_from_ccl(ccl_text)
  }
}

pub fn load_from_either(json_file: String, ccl_file: String) -> AppConfig {
  case simplifile.exists(ccl_file) {
    True -> {
      case simplifile.read(ccl_file) |> result.try(load_from_ccl) {
        Ok(config) -> config
        Error(_) -> load_fallback_json(json_file)
      }
    }
    False -> load_fallback_json(json_file)
  }
}
```

### Phase 2: Configuration Validation

Ensure both formats produce identical results:

```gleam
pub fn validate_migration(json_file: String, ccl_file: String) -> Bool {
  case #(load_json_config(json_file), load_ccl_config(ccl_file)) {
    #(Ok(json_config), Ok(ccl_config)) -> {
      configs_are_equivalent(json_config, ccl_config)
    }
    _ -> False
  }
}

fn configs_are_equivalent(config1: AppConfig, config2: AppConfig) -> Bool {
  config1.database_host == config2.database_host
  && config1.server_port == config2.server_port
  && config1.debug_mode == config2.debug_mode
  // ... compare all fields
}
```

### Phase 3: Complete Migration

Remove old configuration loading code and use CCL exclusively:

```gleam
pub fn load_production_config() -> AppConfig {
  let config_file = case os.get_env("CONFIG_FORMAT") {
    Ok("json") -> "config.json"  // Temporary fallback
    _ -> "config.ccl"           // Default to CCL
  }
  
  case load_config_file(config_file) {
    Ok(config) -> config
    Error(err) -> {
      io.println("Failed to load " <> config_file <> ": " <> err)
      panic as "Configuration error"
    }
  }
}
```

## Migration Checklist

### JSON → CCL
- [ ] Convert objects to dot notation or nested sections
- [ ] Convert arrays to CCL list syntax (`= item`)
- [ ] Add documentation using comment keys (`/=`)
- [ ] Update parsing code to use CCL library
- [ ] Test edge cases (null values, empty objects)

### YAML → CCL  
- [ ] Convert indentation to dot notation or CCL sections
- [ ] Replace YAML lists with CCL list syntax
- [ ] Convert YAML comments to CCL comment keys
- [ ] Handle YAML-specific features (multiline strings, anchors)
- [ ] Update schema validation

### Environment Variables → CCL
- [ ] Group related variables into hierarchical structure
- [ ] Convert underscore separation to dot notation
- [ ] Handle comma-separated values as CCL lists
- [ ] Maintain backward compatibility during transition
- [ ] Update deployment scripts

### TOML → CCL
- [ ] Convert TOML sections to CCL prefixes or nested sections
- [ ] Transform TOML arrays to CCL lists
- [ ] Remove quote requirements (all CCL values are strings)
- [ ] Handle TOML datetime values appropriately

## Best Practices

1. **Start Small** - Migrate one configuration section at a time
2. **Validate Thoroughly** - Compare outputs between old and new formats
3. **Document Changes** - Use CCL's comment system to explain migration decisions
4. **Test Edge Cases** - Pay attention to empty values, special characters
5. **Maintain Compatibility** - Keep old format support during transition period
6. **Use Type Safety** - Leverage Gleam's type system for configuration validation

CCL's simple syntax and powerful features make migration straightforward while providing better maintainability and documentation capabilities.