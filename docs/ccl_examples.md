# CCL Examples - Comprehensive Reference

**📚 This comprehensive reference has been reorganized into focused guides:**

## Quick Navigation

### 🚀 Getting Started
**New to CCL?** Start here for a gentle introduction:
- **[Getting Started with CCL](getting-started.md)** - Basic syntax, first Gleam program, simple examples

### 🏗️ Building Complex Configurations  
**Ready for advanced patterns?** Learn complex configuration structures:
- **[Advanced CCL Patterns](advanced-patterns.md)** - Nested structures, environment configs, documentation

### ⚡ Gleam-Specific Features
**Want type safety and advanced error handling?** Explore Gleam enhancements:
- **[Gleam Features Guide](gleam-features.md)** - Type-safe parsing, smart accessors, configuration composition

### 🔄 Migrating from Other Formats
**Moving from JSON, YAML, or environment variables?** Get migration guidance:
- **[Migration Guide](migration-guide.md)** - Convert from JSON, YAML, TOML, environment variables

---

## Why the Split?

This original 1,200+ line file was overwhelming for users. The new focused guides provide:

- **Faster Learning** - Start simple, progress to advanced
- **Better Navigation** - Find exactly what you need
- **Clearer Organization** - Separate language concepts from implementation details
- **Practical Focus** - Each guide solves specific problems

## Original Content

The sections below contain the complete original examples for reference, but we recommend using the focused guides above for better learning experience.

---

# Part I: Core CCL Language

This section covers the universal CCL language specification that works across all implementations.

## Basic CCL Syntax

### Simple Key-Value Pairs

CCL uses a simple `key = value` syntax for basic configuration:

```ccl
# Basic configuration
app_name = MyApplication
version = 1.2.3
debug = true
port = 8080
```

**Language Features:**
- Keys can contain letters, numbers, dots, and underscores
- Values are stored as strings but can represent different data types
- Whitespace around `=` is optional
- Lines starting with `#` are treated as regular keys (not comments in core CCL)

### Multiline Values

CCL supports continuation lines for multiline values using indentation:

```ccl
description = A comprehensive example
  of a multiline value that spans
  multiple lines with preserved indentation

welcome_message = Welcome to our application!
  
  Please read the documentation carefully
  before getting started.
```

**Language Features:**
- Continuation lines must be indented with at least one space or tab
- Leading whitespace on continuation lines is preserved
- Empty lines within multiline values are preserved
- The final value includes literal newlines and indentation

## Core Language Features

### Real-World Configuration Example (Indented)

CCL handles complex configuration using nested sections and various data types:

```ccl
/= Web server configuration
server =
  name = production-api
  bind_address = 0.0.0.0
  port = 8080
  
  ssl =
    enabled = true
    cert = /path/to/certificate.pem
    key = /path/to/private-key.pem

/= Logging configuration
logging =
  level = info
  files =
    app_log = /var/log/app.log
    access_log = /var/log/access.log

/= Security settings
security =
  csrf_protection = on
  rate_limiting = true
  max_requests_per_minute = 1000

/= Cache configuration
cache =
  enabled = true
  ttl = 300
```

**Language Features:**
- All values are strings at the language level: `8080`, `true`, `on`
- No distinction between string, number, or boolean types in core CCL
- Applications interpret string values as needed
- Indented sections create logical groupings
- Comments use `/=` for visual organization

### Hierarchical Organization (Indented)

CCL supports hierarchical organization using nested sections:

```ccl
/= Database configuration
database =
  host = localhost
  port = 5432
  name = myapp_production
  username = dbuser
  password = secure_password123
  ssl = true
  pool_size = 20
  timeout = 30.5

/= Redis configuration
redis =
  host = redis.example.com
  port = 6379
  database = 0
  password = redis_password
```

**Alternative: Dot Notation for Flat Keys**
```ccl
# Database configuration (flat dot notation)
database.host = localhost
database.port = 5432
database.name = myapp_production
database.username = dbuser
database.password = secure_password123
database.ssl = true
database.pool_size = 20
database.timeout = 30.5

# Redis configuration (flat dot notation)
redis.host = redis.example.com
redis.port = 6379
redis.database = 0
redis.password = redis_password
```

