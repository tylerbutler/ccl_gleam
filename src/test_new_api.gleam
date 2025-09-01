import ccl
import gleam/io
import gleam/list
import gleam/string

pub fn main() {
  io.println("=== Testing New CCL API ===\n")
  
  // Test 1: Basic flat parsing (should work the same as before)
  test_basic_parsing()
  
  // Test 2: make_objects function  
  test_make_objects()
  
  // Test 3: End-to-end nested parsing
  test_nested_parsing()
}

fn test_basic_parsing() {
  io.println("Test 1: Basic flat parsing")
  io.println("==========================")
  
  let input = "name = Alice\nage = 42"
  
  case ccl.parse(input) {
    Ok(entries) -> {
      io.println("Input: " <> input)
      io.println("Entries:")
      list.each(entries, fn(entry) {
        io.println("  " <> entry.key <> " = " <> entry.value)
      })
    }
    Error(err) -> io.println("Parse error: " <> err.reason)
  }
  
  io.println("")
}

fn test_make_objects() {
  io.println("Test 2: make_objects function")
  io.println("=============================")
  
  let entries = [
    ccl.Entry("database", "enabled = true"),
    ccl.Entry("name", "myapp"),
  ]
  
  io.println("Input entries:")
  list.each(entries, fn(entry) {
    io.println("  " <> entry.key <> " = " <> entry.value)
  })
  
  let ccl_obj = ccl.make_objects(entries)
  io.println("\nResulting CCL object:")
  io.println(ccl.pretty_print_ccl(ccl_obj))
  
  io.println("")
}

fn test_nested_parsing() {
  io.println("Test 3: End-to-end nested parsing")
  io.println("==================================")
  
  let input = "database =\n  enabled = true\n  port = 5432\napp = myapp"
  
  io.println("Input: " <> input)
  
  // Step 1: Parse to flat entries
  case ccl.parse(input) {
    Ok(entries) -> {
      io.println("\nFlat parsed entries:")
      list.each(entries, fn(entry) {
        io.println("  " <> entry.key <> " = " <> string.inspect(entry.value))
      })
      
      // Step 2: Build nested objects
      let ccl_obj = ccl.make_objects(entries)
      io.println("\nNested CCL object:")
      io.println(ccl.pretty_print_ccl(ccl_obj))
    }
    Error(err) -> io.println("Parse error: " <> err.reason)
  }
  
  io.println("")
}