import ccl
import ccl_core
import gleam/dict
import gleam/io
import gleam/list
import gleam/result
import gleam/string

/// Helper functions to work with nested CCL structures
pub type NestedConfig =
  dict.Dict(String, String)

/// Parse CCL into a nested structure using dot notation
pub fn to_nested_dict(entries: List(ccl_core.Entry)) -> NestedConfig {
  list.fold(entries, dict.new(), fn(acc, entry) {
    dict.insert(acc, entry.key, entry.value)
  })
}

/// Get all keys that start with a prefix (representing a nested section)
pub fn get_section(
  config: NestedConfig,
  prefix: String,
) -> List(#(String, String)) {
  dict.to_list(config)
  |> list.filter(fn(pair) {
    let #(key, _) = pair
    string.starts_with(key, prefix)
  })
}

/// Extract the local key name from a dotted key (e.g., "database.host" -> "host")
pub fn local_key(key: String, prefix: String) -> String {
  case string.starts_with(key, prefix) {
    True -> string.drop_start(key, string.length(prefix))
    False -> key
  }
}

pub fn main() {
  io.println("=== CCL Nested Structure Handling ===\n")

  // Example: Hierarchical configuration
  let config_text =
    "database.host = localhost
database.port = 5432
database.name = myapp_db
database.credentials.username = admin
database.credentials.password = secret123
database.pool.min_size = 2
database.pool.max_size = 10
database.pool.timeout = 30

cache.redis.host = redis.example.com
cache.redis.port = 6379
cache.redis.db = 0
cache.redis.auth.password = redis_secret
cache.redis.pool.size = 5

app.name = My Application
app.version = 1.0.0
app.debug = true
app.features.auth = enabled
app.features.logging = info
app.features.metrics = disabled

server.allowed_hosts = 
  example.com
  www.example.com
  api.example.com
  
api.cors.origins =
  https://example.com
  https://app.example.com
  http://localhost:3000"

  case ccl_core.parse(config_text) {
    Ok(entries) -> {
      let config = to_nested_dict(entries)

      io.println("All parsed entries:")
      dict.each(config, fn(key, value) {
        io.println("  " <> key <> " = " <> value)
      })

      io.println("\n--- Nested Structure Examples ---")

      // Example 1: Database configuration
      io.println("\n1. Database Configuration:")
      let db_config = get_section(config, "database.")
      list.each(db_config, fn(pair) {
        let #(key, value) = pair
        let local = local_key(key, "database.")
        io.println("  " <> local <> " -> " <> value)
      })

      // Example 2: Nested credentials
      io.println("\n2. Database Credentials:")
      let creds = get_section(config, "database.credentials.")
      list.each(creds, fn(pair) {
        let #(key, value) = pair
        let local = local_key(key, "database.credentials.")
        io.println("  " <> local <> " -> " <> value)
      })

      // Example 3: Application features
      io.println("\n3. Application Features:")
      let features = get_section(config, "app.features.")
      list.each(features, fn(pair) {
        let #(key, value) = pair
        let local = local_key(key, "app.features.")
        io.println("  " <> local <> " -> " <> value)
      })

      // Example 4: Multi-line values as arrays
      io.println("\n4. Multi-line Values:")
      case dict.get(config, "server.allowed_hosts") {
        Ok(hosts) -> {
          io.println("Allowed hosts:")
          let host_list = parse_multiline_value(hosts)
          list.each(host_list, fn(host) { io.println("  - " <> host) })
        }
        Error(_) -> io.println("No allowed hosts configured")
      }

      case dict.get(config, "api.cors.origins") {
        Ok(origins) -> {
          io.println("CORS origins:")
          let origin_list = parse_multiline_value(origins)
          list.each(origin_list, fn(origin) { io.println("  - " <> origin) })
        }
        Error(_) -> io.println("No CORS origins configured")
      }

      // Example 5: Grouping related configuration
      io.println("\n5. Cache Configuration by Type:")
      let redis_config = get_section(config, "cache.redis.")
      case list.is_empty(redis_config) {
        True -> io.println("No Redis configuration found")
        False -> {
          io.println("Redis settings:")
          list.each(redis_config, fn(pair) {
            let #(key, value) = pair
            let local = local_key(key, "cache.redis.")
            io.println("  " <> local <> " -> " <> value)
          })
        }
      }
    }
    Error(err) -> {
      io.println(
        "Parse error at line " <> string.inspect(err.line) <> ": " <> err.reason,
      )
    }
  }
}

/// Parse a multi-line value into a list of strings
fn parse_multiline_value(value: String) -> List(String) {
  value
  |> string.split("\n")
  |> list.map(string.trim)
  |> list.filter(fn(line) { string.length(line) > 0 })
}

/// Example of building a nested data structure from CCL
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

pub fn extract_database_config(
  config: NestedConfig,
) -> Result(DatabaseConfig, String) {
  use host <- result_try(dict.get(config, "database.host"))
  use port <- result_try(dict.get(config, "database.port"))
  use name <- result_try(dict.get(config, "database.name"))
  use username <- result_try(dict.get(config, "database.credentials.username"))
  use password <- result_try(dict.get(config, "database.credentials.password"))
  use min_pool <- result_try(dict.get(config, "database.pool.min_size"))
  use max_pool <- result_try(dict.get(config, "database.pool.max_size"))

  Ok(DatabaseConfig(
    host: host,
    port: port,
    name: name,
    username: username,
    password: password,
    min_pool_size: min_pool,
    max_pool_size: max_pool,
  ))
}

fn result_try(
  result: Result(a, b),
  next: fn(a) -> Result(c, String),
) -> Result(c, String) {
  case result {
    Ok(value) -> next(value)
    Error(_) -> Error("Missing configuration value")
  }
}

/// Helper function that uses result.try syntax properly
pub fn extract_database_config_proper(
  config: NestedConfig,
) -> Result(DatabaseConfig, String) {
  use host <- result.try(
    dict.get(config, "database.host")
    |> result.replace_error("Missing database.host"),
  )
  use port <- result.try(
    dict.get(config, "database.port")
    |> result.replace_error("Missing database.port"),
  )
  use name <- result.try(
    dict.get(config, "database.name")
    |> result.replace_error("Missing database.name"),
  )
  use username <- result.try(
    dict.get(config, "database.credentials.username")
    |> result.replace_error("Missing database.credentials.username"),
  )
  use password <- result.try(
    dict.get(config, "database.credentials.password")
    |> result.replace_error("Missing database.credentials.password"),
  )
  use min_pool <- result.try(
    dict.get(config, "database.pool.min_size")
    |> result.replace_error("Missing database.pool.min_size"),
  )
  use max_pool <- result.try(
    dict.get(config, "database.pool.max_size")
    |> result.replace_error("Missing database.pool.max_size"),
  )

  Ok(DatabaseConfig(
    host: host,
    port: port,
    name: name,
    username: username,
    password: password,
    min_pool_size: min_pool,
    max_pool_size: max_pool,
  ))
}