**Comparing Approaches:**
- **Indented sections:** Less verbose, better readability, requires `ccl.make_objects()` processing
- **Dot notation:** More explicit, works with raw entries, longer key names
- **Both approaches** result in the same accessible data structure after processing
- **Recommendation:** Use indented sections for complex configurations, dot notation for simple flat structures

### Empty Values

CCL handles empty values explicitly:

```ccl
# Values with content
api_key = abc123def456
error_message = Something went wrong!

# Empty value (everything after = is whitespace)
empty_value = 

# Continuation line that's empty
multiline_with_empty = First line
  
  Third line
```

**Language Features:**
- Empty values are distinct from missing keys
- Trailing whitespace after `=` is trimmed for empty values
- Empty continuation lines are preserved in multiline values
- Applications decide how to interpret empty values

## Lists and Arrays

### Simple Lists (Indented)

CCL represents lists using empty keys (`=`) with indented values:

```ccl
/= Network configuration
network =
  allowed_hosts =
    = localhost
    = 127.0.0.1
    = example.com
    = api.example.com
  
  ports =
    = 80
    = 443
    = 8080
    = 3000
```

**Alternative: Flat List Structure**
```ccl
# List using empty keys (flat structure)
allowed_hosts =
  = localhost
  = 127.0.0.1
  = example.com
  = api.example.com

# Port list (flat structure)
ports =
  = 80
  = 443
  = 8080
  = 3000
```

**Language Features:**
- Lists start with a named key followed by `=` and whitespace
- List items use indented `= value` syntax
- List items are ordered as they appear in the file
- Each list item value follows the same rules as regular values
- Lists can be nested within sections for better organization

### Array-Style Lists

Alternative list representation using indexed keys:

```ccl
# Array-style configuration
servers.0 = web-1.example.com
servers.1 = web-2.example.com
servers.2 = web-3.example.com

database_urls.0 = postgres://db1.example.com/myapp
database_urls.1 = postgres://db2.example.com/myapp
```

**Language Features:**
- Uses dot notation with numeric suffixes: `.0`, `.1`, `.2`
- Each indexed entry is a separate key-value pair
- No special array syntax - just naming convention
- Applications must interpret numeric suffixes as array indices

### Complex List Structures (Indented)

Combining lists with nested sections for complex data:

```ccl
/= Feature configuration
features =
  enabled =
    = user_registration
    = email_notifications  
    = advanced_search
  
  beta =
    = beta_dashboard

feature_config =
  user_registration =
    enabled = true
    rollout_percentage = 100
  
  email_notifications =
    enabled = true
    rollout_percentage = 80
  
  beta_dashboard =
    enabled = false
    rollout_percentage = 5
```

**Alternative: Flat Structure with Dot Notation**
```ccl
# Feature flags with metadata (flat structure)
features =
  = user_registration
  = email_notifications  
  = advanced_search
  = beta_dashboard

feature_config.user_registration.enabled = true
feature_config.user_registration.rollout_percentage = 100

feature_config.beta_dashboard.enabled = false
feature_config.beta_dashboard.rollout_percentage = 5
```

**Language Features:**
- Lists can be organized within nested sections
- Hierarchical structure makes relationships clearer
- Both indented and dot notation approaches work
- Indented sections provide better visual organization
- Applications interpret relationships between keys

## Nested Configuration

### Indented Nested Sections

CCL supports true structural nesting using indentation syntax:

```ccl
/= Application configuration with indented nested sections
app =
  name = MyApplication
  version = 2.1.0
  debug = false
  
  server =
    host = 0.0.0.0
    port = 8080
    
    ssl =
      enabled = true
      cert_file = /etc/ssl/cert.pem
      key_file = /etc/ssl/private.key
  
  database =
    primary =
      host = db1.example.com
      port = 5432
      name = myapp_prod
    
    replica =
      host = db2.example.com
      port = 5432
      name = myapp_prod
```

**Language Features:**
- True structural nesting using indentation
- Empty values (`app =`) indicate nested sections
- Indented key-value pairs belong to the parent section
- Nested sections can contain other nested sections
- Indentation level determines hierarchy depth
- **Note:** Indented nested sections require `ccl.make_objects()` to process the hierarchical structure

### Hierarchical Configuration (Dot Notation)

Alternative approach using dot notation for flat key representation:

