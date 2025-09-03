// CCL Test Data Generator for Benchmarking

import gleam/int
import gleam/float
import gleam/list
import gleam/string

pub type FileSize {
  Small      // 1KB - 10KB
  Medium     // 10KB - 1MB
  Large      // 1MB - 10MB
  Huge       // 10MB+
}

pub type KeyStyle {
  Simple     // key = value
  Dotted     // app.server.port = 8080
  Mixed      // combination of both
}

pub type ValueType {
  StringVal
  IntVal
  FloatVal
  BoolVal
  ListVal
  EmptyVal
}

pub type BenchmarkConfig {
  BenchmarkConfig(
    file_size: FileSize,
    nesting_depth: Int,
    list_density: Float,
    comment_density: Float,
    key_complexity: KeyStyle,
    value_types: List(ValueType),
  )
}

/// Generate CCL configuration text based on benchmark parameters
pub fn generate_ccl(config: BenchmarkConfig) -> String {
  let target_size = get_target_size(config.file_size)
  let lines = []
  
  generate_lines(config, target_size, lines)
  |> list.reverse()
  |> string.join("\n")
}

/// Generate small configuration for quick benchmarks
pub fn generate_small_config() -> String {
  let config = BenchmarkConfig(
    file_size: Small,
    nesting_depth: 2,
    list_density: 0.2,
    comment_density: 0.1,
    key_complexity: Mixed,
    value_types: [StringVal, IntVal, BoolVal],
  )
  generate_ccl(config)
}

/// Generate medium configuration for realistic benchmarks
pub fn generate_medium_config() -> String {
  let config = BenchmarkConfig(
    file_size: Medium,
    nesting_depth: 4,
    list_density: 0.3,
    comment_density: 0.15,
    key_complexity: Mixed,
    value_types: [StringVal, IntVal, FloatVal, BoolVal, ListVal],
  )
  generate_ccl(config)
}

/// Generate large configuration for stress testing
pub fn generate_large_config() -> String {
  let config = BenchmarkConfig(
    file_size: Large,
    nesting_depth: 6,
    list_density: 0.4,
    comment_density: 0.05,
    key_complexity: Dotted,
    value_types: [StringVal, IntVal, FloatVal, BoolVal, ListVal, EmptyVal],
  )
  generate_ccl(config)
}

/// Generate web server configuration example
pub fn generate_web_server_config() -> String {
  "
# Web Server Configuration
server.name = production-api
server.host = 0.0.0.0
server.port = 8080
server.ssl.enabled = true
server.ssl.cert = /path/to/certificate.pem
server.ssl.key = /path/to/private-key.pem

# Database Configuration
database.host = localhost
database.port = 5432
database.name = myapp_production
database.username = dbuser
database.password = secure_password123
database.ssl = true
database.pool_size = 20
database.timeout = 30.5

# Allowed Hosts
allowed_hosts =
  = localhost
  = 127.0.0.1
  = api.example.com
  = web.example.com

# Feature Flags
features.user_registration = true
features.email_notifications = false
features.advanced_search = true
features.beta_dashboard = false

# Cache Configuration
cache.enabled = true
cache.ttl = 300
cache.redis.host = localhost
cache.redis.port = 6379
cache.redis.database = 0

/= Performance Settings
performance.max_connections = 1000
performance.request_timeout = 30.0
performance.keep_alive = true
"
  |> string.trim()
}

/// Generate feature flags configuration
pub fn generate_feature_flags_config(count: Int) -> String {
  let flag_entries = list.range(0, count - 1)
    |> list.map(fn(i) { "  = feature_" <> int.to_string(i) })
    |> string.join("\n")
  
  let flag_configs = list.range(0, count - 1)
    |> list.map(fn(i) {
      let flag_name = "feature_" <> int.to_string(i)
      let enabled = case i % 3 {
        0 -> "true"
        1 -> "false"
        _ -> "true"
      }
      let rollout = int.to_string((i * 7) % 100)
      
      flag_name <> ".enabled = " <> enabled <> "\n" <>
      flag_name <> ".rollout_percentage = " <> rollout
    })
    |> string.join("\n")
    
  "/= Feature Flags Configuration\nflags =\n" <> flag_entries <> "\n\n" <> flag_configs
}

/// Generate nested configuration with specified depth
pub fn generate_nested_config(depth: Int, keys_per_level: Int) -> String {
  generate_nested_keys("", depth, keys_per_level, [])
  |> list.reverse()
  |> string.join("\n")
}

// === INTERNAL HELPER FUNCTIONS ===

fn get_target_size(file_size: FileSize) -> Int {
  case file_size {
    Small -> 5000      // ~5KB
    Medium -> 500000   // ~500KB  
    Large -> 5000000   // ~5MB
    Huge -> 50000000   // ~50MB
  }
}

