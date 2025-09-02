import ccl_core
import gleam/io
import gleam/string

pub fn main() {
  io.println("Testing tab indentation fix...")
  
  // Test case from ccl-test-suite.json: tab_only_indentation
  let input = "config = First line\n\tTab indented line\n\tAnother tab line\nnext = value"
  
  case ccl_core.parse(input) {
    Ok(entries) -> {
      io.println("✓ Parse succeeded!")
      io.println("Results:")
      
      case entries {
        [ccl_core.Entry(key1, value1), ccl_core.Entry(key2, value2)] -> {
          io.println("Entry 1 - Key: " <> key1)
          io.println("Entry 1 - Value: " <> string.inspect(value1))
          io.println("Entry 2 - Key: " <> key2)  
          io.println("Entry 2 - Value: " <> string.inspect(value2))
          
          // Check if the tab indentation was parsed correctly
          let expected_value1 = "First line\n\tTab indented line\n\tAnother tab line"
          case value1 == expected_value1 {
            True -> io.println("✓ Tab indentation parsed correctly!")
            False -> {
              io.println("✗ Tab indentation issue!")
              io.println("Expected: " <> string.inspect(expected_value1))
              io.println("Got:      " <> string.inspect(value1))
            }
          }
        }
        _ -> {
          io.println("✗ Unexpected number of entries")
          io.println("Got: " <> string.inspect(entries))
        }
      }
    }
    Error(err) -> {
      io.println("✗ Parse failed: " <> string.inspect(err))
    }
  }
}