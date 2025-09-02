import ccl_core
import ccl
import gleam/io
import gleam/list
import gleam/string

pub fn main() {
  io.println("=== Enhanced List Handling Demo ===\n")
  
  // Create test CCL with different data types
  let ccl_core_text = "app_name = MyApp

ports =
  = 8000
  = 8001
  = 8002

single_port =
  = 9000

database =
  host = localhost
  port = 5432

services =
  web =
    name = frontend
    ports =
      = 3000
      = 3001
  api =
    name = backend  
    port = 4000"

  case ccl_core.parse(ccl_core_text) {
    Ok(flat_entries) -> {
      let ccl_core_obj = ccl_core.make_objects(flat_entries)
      
      
      demo_node_type_detection(ccl_core_obj)
      demo_smart_access_functions(ccl_core_obj)
      demo_list_access_patterns(ccl_core_obj)
      demo_error_handling_improvements(ccl_core_obj)
    }
    Error(err) -> io.println("Parse error: " <> err.reason)
  }
}

fn demo_node_type_detection(ccl_core_obj: ccl_core.CCL) {
  io.println("=== 1. Node Type Detection ===")
  
  let test_paths = [
    "app_name",           // Should be SingleValue
    "ports",              // Should be ListValue 
    "single_port",        // Should be SingleValue (single item list)
    "database",           // Should be ObjectValue
    "services.web.ports", // Should be ListValue
    "services.api.port",  // Should be SingleValue
    "nonexistent",        // Should be Missing
  ]
  
  list.each(test_paths, fn(path) {
    let node_type = ccl.node_type(ccl_core_obj, path)
    io.println("  " <> path <> " -> " <> describe_node_type(node_type))
  })
  
  io.println("")
}

fn describe_node_type(node_type: ccl.NodeType) -> String {
  case node_type {
    ccl.SingleValue -> "SingleValue"
    ccl.ListValue -> "ListValue"
    ccl.ObjectValue -> "ObjectValue"
    ccl.Missing -> "Missing"
  }
}

fn demo_smart_access_functions(ccl_core_obj: ccl_core.CCL) {
  io.println("=== 2. Smart Access Functions ===")
  
  // get_smart_value - gives helpful errors for wrong types
  io.println("Using get_smart_value():")
  demo_smart_value(ccl_core_obj, "app_name")      // Should work
  demo_smart_value(ccl_core_obj, "ports")         // Should suggest get_list()
  demo_smart_value(ccl_core_obj, "database")      // Should suggest get_nested()
  
  io.println("\nUsing get_list():")
  demo_get_list(ccl_core_obj, "ports")            // Should return list
  demo_get_list(ccl_core_obj, "single_port")      // Should return single-item list
  demo_get_list(ccl_core_obj, "app_name")         // Should return single-item list
  demo_get_list(ccl_core_obj, "database")         // Should error
  
  io.println("\nUsing get_value_or_first():")
  demo_get_value_or_first(ccl_core_obj, "app_name")    // Single value
  demo_get_value_or_first(ccl_core_obj, "ports")       // First item of list
  demo_get_value_or_first(ccl_core_obj, "single_port") // Single item
  
  io.println("")
}

fn demo_smart_value(ccl_core_obj: ccl_core.CCL, path: String) {
  case ccl.get_smart_value(ccl_core_obj, path) {
    Ok(value) -> io.println("  " <> path <> " = " <> value)
    Error(err) -> io.println("  " <> path <> " -> " <> err)
  }
}

fn demo_get_list(ccl_core_obj: ccl_core.CCL, path: String) {
  case ccl.get_list(ccl_core_obj, path) {
    Ok(values) -> io.println("  " <> path <> " = [" <> string.join(values, ", ") <> "]")
    Error(err) -> io.println("  " <> path <> " -> " <> err)
  }
}

fn demo_get_value_or_first(ccl_core_obj: ccl_core.CCL, path: String) {
  case ccl.get_value_or_first(ccl_core_obj, path) {
    Ok(value) -> io.println("  " <> path <> " = " <> value <> " (first/only)")
    Error(err) -> io.println("  " <> path <> " -> " <> err)
  }
}

fn demo_list_access_patterns(ccl_core_obj: ccl_core.CCL) {
  io.println("=== 3. Common List Access Patterns ===")
  
  // Pattern 1: Process all items in a list
  io.println("Processing all ports:")
  case ccl.get_list(ccl_core_obj, "ports") {
    Ok(ports) -> {
      list.each(ports, fn(port) {
        io.println("  - Configuring port " <> port)
      })
    }
    Error(err) -> io.println("Error: " <> err)
  }
  
  // Pattern 2: Get default value from list or single value
  io.println("\nGetting primary port (first port):")
  case ccl.get_value_or_first(ccl_core_obj, "ports") {
    Ok(primary_port) -> io.println("  Primary port: " <> primary_port)
    Error(err) -> io.println("  Error: " <> err)
  }
  
  // Pattern 3: Handle flexible configuration (could be single or list)
  io.println("\nFlexible config handling:")
  ["single_port", "ports", "services.api.port"]
  |> list.each(fn(path) {
    case ccl.get_list(ccl_core_obj, path) {
      Ok(values) -> {
        let count = list.length(values)
        io.println("  " <> path <> " has " <> string.inspect(count) <> " value(s): [" <> string.join(values, ", ") <> "]")
      }
      Error(err) -> io.println("  " <> path <> " -> " <> err)
    }
  })
  
  io.println("")
}

fn demo_error_handling_improvements(ccl_core_obj: ccl_core.CCL) {
  io.println("=== 4. Improved Error Messages ===")
  
  // Show how the new functions provide better error messages
  let test_cases = [
    #("get_smart_value", "ports"),          // List accessed as single value
    #("get_smart_value", "database"),       // Object accessed as single value
    #("get_list", "database"),              // Object accessed as list
    #("get_value_or_first", "database"),    // Object accessed as value
  ]
  
  list.each(test_cases, fn(test_case) {
    let #(function_name, path) = test_case
    case function_name {
      "get_smart_value" -> {
        case ccl.get_smart_value(ccl_core_obj, path) {
          Ok(value) -> io.println("  " <> function_name <> "(" <> path <> ") = " <> value)
          Error(err) -> io.println("  " <> function_name <> "(" <> path <> ") -> " <> err)
        }
      }
      "get_list" -> {
        case ccl.get_list(ccl_core_obj, path) {
          Ok(values) -> io.println("  " <> function_name <> "(" <> path <> ") = [" <> string.join(values, ", ") <> "]")
          Error(err) -> io.println("  " <> function_name <> "(" <> path <> ") -> " <> err)
        }
      }
      "get_value_or_first" -> {
        case ccl.get_value_or_first(ccl_core_obj, path) {
          Ok(value) -> io.println("  " <> function_name <> "(" <> path <> ") = " <> value)
          Error(err) -> io.println("  " <> function_name <> "(" <> path <> ") -> " <> err)
        }
      }
      _ -> io.println("  Unknown function: " <> function_name)
    }
  })
  
  io.println("")
}