```ccl
# Application configuration with dot notation
app.name = MyApplication
app.version = 2.1.0
app.debug = false

app.server.host = 0.0.0.0
app.server.port = 8080
app.server.ssl.enabled = true
app.server.ssl.cert_file = /etc/ssl/cert.pem
app.server.ssl.key_file = /etc/ssl/private.key

app.database.primary.host = db1.example.com
app.database.primary.port = 5432
app.database.primary.name = myapp_prod

app.database.replica.host = db2.example.com  
app.database.replica.port = 5432
app.database.replica.name = myapp_prod
```

**Language Features:**
- Deep hierarchies created through dot notation: `app.server.ssl.enabled`
- Each dotted key is independent - no structural nesting
- Hierarchy is purely naming convention, not syntax
- All keys remain flat strings at the language level
- **Advantage:** Works directly with parsed entries, no `make_objects()` required

### Environment-Specific Configuration (Indented)

Using indented sections to organize environment-specific settings:

```ccl
/= Base configuration
app_name = MyApp
version = 1.0.0

/= Development environment
development =
  debug = true
  log_level = debug
  
  database =
    host = localhost
    port = 5432
  
  cache =
    enabled = false

/= Production environment
production =
  debug = false
  log_level = warning
  
  database =
    host = prod-db.example.com
    port = 5432
  
  cache =
    enabled = true
    
    redis =
      host = redis-cluster.example.com
```

### Environment-Specific Configuration (Dot Notation)

Alternative flat approach using prefixes:

```ccl
# Base configuration
app_name = MyApp
version = 1.0.0

# Development environment
development.debug = true
development.database.host = localhost
development.database.port = 5432
development.log_level = debug
development.cache.enabled = false

# Production environment
production.debug = false
production.database.host = prod-db.example.com
production.database.port = 5432
production.log_level = warning
production.cache.enabled = true
production.cache.redis.host = redis-cluster.example.com
```

**Language Features:**
- Both indented sections and dot notation create hierarchy
- Environment prefixes: `development.`, `production.`
- Global keys without prefixes serve as defaults
- Applications choose which prefixed keys to prioritize
- No built-in environment resolution - just naming patterns

## Comments and Documentation

### Using Special Keys for Comments

CCL uses special key names for documentation and comments. The standard comment key is `/`, but any key can be used as a comment:

```ccl
/= Application Configuration
/= Version: 2.1.0
/= Last updated: 2024-01-15

app_name = MyApplication
/= The display name for the application

version = 2.1.0

/= Security Configuration
/= These settings control authentication and authorization
security.jwt.secret = your-super-secret-key-here
security.jwt.expiration = 3600
#= Expiration time in seconds
security.password.min_length = 8
security.password.require_special_chars = true

//= Database Configuration (alternative comment style)
//= Primary database connection settings
database.host = localhost
database.port = 5432

/= Redis Configuration
redis.host = localhost
redis.port = 6379
redis.database = 0
/= Redis database number (0-15)
```

**Language Features:**
- Standard comment key: `/=` (most common)
- Alternative comment keys: `#=`, `//=`, etc. (any key works)
- Comments are regular key-value pairs in core CCL
- Comments can appear before, after, or between configuration values
- No special comment syntax - just naming convention
- Applications filter comment keys as needed
- Values after comment keys can be multiline

### Flexible Documentation Patterns (Indented)

Comments can appear anywhere in the configuration - before, after, or between values:

```ccl
/= API Configuration Section
api =
  /= Rate limit: requests per minute per IP address
  rate_limit = 100
  
  /= Connection timeout in seconds
  timeout = 30.0

/= Database Configuration
database =
  /= Maximum number of database connections in the pool
  pool_size = 20
  
  /= Query timeout in seconds - adjust based on your query complexity
  query_timeout = 10
  /= This setting affects performance significantly
```

**Alternative: Flat Structure with Comments**
```ccl
/= API Configuration Section
api.rate_limit = 100
/= Rate limit: requests per minute per IP address

/= Connection timeout in seconds
api.timeout = 30.0

database.pool_size = 20
#= Maximum number of database connections in the pool

#= Query timeout in seconds - adjust based on your query complexity
database.query_timeout = 10
/= This setting affects performance significantly
```

**Language Features:**
- Comments can be placed before, after, or between configuration values
- No association between regular keys and comment keys in core CCL
- Positional documentation is purely conventional
- Applications may use position to link docs to values
- Flexible placement allows for both section headers and inline documentation

## Gleam API Usage