fn generate_lines(
  config: BenchmarkConfig, 
  target_size: Int, 
  acc: List(String)
) -> List(String) {
  let current_size = calculate_size(acc)
  case current_size >= target_size {
    True -> acc
    False -> {
      let new_line = generate_line(config, list.length(acc))
      generate_lines(config, target_size, [new_line, ..acc])
    }
  }
}

fn generate_line(config: BenchmarkConfig, line_number: Int) -> String {
  // Determine line type based on densities
  case should_generate_comment(config.comment_density, line_number) {
    True -> generate_comment(line_number)
    False -> case should_generate_list(config.list_density, line_number) {
      True -> generate_list_entry()
      False -> generate_key_value(config, line_number)
    }
  }
}

fn generate_comment(line_number: Int) -> String {
  let comment_styles = ["/=", "#=", "//="]
  let style = case line_number % 3 {
    0 -> "/="
    1 -> "#="
    _ -> "//="
  }
  style <> " Configuration comment " <> int.to_string(line_number)
}

fn generate_list_entry() -> String {
  "  = list_item_value"
}

fn generate_key_value(config: BenchmarkConfig, line_number: Int) -> String {
  let key = generate_key(config.key_complexity, config.nesting_depth, line_number)
  let value = generate_value(config.value_types, line_number)
  key <> " = " <> value
}

fn generate_key(style: KeyStyle, max_depth: Int, line_number: Int) -> String {
  case style {
    Simple -> "key_" <> int.to_string(line_number)
    Dotted -> {
      let depth = (line_number % max_depth) + 1
      generate_dotted_key(depth, line_number)
    }
    Mixed -> case line_number % 2 {
      0 -> "key_" <> int.to_string(line_number)
      _ -> generate_dotted_key((line_number % max_depth) + 1, line_number)
    }
  }
}

fn generate_dotted_key(depth: Int, line_number: Int) -> String {
  list.range(0, depth - 1)
  |> list.map(fn(i) { "section" <> int.to_string(i) })
  |> list.append(["key_" <> int.to_string(line_number)])
  |> string.join(".")
}

fn generate_value(value_types: List(ValueType), line_number: Int) -> String {
  let type_count = list.length(value_types)
  let selected_type = case list.at(value_types, line_number % type_count) {
    Ok(t) -> t
    Error(_) -> StringVal
  }
  
  case selected_type {
    StringVal -> "string_value_" <> int.to_string(line_number)
    IntVal -> int.to_string(line_number * 42)
    FloatVal -> float.to_string(int.to_float(line_number) *. 3.14159)
    BoolVal -> case line_number % 2 {
      0 -> "true"
      _ -> "false"
    }
    ListVal -> "\n  = list_item_1\n  = list_item_2"
    EmptyVal -> ""
  }
}

fn generate_nested_keys(
  prefix: String, 
  remaining_depth: Int, 
  keys_per_level: Int,
  acc: List(String)
) -> List(String) {
  case remaining_depth {
    0 -> acc
    _ -> {
      let current_level_keys = list.range(0, keys_per_level - 1)
        |> list.map(fn(i) {
          let key = case prefix {
            "" -> "key" <> int.to_string(i)
            _ -> prefix <> ".key" <> int.to_string(i)
          }
          case remaining_depth {
            1 -> key <> " = terminal_value_" <> int.to_string(i)
            _ -> ""
          }
        })
        |> list.filter(fn(s) { s != "" })
      
      let nested_keys = list.range(0, keys_per_level - 1)
        |> list.fold(acc, fn(inner_acc, i) {
          let new_prefix = case prefix {
            "" -> "key" <> int.to_string(i)
            _ -> prefix <> ".key" <> int.to_string(i)
          }
          generate_nested_keys(new_prefix, remaining_depth - 1, keys_per_level, inner_acc)
        })
      
      list.append(current_level_keys, nested_keys)
    }
  }
}

fn should_generate_comment(density: Float, line_number: Int) -> Bool {
  let hash_value = int.to_float(line_number * 31 + 17) /. 1000.0
  let normalized = hash_value -. float.truncate(hash_value)
  normalized <. density
}

fn should_generate_list(density: Float, line_number: Int) -> Bool {
  let hash_value = int.to_float(line_number * 37 + 23) /. 1000.0
  let normalized = hash_value -. float.truncate(hash_value)
  normalized <. density
}

fn calculate_size(lines: List(String)) -> Int {
  lines
  |> list.map(string.length)
  |> list.fold(0, fn(acc, len) { acc + len + 1 }) // +1 for newlines
}