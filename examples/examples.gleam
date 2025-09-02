import ccl_core
import ccl
import gleam/io
import gleam/list
import gleam/string

/// Examples demonstrating how to handle nested structures in CCL
pub fn main() {
  io.println("=== CCL Nested Structure Examples ===\n")
  
  // Example 1: Database configuration with nested connection details
  example_database_config()
  
  // Example 2: Server configuration with multiple environments
  example_server_config()
  
  // Example 3: Complex application settings with various data types
  example_app_config()
  
  // Example 4: Multi-line values representing nested data
  example_multiline_nested()
}

pub fn example_database_config() {
  io.println("Example 1: Database Configuration")
  io.println("--------------------------------")
  
  let ccl_config = "
database.host = localhost
database.port = 5432
database.name = myapp
database.user = admin
database.password = secret123
database.ssl.enabled = true
database.ssl.cert_path = /etc/ssl/certs/db.pem
database.ssl.key_path = /etc/ssl/private/db.key
database.pool.max_connections = 10
database.pool.min_connections = 2
database.pool.timeout_seconds = 30
"

  case ccl_core.parse(ccl_config) {
    Ok(entries) -> {
      io.println("Parsed entries:")
      list.each(entries, fn(entry) {
        io.println("  " <> entry.key <> " = " <> entry.value)
      })
      
      // Show how to extract nested configuration
      io.println("\nExtracted nested config:")
      let db_entries = list.filter(entries, fn(entry) {
        case entry.key {
          "database.host" | "database.port" | "database.name" -> True
          _ -> False
        }
      })
      
      list.each(db_entries, fn(entry) {
        io.println("  " <> entry.key <> " -> " <> entry.value)
      })
    }
    Error(err) -> io.println("Parse error: " <> err.reason)
  }
  
  io.println("")
}

pub fn example_server_config() {
  io.println("Example 2: Server Configuration")
  io.println("------------------------------")
  
  let ccl_config = "
server.development.host = localhost
server.development.port = 3000
server.development.debug = true
server.development.log_level = debug

server.production.host = 0.0.0.0
server.production.port = 80
server.production.debug = false
server.production.log_level = warn

server.staging.host = staging.example.com
server.staging.port = 443
server.staging.debug = false
server.staging.log_level = info
"

  case ccl_core.parse(ccl_config) {
    Ok(entries) -> {
      io.println("Parsed entries:")
      list.each(entries, fn(entry) {
        io.println("  " <> entry.key <> " = " <> entry.value)
      })
      
      // Show how to group by environment
      io.println("\nGrouped by environment:")
      let prod_entries = list.filter(entries, fn(entry) {
        case entry.key {
          "server.production." <> _ -> True
          _ -> False
        }
      })
      
      io.println("Production settings:")
      list.each(prod_entries, fn(entry) {
        io.println("  " <> entry.key <> " -> " <> entry.value)
      })
    }
    Error(err) -> io.println("Parse error: " <> err.reason)
  }
  
  io.println("")
}

pub fn example_app_config() {
  io.println("Example 3: Complex Application Settings")
  io.println("--------------------------------------")
  
  let ccl_config = "
app.name = My Application
app.version = 1.2.3
app.author.name = John Doe
app.author.email = john@example.com
app.author.website = https://johndoe.dev

features.authentication.enabled = true
features.authentication.providers = oauth,ldap,local
features.authentication.session_timeout = 3600

features.logging.level = info
features.logging.file = /var/log/myapp.log
features.logging.rotate = daily
features.logging.max_size = 10MB

cache.redis.host = redis.example.com
cache.redis.port = 6379
cache.redis.database = 0
cache.redis.ttl = 300

cache.memory.max_items = 1000
cache.memory.eviction_policy = lru
"

  case ccl_core.parse(ccl_config) {
    Ok(entries) -> {
      io.println("Parsed entries:")
      list.each(entries, fn(entry) {
        io.println("  " <> entry.key <> " = " <> entry.value)
      })
      
      // Show how to extract feature flags
      io.println("\nFeature configuration:")
      let feature_entries = list.filter(entries, fn(entry) {
        case entry.key {
          "features." <> _ -> True
          _ -> False
        }
      })
      
      list.each(feature_entries, fn(entry) {
        io.println("  " <> entry.key <> " -> " <> entry.value)
      })
    }
    Error(err) -> io.println("Parse error: " <> err.reason)
  }
  
  io.println("")
}

pub fn example_multiline_nested() {
  io.println("Example 4: Multi-line Values for Nested Data")
  io.println("--------------------------------------------")
  
  let ccl_config = "api.endpoints.users
  = /api/v1/users
    /api/v1/users/{id}
    /api/v1/users/{id}/profile

api.endpoints.posts
  = /api/v1/posts
    /api/v1/posts/{id}
    /api/v1/posts/{id}/comments

database.migrations = 
  2024_01_01_create_users_table.sql
  2024_01_02_create_posts_table.sql
  2024_01_03_add_user_indexes.sql
  2024_01_04_create_comments_table.sql

cors.allowed_origins =
  https://example.com
  https://www.example.com
  https://api.example.com
  http://localhost:3000"

  case ccl_core.parse(ccl_config) {
    Ok(entries) -> {
      io.println("Parsed entries:")
      list.each(entries, fn(entry) {
        io.println("Key: " <> entry.key)
        io.println("Value:")
        io.println(entry.value)
        io.println("---")
      })
      
      // Show how multi-line values can represent arrays/lists
      io.println("\nMulti-line values as arrays:")
      list.each(entries, fn(entry) {
        case entry.key {
          "cors.allowed_origins" -> {
            io.println("CORS origins:")
            // Split by lines to show individual origins
            let lines = case entry.value {
              "" -> []
              value -> {
                value
                |> string.split("\n")
                |> list.map(string.trim)
                |> list.filter(fn(line) { string.length(line) > 0 })
              }
            }
            list.each(lines, fn(origin) {
              io.println("  - " <> origin)
            })
          }
          _ -> Nil
        }
      })
    }
    Error(err) -> io.println("Parse error: " <> err.reason)
  }
  
  io.println("")
}