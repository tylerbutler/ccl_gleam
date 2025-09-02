import ccl
import ccl_core
import gleam/io
import gleam/json
import gleam/dynamic/decode
import gleam/string
import gleam/list
import gleeunit/should
import simplifile

pub fn main() {
  io.println("=== Running CCL Typed Parsing Tests ===\n")
  
  // Load and run typed parsing examples
  case load_typed_parsing_examples() {
    Ok(examples) -> run_examples(examples)
    Error(err) -> {
      io.println("Failed to load typed parsing examples: " <> err)
      should.fail()
    }
  }
}

// Simple structure for the examples JSON (simplified for now)
type TypedExample {
  TypedExample(
    name: String,
    description: String,
    input: String,
    expected_results: List(#(String, String)), // Just key-value pairs for simple validation
  )
}

fn load_typed_parsing_examples() -> Result(List(TypedExample), String) {
  case simplifile.read("ccl-test-suite/ccl-typed-parsing-examples.json") {
    Ok(_content) -> {
      // For now, return hardcoded examples based on our JSON test file
      Ok([
        TypedExample(
          name: "parse_basic_integer",
          description: "Parse a basic integer value",
          input: "port = 8080",
          expected_results: [#("port", "8080")]
        ),
        TypedExample(
          name: "parse_basic_float", 
          description: "Parse a basic float value",
          input: "temperature = 98.6",
          expected_results: [#("temperature", "98.6")]
        ),
        TypedExample(
          name: "parse_boolean_true",
          description: "Parse boolean true value",
          input: "enabled = true",
          expected_results: [#("enabled", "true")]
        ),
        TypedExample(
          name: "parse_mixed_types",
          description: "Parse configuration with mixed data types",
          input: "host = localhost\\nport = 8080\\nssl = true\\ntimeout = 30.5\\ndebug = off",
          expected_results: [#("host", "localhost"), #("port", "8080"), #("ssl", "true"), #("timeout", "30.5"), #("debug", "off")]
        ),
        TypedExample(
          name: "parse_error_cases",
          description: "Test error cases for invalid parsing",
          input: "port = not_a_number\\ntemperature = invalid\\nenabled = maybe",
          expected_results: [#("port", "not_a_number"), #("temperature", "invalid"), #("enabled", "maybe")]
        ),
        TypedExample(
          name: "parse_boolean_variants",
          description: "Test various boolean representations",
          input: "flag1 = yes\\nflag2 = on\\nflag3 = 1\\nflag4 = false\\nflag5 = no\\nflag6 = off\\nflag7 = 0",
          expected_results: [#("flag1", "yes"), #("flag2", "on"), #("flag3", "1"), #("flag4", "false"), #("flag5", "no"), #("flag6", "off"), #("flag7", "0")]
        )
      ])
    }
    Error(err) -> Error("Failed to read file: " <> simplifile.describe_error(err))
  }
}

fn run_examples(examples: List(TypedExample)) {
  list.each(examples, fn(example) {
    io.println("Running test: " <> example.name <> " - " <> example.description)
    
    // Convert \\n to actual newlines
    let cleaned_input = string.replace(example.input, "\\n", "\n")
    
    case ccl_core.parse(cleaned_input) {
      Ok(entries) -> {
        let parsed = ccl_core.make_objects(entries)
        run_typed_parsing_tests(parsed, example)
      }
      Error(err) -> {
        io.println("  ✗ PARSE ERROR: " <> string.inspect(err))
      }
    }
    
    io.println("")
  })
}

fn run_typed_parsing_tests(parsed: ccl_core.CCL, example: TypedExample) {
  case example.name {
    "parse_basic_integer" -> {
      // Test ccl.get_int()
      case ccl.get_int(parsed, "port") {
        Ok(8080) -> io.println("  ✓ get_int(port) = 8080")
        Ok(other) -> io.println("  ✗ get_int(port) = " <> string.inspect(other) <> ", expected 8080")
        Error(err) -> io.println("  ✗ get_int(port) error: " <> err)
      }
      
      // Test ccl.get_typed_value()
      case ccl.get_typed_value(parsed, "port") {
        Ok(ccl.IntVal(8080)) -> io.println("  ✓ get_typed_value(port) = IntVal(8080)")
        Ok(other) -> io.println("  ✗ get_typed_value(port) = " <> string.inspect(other))
        Error(err) -> io.println("  ✗ get_typed_value(port) error: " <> err)
      }
    }
    
    "parse_basic_float" -> {
      // Test ccl.get_float()
      case ccl.get_float(parsed, "temperature") {
        Ok(98.6) -> io.println("  ✓ get_float(temperature) = 98.6")
        Ok(other) -> io.println("  ✗ get_float(temperature) = " <> string.inspect(other) <> ", expected 98.6")
        Error(err) -> io.println("  ✗ get_float(temperature) error: " <> err)
      }
      
      // Test ccl.get_typed_value()
      case ccl.get_typed_value(parsed, "temperature") {
        Ok(ccl.FloatVal(98.6)) -> io.println("  ✓ get_typed_value(temperature) = FloatVal(98.6)")
        Ok(other) -> io.println("  ✗ get_typed_value(temperature) = " <> string.inspect(other))
        Error(err) -> io.println("  ✗ get_typed_value(temperature) error: " <> err)
      }
    }
    
    "parse_boolean_true" -> {
      // Test ccl.get_bool()
      case ccl.get_bool(parsed, "enabled") {
        Ok(True) -> io.println("  ✓ get_bool(enabled) = True")
        Ok(False) -> io.println("  ✗ get_bool(enabled) = False, expected True")
        Error(err) -> io.println("  ✗ get_bool(enabled) error: " <> err)
      }
      
      // Test ccl.get_typed_value()
      case ccl.get_typed_value(parsed, "enabled") {
        Ok(ccl.BoolVal(True)) -> io.println("  ✓ get_typed_value(enabled) = BoolVal(True)")
        Ok(other) -> io.println("  ✗ get_typed_value(enabled) = " <> string.inspect(other))
        Error(err) -> io.println("  ✗ get_typed_value(enabled) error: " <> err)
      }
    }
    
    "parse_mixed_types" -> {
      // Test various get_typed_value() calls
      case ccl.get_typed_value(parsed, "host") {
        Ok(ccl.StringVal("localhost")) -> io.println("  ✓ get_typed_value(host) = StringVal(localhost)")
        Ok(other) -> io.println("  ✗ get_typed_value(host) = " <> string.inspect(other))
        Error(err) -> io.println("  ✗ get_typed_value(host) error: " <> err)
      }
      
      case ccl.get_typed_value(parsed, "port") {
        Ok(ccl.IntVal(8080)) -> io.println("  ✓ get_typed_value(port) = IntVal(8080)")
        Ok(other) -> io.println("  ✗ get_typed_value(port) = " <> string.inspect(other))
        Error(err) -> io.println("  ✗ get_typed_value(port) error: " <> err)
      }
      
      case ccl.get_typed_value(parsed, "ssl") {
        Ok(ccl.BoolVal(True)) -> io.println("  ✓ get_typed_value(ssl) = BoolVal(True)")
        Ok(other) -> io.println("  ✗ get_typed_value(ssl) = " <> string.inspect(other))
        Error(err) -> io.println("  ✗ get_typed_value(ssl) error: " <> err)
      }
      
      case ccl.get_typed_value(parsed, "timeout") {
        Ok(ccl.FloatVal(30.5)) -> io.println("  ✓ get_typed_value(timeout) = FloatVal(30.5)")
        Ok(other) -> io.println("  ✗ get_typed_value(timeout) = " <> string.inspect(other))
        Error(err) -> io.println("  ✗ get_typed_value(timeout) error: " <> err)
      }
      
      case ccl.get_typed_value(parsed, "debug") {
        Ok(ccl.BoolVal(False)) -> io.println("  ✓ get_typed_value(debug) = BoolVal(False)")
        Ok(other) -> io.println("  ✗ get_typed_value(debug) = " <> string.inspect(other))
        Error(err) -> io.println("  ✗ get_typed_value(debug) error: " <> err)
      }
    }
    
    "parse_error_cases" -> {
      // Test integer parsing error
      case ccl.get_int(parsed, "port") {
        Error(err) -> io.println("  ✓ get_int(port) error: " <> err)
        Ok(val) -> io.println("  ✗ get_int(port) should error, got: " <> string.inspect(val))
      }
      
      // Test float parsing error
      case ccl.get_float(parsed, "temperature") {
        Error(err) -> io.println("  ✓ get_float(temperature) error: " <> err)
        Ok(val) -> io.println("  ✗ get_float(temperature) should error, got: " <> string.inspect(val))
      }
      
      // Test boolean parsing error
      case ccl.get_bool(parsed, "enabled") {
        Error(err) -> io.println("  ✓ get_bool(enabled) error: " <> err)
        Ok(val) -> io.println("  ✗ get_bool(enabled) should error, got: " <> string.inspect(val))
      }
      
      // Test missing path error
      case ccl.get_int(parsed, "missing") {
        Error(err) -> io.println("  ✓ get_int(missing) error: " <> err)
        Ok(val) -> io.println("  ✗ get_int(missing) should error, got: " <> string.inspect(val))
      }
    }
    
    "parse_boolean_variants" -> {
      let true_flags = ["flag1", "flag2", "flag3"]
      let false_flags = ["flag4", "flag5", "flag6", "flag7"]
      
      // Test true variants
      list.each(true_flags, fn(flag) {
        case ccl.get_bool(parsed, flag) {
          Ok(True) -> io.println("  ✓ get_bool(" <> flag <> ") = True")
          Ok(False) -> io.println("  ✗ get_bool(" <> flag <> ") = False, expected True")
          Error(err) -> io.println("  ✗ get_bool(" <> flag <> ") error: " <> err)
        }
      })
      
      // Test false variants  
      list.each(false_flags, fn(flag) {
        case ccl.get_bool(parsed, flag) {
          Ok(False) -> io.println("  ✓ get_bool(" <> flag <> ") = False")
          Ok(True) -> io.println("  ✗ get_bool(" <> flag <> ") = True, expected False")
          Error(err) -> io.println("  ✗ get_bool(" <> flag <> ") error: " <> err)
        }
      })
    }
    
    _ -> {
      io.println("  ! Test case '" <> example.name <> "' not implemented yet")
    }
  }
}