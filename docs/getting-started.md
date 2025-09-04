# Getting Started with CCL

A gentle introduction to the Categorical Configuration Language with practical examples.

## What is CCL?

CCL is a minimal configuration format that uses simple key-value pairs with indentation-based nesting:

```ccl
database =
  host = localhost
  port = 5432
server =
  ports =
    = 8000
    = 8001
```

## Basic Syntax

### Simple Key-Value Pairs

Start with the most basic CCL configuration:

```ccl
app_name = MyApplication
version = 1.2.3
debug = true
port = 8080
```

**Key Points:**
- Use `key = value` syntax
- Keys can contain letters, numbers, dots, and underscores
- Values are strings (applications interpret them as needed)
- Whitespace around `=` is optional

### Your First Gleam Program

Parse this basic configuration in Gleam:

```gleam
import ccl

let config = "app_name = MyApplication\nport = 8080"

case ccl.parse(config) {
  Ok(entries) -> {
    // For flat keys like "app_name", you can work directly with entries
    // or use make_objects() - both work the same for simple keys
    let objects = ccl.make_objects(entries)
    case ccl.get(objects, "app_name") {
      Ok(ccl.CclString(name)) -> io.println("App: " <> name)
      _ -> io.println("App name not found")
    }
  }
  Error(err) -> io.println("Parse error: " <> err.reason)
}
```

## Nested Configuration

### Using Indented Sections

Group related configuration using indentation:

```ccl
database =
  host = localhost
  port = 5432
  username = admin

server =
  port = 8080
  debug = true
```

Access nested values using dot notation:

```gleam
// Note: Accessing nested sections requires make_objects() processing first
case ccl.get(objects, "database.host") {
  Ok(ccl.CclString(host)) -> connect_to_database(host)
  _ -> use_default_host()
}
```

### Alternative: Flat Structure with Dot Notation

You can also use dot notation directly in keys:

```ccl
database.host = localhost
database.port = 5432
server.port = 8080
server.debug = true
```

**Key Differences:**
- **Nested sections (above)**: Create actual hierarchical structure, require `ccl.make_objects()` for processing
- **Dot notation**: Keys are literal strings like `"database.host"`, work directly with `ccl.parse()` 
- **Result**: Both approaches produce the same accessible structure after processing

**When to use each:**
- **Nested sections**: Better readability for complex configurations
- **Dot notation**: Simpler processing, better for flat or simple configurations

## Lists

### Simple Lists

Create lists using empty keys with indented values:

```ccl
allowed_hosts =
  = localhost
  = example.com
  = api.example.com

ports =
  = 8080
  = 8001
  = 8002
```

Access lists in Gleam:

```gleam
case ccl.get(objects, "allowed_hosts") {
  Ok(ccl.CclList(hosts)) -> {
    list.each(hosts, fn(host) { 
      io.println("Allowed: " <> host)
    })
  }
  _ -> io.println("No hosts configured")
}
```

## Real-World Example

Here's a complete web server configuration:

```ccl
app =
  name = MyWebApp
  version = 1.0.0

server =
  host = 0.0.0.0
  port = 8080
  
database =
  host = localhost
  port = 5432
  name = myapp_db

allowed_origins =
  = https://example.com
  = https://www.example.com
```

Load this configuration safely:

```gleam
pub fn load_config(config_text: String) {
  case ccl.parse(config_text) {
    Ok(entries) -> {
      let config = ccl.make_objects(entries)
      
      let app_name = case ccl.get(config, "app.name") {
        Ok(ccl.CclString(name)) -> name
        _ -> "DefaultApp"
      }
      
      let server_port = case ccl.get(config, "server.port") {
        Ok(ccl.CclString(port_str)) -> {
          case int.parse(port_str) {
            Ok(port) -> port
            Error(_) -> 8080
          }
        }
        _ -> 8080
      }
      
      io.println("Starting " <> app_name <> " on port " <> int.to_string(server_port))
    }
    Error(err) -> {
      io.println("Configuration error: " <> err.reason)
    }
  }
}
```

## Common Patterns

### Optional Configuration

Handle missing or optional configuration gracefully:

```gleam
// Provide defaults for optional settings
let timeout = case ccl.get(config, "database.timeout") {
  Ok(ccl.CclString(t)) -> case int.parse(t) {
    Ok(seconds) -> seconds
    Error(_) -> 30
  }
  _ -> 30  // default timeout
}
```

### Environment-Specific Config

Structure configuration by environment:

```ccl
development =
  database =
    host = localhost
    port = 5432
  debug = true

production =
  database =
    host = db.example.com
    port = 5432
  debug = false
```

## Next Steps

Now that you understand the basics:

1. **Try the examples** - Copy and run the code above
2. **Read the [Advanced Patterns Guide](advanced-patterns.md)** - Learn complex configurations
3. **Check [Gleam Features](gleam-features.md)** - Explore type-safe parsing
4. **See [Migration Guide](migration-guide.md)** - Convert from JSON/YAML

## Quick Reference

```gleam
// Parse CCL text
ccl.parse(text) -> Result(List(Entry), ParseError)

// Build nested objects  
ccl.make_objects(entries) -> CCL

// Access any value
ccl.get(ccl_obj, "path.to.key") -> Result(CclValue, String)

// CclValue types:
// - CclString(String)     - Single value
// - CclList(List(String)) - Multiple values  
// - CclObject(CCL)        - Nested object
```

That's all you need to get started with CCL! The syntax is simple, but the power comes from how you structure and access your configuration data.