### Basic Parsing and Access

```ccl
/= Basic application configuration
app =
  name = MyApplication
  version = 1.2.3
  debug = true
  port = 8080
```

```gleam
// Parse CCL text into entry list, then create accessible object
let config = ccl.parse(ccl_text)
  |> result.unwrap([])
  |> ccl.make_objects()  // Required for nested structure access

// Access nested values using dot notation (works with indented structure)
let app_name = ccl.get_value(config, "app.name") // Ok("MyApplication")
let version = ccl.get_value(config, "app.version")   // Ok("1.2.3")

// Gleam enhancement: Type-aware parsing
let port = ccl.get_int(config, "app.port")           // Ok(8080)
let debug = ccl.get_bool(config, "app.debug")        // Ok(True)

// Alternative: Skip make_objects() for flat dot notation
let entries = ccl.parse(flat_dot_ccl_text) |> result.unwrap([])
// Direct access to entries without hierarchical processing
```

**Gleam Enhancements:**
- `ccl.parse()` - Parses CCL text to entry list
- `ccl.make_objects()` - **Required** for nested sections, processes hierarchical structure
- `ccl.get_value()` - Gets raw string value (core CCL)
- `ccl.get_int()`, `ccl.get_bool()`, `ccl.get_float()` - Type-safe parsing
- **Processing choice:** Use `make_objects()` for nested sections, skip for simple flat structures

### Working with Configuration Objects

```ccl
/= Service configuration
services =
  database =
    host = localhost
    port = 5432
    name = myapp_production
    username = dbuser
    password = secure_password123
  
  redis =
    host = redis.example.com
    port = 6379
```

**Alternative: Flat Structure**
```ccl
# Hierarchical configuration (dot notation)
database.host = localhost
database.port = 5432
database.name = myapp_production
database.username = dbuser
database.password = secure_password123
redis.host = redis.example.com
redis.port = 6379
```

```gleam
pub type DatabaseConfig {
  DatabaseConfig(
    host: String,
    port: Int,
    name: String,
    username: String,
    password: String
  )
}

pub fn load_database_config(ccl: ccl.CCL) -> Result(DatabaseConfig, String) {
  // Gleam enhancement: use chaining for clean error handling
  // Works with both indented (services.database.host) and flat (database.host) structures
  use host <- result.try(ccl.get_value(ccl, "services.database.host"))
  use port <- result.try(ccl.get_int(ccl, "services.database.port"))
  use name <- result.try(ccl.get_value(ccl, "services.database.name"))
  use username <- result.try(ccl.get_value(ccl, "services.database.username"))
  use password <- result.try(ccl.get_value(ccl, "services.database.password"))
  
  Ok(DatabaseConfig(
    host: host,
    port: port,
    name: name,
    username: username,
    password: password
  ))
}
```

**Gleam Enhancements:**
- Type-safe configuration structs
- `result.try()` for clean error chaining
- Compile-time verification of field access

### Working with Lists

```ccl
/= Network configuration with lists
network =
  allowed_hosts =
    = localhost
    = 127.0.0.1
    = example.com
  
  ports =
    = 80
    = 443
    = 8080
```

**Alternative: Flat List Structure**
```ccl
# Lists in CCL (flat structure)
allowed_hosts =
  = localhost
  = 127.0.0.1
  = example.com

ports =
  = 80
  = 443
  = 8080
```

```gleam
// Gleam enhancement: List extraction with type conversion
// Works with nested structure: "network.allowed_hosts"
let hosts = ccl.get_list(config, "network.allowed_hosts")
// Ok(["localhost", "127.0.0.1", "example.com"])

// Parse list values as specific types
let ports = ccl.get_list(config, "network.ports")
  |> result.map(list.map(_, int.parse))
  |> result.map(result.values)
// Ok([80, 443, 8080])

// For flat structure, use direct keys:
let flat_hosts = ccl.get_list(config, "allowed_hosts") // Flat structure
let flat_ports = ccl.get_list(config, "ports")         // Flat structure

// Alternative: Array-style access  
let primary_server = ccl.get_value(config, "servers.0")    
let backup_server = ccl.get_value(config, "servers.1")     

// Gleam enhancement: Get all keys with prefix
let all_servers = ccl.get_keys(config, "servers")
  |> list.map(fn(key) { ccl.get_value(config, "servers." <> key) })
  |> result.values
```

