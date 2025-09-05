# Configuration Format Comparison

Comparing CCL with JSON, YAML, TOML, INI, and environment variables to help you choose the right format.

## Format Comparison Overview

| Feature | JSON | YAML | TOML | INI | Env Vars | CCL |
|---------|------|------|------|-----|----------|-----|
| Comments | ❌ | ✅ | ✅ | ✅ | ❌ | ✅ |
| Human Readable | ⚠️ | ✅ | ✅ | ✅ | ❌ | ✅ |
| Hierarchical | ✅ | ✅ | ✅ | ⚠️ | ❌ | ✅ |
| Lists/Arrays | ✅ | ✅ | ✅ | ❌ | ⚠️ | ✅ |
| String Quoting | Required | Optional | Mixed | Optional | N/A | Optional |
| Multiline Values | Escaped | Native | Limited | ❌ | ❌ | ✅ |
| Duplicate Keys | Error | Error | Error | Overwrite | Overwrite | Merge |

## JSON vs CCL

**JSON (config.json):**
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

**CCL (config.ccl):**
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

**Key Differences:**
- **Comments**: JSON has no comment support; CCL uses `/=` for documentation
- **Quotes**: JSON requires quotes on all strings; CCL treats everything as strings
- **Readability**: CCL is more readable with less punctuation
- **Lists**: JSON arrays `["a", "b"]` become CCL lists with `= a` and `= b`

**When to Choose Each:**
- **JSON**: API responses, data interchange, when you need strict syntax
- **CCL**: Human-authored configuration files, when you need comments and documentation

## YAML vs CCL

**YAML (config.yaml):**
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

**CCL (config.ccl):**
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

**Key Differences:**
- **Indentation**: YAML relies on precise indentation; CCL uses explicit structure
- **Lists**: YAML uses `- item`; CCL uses `= item`  
- **Quotes**: YAML has complex quoting rules; CCL treats all values as strings
- **Error-prone**: YAML indentation errors are common; CCL structure is more explicit

**When to Choose Each:**
- **YAML**: Ansible playbooks, Docker Compose, when indentation feels natural
- **CCL**: When you want explicit structure without indentation sensitivity

## TOML vs CCL

**TOML (config.toml):**
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

**CCL (config.ccl):**
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

**Key Differences:**
- **Sections**: TOML uses `[section]` headers; CCL uses dot notation or nested sections
- **Arrays**: TOML uses `["a", "b"]`; CCL uses list syntax with `= item`
- **Types**: TOML has strict typing; CCL treats all values as strings with smart parsing
- **Verbosity**: CCL is less verbose with fewer brackets and quotes

**When to Choose Each:**
- **TOML**: Rust projects (Cargo.toml), Python packaging, when you want strict typing
- **CCL**: When you prefer simpler syntax and don't need strict types

## INI vs CCL

**INI (config.ini):**
```ini
[app]
name=MyApplication
version=1.2.3
debug=true

[server]
host=localhost
port=8080

[database]
host=localhost
port=5432
name=myapp_dev
# No native array support
url1=postgres://db1:5432/myapp
url2=postgres://db2:5432/myapp
```

**CCL (config.ccl):**
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

**Key Differences:**
- **Arrays**: INI has no native array support; CCL has built-in list syntax
- **Nesting**: INI supports only one level of sections; CCL supports deep hierarchies
- **Comments**: Both support comments, but CCL's `/=` creates structured documentation
- **Parsing**: INI parsing varies by implementation; CCL has consistent rules

**When to Choose Each:**
- **INI**: Legacy Windows applications, simple key-value configurations
- **CCL**: When you need arrays, deep nesting, or consistent parsing

## Environment Variables vs CCL

**Environment Variables (.env):**
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

**CCL (config.ccl):**
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

**Key Differences:**
- **Structure**: Environment variables are flat; CCL supports hierarchy
- **Arrays**: Environment variables use delimited strings; CCL has native lists
- **Documentation**: Environment variables have no comment support; CCL has rich documentation
- **Readability**: Environment variables become unwieldy at scale; CCL stays organized

**When to Choose Each:**
- **Environment Variables**: Deployment secrets, runtime overrides, containerized applications
- **CCL**: Complex configuration files, when you need structure and documentation


## Format Selection Guide

### Use JSON when:
- Building REST APIs or web services
- Exchanging data between systems
- You need strict syntax validation
- Working with JavaScript applications
- Schema validation is critical

### Use YAML when:
- Writing Docker Compose files
- Configuring CI/CD pipelines (GitHub Actions, etc.)
- Creating Ansible playbooks
- You prefer indentation-based structure
- Working with Kubernetes manifests

### Use TOML when:
- Configuring Rust projects (Cargo.toml)
- Python packaging (pyproject.toml)
- You need strict data types
- Configuration has clear sectional boundaries
- Type safety is important

### Use INI when:
- Maintaining legacy applications
- Simple key-value configuration
- Windows applications
- Configuration has minimal nesting needs

### Use Environment Variables when:
- Deploying containerized applications
- Managing deployment secrets
- Runtime configuration overrides
- Following 12-factor app principles
- Simple configuration without structure

### Use CCL when:
- Human-authored configuration files
- You need rich inline documentation
- Configuration requires complex nested structures
- You want merge semantics for duplicate keys
- Simplicity and readability are priorities
- You're using Gleam and want type-safe parsing

## Syntax Quick Reference

| Feature | JSON | YAML | TOML | INI | CCL |
|---------|------|------|------|-----|-----|
| **Comments** | ❌ None | `# comment` | `# comment` | `; comment` | `/= comment` |
| **String Values** | `"value"` | `value` or `"value"` | `"value"` | `value` | `value` |
| **Numbers** | `123` | `123` | `123` | `123` | `123` |
| **Booleans** | `true`/`false` | `true`/`false` | `true`/`false` | `true`/`false` | `true`/`false` |
| **Nested Objects** | `{"a":{"b":"c"}}` | `a:`<br>&nbsp;&nbsp;`b: c` | `[a]`<br>`b = "c"` | `[a]`<br>`b=c` | `a.b = c` |
| **Arrays/Lists** | `["a","b"]` | `- a`<br>`- b` | `["a","b"]` | ❌ | `= a`<br>`= b` |
| **Multiline** | `"line1\nline2"` | `\|`<br>&nbsp;&nbsp;`line1`<br>&nbsp;&nbsp;`line2` | `"""line1\nline2"""` | ❌ | `<<`<br>`line1`<br>`line2`<br>`>>` |

## Common Patterns Comparison

### Database Configuration
**JSON**: Verbose with required quotes and commas
```json
{
  "database": {
    "host": "localhost",
    "port": 5432,
    "replicas": ["db1.example.com", "db2.example.com"]
  }
}
```

**YAML**: Clean but indentation-sensitive
```yaml
database:
  host: localhost
  port: 5432
  replicas:
    - db1.example.com
    - db2.example.com
```

**TOML**: Section-based with explicit arrays
```toml
[database]
host = "localhost"
port = 5432
replicas = ["db1.example.com", "db2.example.com"]
```

**CCL**: Simple and self-documenting
```ccl
/= Database Configuration
database.host = localhost
database.port = 5432
database.replicas =
  = db1.example.com
  = db2.example.com
```

### Feature Summary

CCL combines the best aspects of each format:
- **JSON's** structured data without verbose syntax
- **YAML's** readability without indentation sensitivity  
- **TOML's** clear sections without bracket overhead
- **INI's** simplicity with modern features like arrays
- **Environment variables'** ease of use with hierarchical organization

Choose the format that best fits your project's needs, tooling constraints, and team preferences.