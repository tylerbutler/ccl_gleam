import ccl
import gleam/io
import gleam/list
import gleam/result
import gleam/string

pub fn main() {
  io.println("=== CCL Nested Value Access Demo ===\n")
  
  // Create a complex CCL structure
  let ccl_text = "
database =
  host = localhost
  port = 5432
  credentials =
    username = admin
    password = secret123

server =
  name = myapp
  ports =
    = 8000
    = 8001
    = 8002

features =
  auth = enabled
  logging = info
  cache = disabled

simple = value
"

  // Parse and build CCL object
  case ccl.parse(ccl_text) {
    Ok(flat_entries) -> {
      let ccl_obj = ccl.make_objects(flat_entries)
      
      io.println("Created CCL object from:")
      io.println(ccl_text)
      
      demo_basic_access(ccl_obj)
      demo_nested_access(ccl_obj)
      demo_list_access(ccl_obj)
      demo_exploration(ccl_obj)
      demo_error_handling(ccl_obj)
    }
    Error(err) -> io.println("Parse error: " <> err.reason)
  }
}

fn demo_basic_access(ccl_obj: ccl.CCL) {
  io.println("=== 1. Basic Value Access ===")
  
  // Get simple value
  case ccl.get_value(ccl_obj, "simple") {
    Ok(value) -> io.println("simple = " <> value)
    Error(err) -> io.println("Error: " <> err)
  }
  
  // Get nested value
  case ccl.get_value(ccl_obj, "database.host") {
    Ok(value) -> io.println("database.host = " <> value)
    Error(err) -> io.println("Error: " <> err)
  }
  
  // Get deeply nested value
  case ccl.get_value(ccl_obj, "database.credentials.username") {
    Ok(value) -> io.println("database.credentials.username = " <> value)
    Error(err) -> io.println("Error: " <> err)
  }
  
  io.println("")
}

fn demo_nested_access(ccl_obj: ccl.CCL) {
  io.println("=== 2. Working with Nested Objects ===")
  
  // Get a nested CCL object
  case ccl.get_nested(ccl_obj, "database") {
    Ok(db_ccl) -> {
      io.println("Database configuration:")
      case ccl.get_value(db_ccl, "host") {
        Ok(host) -> io.println("  host: " <> host)
        Error(_) -> io.println("  host: not found")
      }
      case ccl.get_value(db_ccl, "port") {
        Ok(port) -> io.println("  port: " <> port)
        Error(_) -> io.println("  port: not found")
      }
      
      // Get nested object within nested object
      case ccl.get_nested(db_ccl, "credentials") {
        Ok(creds_ccl) -> {
          io.println("  credentials:")
          case ccl.get_value(creds_ccl, "username") {
            Ok(user) -> io.println("    username: " <> user)
            Error(_) -> io.println("    username: not found")
          }
          case ccl.get_value(creds_ccl, "password") {
            Ok(pass) -> io.println("    password: " <> pass)
            Error(_) -> io.println("    password: not found")
          }
        }
        Error(err) -> io.println("  credentials error: " <> err)
      }
    }
    Error(err) -> io.println("Database error: " <> err)
  }
  
  io.println("")
}

fn demo_list_access(ccl_obj: ccl.CCL) {
  io.println("=== 3. List-Style Values (Empty Keys) ===")
  
  // Get all values for ports (which uses empty keys)
  let port_values = ccl.get_values(ccl_obj, "server.ports")
  io.println("server.ports = [" <> string.join(port_values, ", ") <> "]")
  
  io.println("Individual port access:")
  list.each(port_values, fn(port) {
    io.println("  - Port: " <> port)
  })
  
  io.println("")
}

fn demo_exploration(ccl_obj: ccl.CCL) {
  io.println("=== 4. Structure Exploration ===")
  
  // Check if keys exist
  io.println("Key existence checks:")
  io.println("  'simple' exists: " <> string.inspect(ccl.has_key(ccl_obj, "simple")))
  io.println("  'database.host' exists: " <> string.inspect(ccl.has_key(ccl_obj, "database.host")))
  io.println("  'nonexistent' exists: " <> string.inspect(ccl.has_key(ccl_obj, "nonexistent")))
  
  // Get all top-level keys
  let top_keys = ccl.get_keys(ccl_obj, "")
  io.println("Top-level keys: [" <> string.join(top_keys, ", ") <> "]")
  
  // Get keys within database
  let db_keys = ccl.get_keys(ccl_obj, "database")
  io.println("Database keys: [" <> string.join(db_keys, ", ") <> "]")
  
  // Get all paths in the structure
  let all_paths = ccl.get_all_paths(ccl_obj)
  io.println("All paths in CCL:")
  list.each(all_paths, fn(path) {
    io.println("  - " <> path)
  })
  
  io.println("")
}

fn demo_error_handling(ccl_obj: ccl.CCL) {
  io.println("=== 5. Error Handling ===")
  
  // Try to access non-existent keys
  case ccl.get_value(ccl_obj, "nonexistent") {
    Ok(value) -> io.println("nonexistent = " <> value)
    Error(err) -> io.println("Expected error for 'nonexistent': " <> err)
  }
  
  case ccl.get_value(ccl_obj, "database.nonexistent") {
    Ok(value) -> io.println("database.nonexistent = " <> value)
    Error(err) -> io.println("Expected error for 'database.nonexistent': " <> err)
  }
  
  case ccl.get_value(ccl_obj, "database.credentials.nonexistent") {
    Ok(value) -> io.println("database.credentials.nonexistent = " <> value)
    Error(err) -> io.println("Expected error for 'database.credentials.nonexistent': " <> err)
  }
  
  io.println("")
}

// Additional helper function to demonstrate programmatic access
pub fn get_database_config(ccl_obj: ccl.CCL) -> Result(DatabaseConfig, String) {
  use host <- result.try(ccl.get_value(ccl_obj, "database.host"))
  use port <- result.try(ccl.get_value(ccl_obj, "database.port"))
  use username <- result.try(ccl.get_value(ccl_obj, "database.credentials.username"))
  use password <- result.try(ccl.get_value(ccl_obj, "database.credentials.password"))
  
  Ok(DatabaseConfig(
    host: host,
    port: port,
    username: username,
    password: password,
  ))
}

pub type DatabaseConfig {
  DatabaseConfig(host: String, port: String, username: String, password: String)
}