**Gleam Enhancements:**
- `ccl.get_list()` - Extract lists from empty-key syntax
- `ccl.get_keys()` - Find keys by prefix pattern
- Integration with Gleam's `list` module for processing

### Nested Configuration Access

```ccl
app.server.host = 0.0.0.0
app.server.port = 8080
app.server.ssl.enabled = true
app.database.primary.host = db1.example.com
```

```gleam
// Direct access to nested values (core CCL approach)
let app_name = ccl.get_value(config, "app.name")                      
let ssl_enabled = ccl.get_bool(config, "app.server.ssl.enabled")      
let primary_db_host = ccl.get_value(config, "app.database.primary.host") 

// Gleam enhancement: Extract nested configuration objects
let server_config = ccl.get_nested(config, "app.server")
case server_config {
  Ok(server) -> {
    let host = ccl.get_value(server, "host")     // Ok("0.0.0.0")
    let port = ccl.get_int(server, "port")       // Ok(8080)
    // Process server configuration...
  }
  Error(err) -> io.println("Server config not found: " <> err)
}
```

**Gleam Enhancements:**
- `ccl.get_nested()` - Extract sub-configurations by prefix
- Hierarchical configuration objects for better organization

## Type-Safe Parsing

### Advanced Type Parsing with Options

```ccl
# Configuration with mixed parsing needs
server.port = 8080
server.timeout = 30.5
server.enabled = true
server.name = production-server
```

```gleam
// Gleam enhancement: Configurable type parsing
let conservative_options = ccl.ParseOptions(
  parse_integers: True,
  parse_floats: False, 
  parse_booleans: False
)

let port = ccl.get_typed_value_with_options(
  config, 
  "server.port", 
  conservative_options
) // Ok(IntVal(8080))

let timeout = ccl.get_typed_value_with_options(
  config, 
  "server.timeout", 
  conservative_options
) // Ok(StringVal("30.5")) - not parsed as float

// Smart parsing (all types enabled)
let smart_options = ccl.smart_options()
let enabled = ccl.get_typed_value_with_options(
  config, 
  "server.enabled", 
  smart_options
) // Ok(BoolVal(True))
```

**Gleam Enhancements:**
- `ParseOptions` type for controlling type inference
- `get_typed_value_with_options()` for fine-grained control
- Conservative vs smart parsing strategies

### Generic Type-Aware Parsing

```ccl
# Mixed data types
max_connections = 100
connection_timeout = 30.5
debug_enabled = true
api_key = abc123def456
empty_value = 
```

```gleam
// Gleam enhancement: Generic typed value extraction
case ccl.get_typed_value(config, "max_connections") {
  Ok(ccl.IntVal(n)) -> io.println("Max connections: " <> int.to_string(n))
  Ok(ccl.StringVal(s)) -> io.println("Got string instead: " <> s)
  Error(err) -> io.println("Error: " <> err)
}

// Handle all possible types
case ccl.get_typed_value(config, "some_key") {
  Ok(ccl.IntVal(i)) -> // Handle integer
  Ok(ccl.FloatVal(f)) -> // Handle float  
  Ok(ccl.BoolVal(b)) -> // Handle boolean
  Ok(ccl.StringVal(s)) -> // Handle string
  Ok(ccl.EmptyVal) -> // Handle empty value
  Error(err) -> // Handle missing/invalid key
}
```

**Gleam Enhancements:**
- `TypedValue` variant type for all possible value types
- Pattern matching on parsed types
- Explicit handling of empty values vs missing keys

### Comment Filtering

```ccl
/= Application Configuration
/= Version: 2.1.0
/= Last updated: 2024-01-15

app_name = MyApplication
version = 2.1.0

/= Security Configuration
security.jwt.secret = your-super-secret-key-here
```

```gleam
// Gleam enhancement: Filter out comment keys for production
let clean_config = ccl.parse(ccl_text)
  |> result.unwrap([])
  |> ccl.filter_keys(["/", "#", "//"])  // Remove comment entries
  |> ccl.make_objects()

// Or keep comments for debugging/documentation
let full_config = ccl.parse(ccl_text)
  |> result.unwrap([])
  |> ccl.make_objects()

// Extract comments for documentation generation
let comments = ccl.parse(ccl_text)
  |> result.unwrap([])
  |> list.filter(fn(entry) { 
      entry.key == "/" || entry.key == "#" || entry.key == "//" 
    })
  |> list.map(fn(entry) { entry.value })
// ["Application Configuration", "Version: 2.1.0", "Last updated: 2024-01-15", ...]
```

