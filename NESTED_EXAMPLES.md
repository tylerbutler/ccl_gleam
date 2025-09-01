# CCL Nested Structure Examples

This document demonstrates how to work with nested structures in CCL using this Gleam library.

## Running the Examples

```bash
# Basic examples showing different nested patterns
gleam run -m examples

# Advanced examples with helper functions for working with nested data
gleam run -m nested_examples
```

## Key Concepts

### 1. Dot Notation for Nesting

CCL uses dot notation to represent nested structures:

```ccl
database.host = localhost
database.port = 5432
database.credentials.username = admin
database.credentials.password = secret123
```

This represents a nested structure like:
```json
{
  "database": {
    "host": "localhost",
    "port": "5432", 
    "credentials": {
      "username": "admin",
      "password": "secret123"
    }
  }
}
```

### 2. Multi-line Values

CCL supports multi-line values using continuation lines:

```ccl
server.allowed_hosts = 
  example.com
  www.example.com
  api.example.com
```

### 3. Grouping Related Configuration

You can group related settings using common prefixes:

```ccl
# All Redis-related settings
cache.redis.host = redis.example.com
cache.redis.port = 6379
cache.redis.db = 0
cache.redis.auth.password = redis_secret
cache.redis.pool.size = 5

# All application feature flags
app.features.auth = enabled
app.features.logging = info
app.features.metrics = disabled
```

## Helper Functions

The `nested_examples.gleam` file provides utilities for working with nested CCL structures:

### Converting to Dictionary

```gleam
let config = to_nested_dict(entries)
// Creates a Dict(String, String) from parsed CCL entries
```

### Extracting Sections

```gleam
let db_config = get_section(config, "database.")
// Gets all key-value pairs that start with "database."
```

### Parsing Multi-line Values

```gleam
let host_list = parse_multiline_value(hosts)
// Splits multi-line values into a list of strings
```

### Building Typed Configuration

```gleam
pub type DatabaseConfig {
  DatabaseConfig(
    host: String,
    port: String, 
    name: String,
    username: String,
    password: String,
    min_pool_size: String,
    max_pool_size: String,
  )
}

// Extract typed configuration from the nested dictionary
let db_config = extract_database_config_proper(config)
```

## Example Patterns

### Environment-specific Configuration

```ccl
server.development.host = localhost
server.development.port = 3000
server.development.debug = true

server.production.host = 0.0.0.0
server.production.port = 80
server.production.debug = false
```

### Feature Flags

```ccl
features.authentication.enabled = true
features.authentication.providers = oauth,ldap,local
features.authentication.session_timeout = 3600

features.logging.level = info
features.logging.file = /var/log/myapp.log
```

### API Configuration

```ccl
api.endpoints.users
  = /api/v1/users
    /api/v1/users/{id}
    /api/v1/users/{id}/profile

api.cors.origins =
  https://example.com
  https://app.example.com
  http://localhost:3000
```

## Best Practices

1. **Use consistent prefixes** for related configuration items
2. **Group by domain** (database, cache, api, etc.)
3. **Use multi-line values** for lists and arrays
4. **Create typed extractors** for complex configuration structures
5. **Validate required fields** when extracting configuration

## Integration with Applications

These examples show how to:
- Parse CCL configuration files
- Extract nested configuration sections
- Convert to typed data structures
- Handle multi-line values as arrays
- Group related configuration items

The patterns demonstrated here can be adapted for any application configuration needs.