**Gleam Enhancements:**
- `ccl.filter_keys()` - Remove keys matching patterns
- Programmable comment extraction
- Flexible filtering for production vs development builds

## Migration Examples

### From JSON to CCL

Converting hierarchical JSON to flat CCL keys:

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

**Migration Pattern:**
- JSON objects become dot-separated keys: `app.name`, `server.ssl.enabled`
- JSON arrays become CCL lists using `=` syntax
- JSON types (`true`, `8080`) become string values in CCL
- Comments replace JSON's lack of comment support

### From YAML to CCL

Flattening YAML hierarchy into CCL dot notation:

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
# Application settings
app.name = MyApplication
app.version = 1.2.3
app.debug = true

# Server settings
server.host = localhost
server.port = 8080
server.middlewares =
  = cors
  = authentication
  = logging

# Database settings
database.primary.host = db1.example.com
database.primary.port = 5432
database.replica.host = db2.example.com
database.replica.port = 5432
```

**Migration Pattern:**
- YAML indentation becomes dot notation: `database.primary.host`
- YAML lists (`- item`) become CCL lists (`= item`)
- YAML comments (`#`) become regular keys in CCL (note the difference!)
- YAML's structural nesting flattens to naming conventions

### From Environment Variables to CCL

Converting flat environment variables to hierarchical CCL:

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
```

**Migration Pattern:**
- Environment variable prefixes become CCL hierarchies: `APP_` → `app.`
- Underscores in env vars become dots: `DATABASE_HOST` → `database.host`
- All environment values are strings, same as CCL values
- CCL allows better organization and documentation than env files

---

# Part II: Gleam CCL Implementation

This section covers Gleam-specific features that enhance the core CCL language with type safety, convenience functions, and advanced parsing options.

## Error Handling

### Graceful Error Handling with Defaults

```ccl
# Configuration with some missing values
server.host = localhost
server.port = 8080
# server.timeout is missing
server.debug = true
```

```gleam
// Gleam enhancement: Default value handling
pub fn load_server_config_with_defaults(config: ccl.CCL) -> ServerConfig {
  let host = ccl.get_value(config, "server.host") 
    |> result.unwrap("localhost")
    
  let port = ccl.get_int(config, "server.port")
    |> result.unwrap(3000)
    
  let timeout = ccl.get_float(config, "server.timeout")
    |> result.unwrap(30.0)
    
  let debug = ccl.get_bool(config, "server.debug")
    |> result.unwrap(False)
    
  ServerConfig(
    host: host,
    port: port, 
    timeout: timeout,
    debug: debug
  )
}
```

**Gleam Enhancements:**
- Type-safe default value fallbacks
- `result.unwrap()` for clean default handling
- Compile-time verification of config struct construction

### Comprehensive Error Reporting

```ccl
# Configuration with various errors
server.port = not_a_number
server.timeout = 30,5  # comma instead of dot
server.enabled = maybe # invalid boolean
database.connections = # empty value
```

```gleam
// Gleam enhancement: Structured error handling
pub type ConfigError {
  ParseError(String)
  ValidationError(String, String)  // path, error
  MissingRequired(String)
}

pub fn load_config_with_validation(ccl_text: String) -> Result(ServerConfig, List(ConfigError)) {
  case ccl.parse(ccl_text) {
    Error(parse_err) -> Error([ParseError(string.inspect(parse_err))])
    Ok(entries) -> {
      let config = ccl.make_objects(entries)
      let errors = []
      
      // Validate required fields
      let errors = case ccl.get_value(config, "server.host") {
        Error(_) -> [MissingRequired("server.host"), ..errors]
        Ok(_) -> errors
      }
      
      // Validate types with detailed error messages
      let errors = case ccl.get_int(config, "server.port") {
        Error(err) -> [ValidationError("server.port", err), ..errors]
        Ok(_) -> errors
      }
      
      case errors {
        [] -> Ok(load_valid_config(config))
        _ -> Error(list.reverse(errors))
      }
    }
  }
}

// Usage with comprehensive error reporting
case load_config_with_validation(config_text) {
  Ok(config) -> {
    io.println("Configuration loaded successfully!")
    config
  }
  Error(errors) -> {
    io.println("Configuration errors found:")
    list.each(errors, fn(error) {
      case error {
        ParseError(msg) -> io.println("Parse error: " <> msg)
        ValidationError(path, msg) -> io.println("At " <> path <> ": " <> msg)
        MissingRequired(path) -> io.println("Required field missing: " <> path)
      }
    })
    panic as "Invalid configuration"
  }
}
```

**Gleam Enhancements:**
- Custom error types for different failure modes
- Batch error collection and reporting
- Path-specific error messages for debugging

## Advanced Gleam Patterns

### Configuration Merging and Composition

```ccl
# base-config.ccl
app.name = MyApp
app.version = 1.0.0
server.port = 3000
server.host = localhost
```

```ccl  
# production-overrides.ccl
server.host = 0.0.0.0
server.port = 80
ssl.enabled = true
ssl.cert = /etc/ssl/cert.pem
```

```gleam
// Gleam enhancement: Configuration merging utilities
pub fn merge_configurations(base_text: String, override_text: String) -> Result(ccl.CCL, String) {
  use base_entries <- result.try(ccl.parse(base_text))
  use override_entries <- result.try(ccl.parse(override_text))
  
  // Combine entries - overrides come last so they take precedence
  let combined = list.append(base_entries, override_entries)
  
  Ok(ccl.make_objects(combined))
}

// Usage
let base_config = simplifile.read("base-config.ccl") |> result.unwrap("")
let prod_overrides = simplifile.read("production-overrides.ccl") |> result.unwrap("")

case merge_configurations(base_config, prod_overrides) {
  Ok(merged_config) -> {
    // merged_config now has production values overriding base values
    let host = ccl.get_value(merged_config, "server.host")  // Ok("0.0.0.0")
    let port = ccl.get_int(merged_config, "server.port")    // Ok(80)
    let app_name = ccl.get_value(merged_config, "app.name") // Ok("MyApp") from base
  }
  Error(err) -> io.println("Merge failed: " <> err)
}
```

**Gleam Enhancements:**
- Entry-level merging before object creation
- Precedence-based configuration composition
- Integration with file I/O libraries

### Environment-Aware Configuration Loading

```ccl
# Base configuration
app_name = MyApp
version = 1.0.0

# Development environment
development.debug = true
development.database.host = localhost

# Production environment
production.debug = false
production.database.host = prod-db.example.com
```

```gleam
// Gleam enhancement: Environment-specific configuration utilities
pub fn load_environment_config(config: ccl.CCL, environment: String) -> Result(ccl.CCL, String) {
  case ccl.get_nested(config, environment) {
    Ok(env_config) -> Ok(env_config)
    Error(_) -> Error("Environment '" <> environment <> "' not found in configuration")
  }
}

// Advanced: Merge base config with environment overrides
pub fn load_with_environment_overrides(config: ccl.CCL, environment: String) -> ccl.CCL {
  case ccl.get_nested(config, environment) {
    Ok(env_config) -> {
      // Merge base config with environment-specific overrides
      // Implementation would combine entries intelligently
      env_config
    }
    Error(_) -> config  // Fall back to base config
  }
}
```

**Gleam Enhancements:**
- Environment-aware configuration selection
- Fallback mechanisms for missing environments
- Intelligent merging of base and environment-specific settings

---

## Best Practices Summary

### Core CCL Language Best Practices
1. **Use meaningful key names**: `database.connection_timeout` instead of `db_ct`
2. **Group related settings**: Use dot notation for hierarchical organization
3. **Document with special keys**: Use `/=`, `#=`, `//=` for comments
4. **Organize with prefixes**: `development.`, `production.` for environments
5. **Use lists consistently**: Prefer `= value` syntax over array indices

### Gleam Implementation Best Practices
1. **Handle errors gracefully**: Provide sensible defaults and clear error messages
2. **Validate configurations**: Check required fields and data types early
3. **Use type-aware parsing**: Leverage typed parsing options for reliability
4. **Filter comments in production**: Remove documentation overhead when not needed
5. **Structure configuration types**: Define custom types for complex configurations
6. **Use result chaining**: Leverage `use` syntax for clean error handling

This comprehensive guide demonstrates both the universal CCL language features and the powerful Gleam-specific enhancements that make configuration management type-safe and robust.