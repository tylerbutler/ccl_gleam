/// Code generator for CCL decoders from Gleam type definitions.
///
/// Parses Gleam `pub type` definitions and generates corresponding decoder
/// functions using the `ccl/decode` combinator API.
///
/// ## Example
///
/// Given this Gleam type:
///
/// ```gleam
/// pub type DatabaseConfig {
///   DatabaseConfig(host: String, port: Int, debug: Bool)
/// }
/// ```
///
/// `generate_decoder` produces:
///
/// ```gleam
/// pub fn database_config_decoder() {
///   use host <- decode.field("host", decode.string)
///   use port <- decode.field("port", decode.int)
///   use debug <- decode.field("debug", decode.bool)
///   decode.success(DatabaseConfig(host:, port:, debug:))
/// }
/// ```
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

// --- Public types ---

/// A parsed field from a Gleam type definition.
pub type FieldDef {
  FieldDef(name: String, field_type: FieldType)
}

/// Supported field types for decoder generation.
pub type FieldType {
  StringType
  IntType
  FloatType
  BoolType
  ListType(FieldType)
  OptionType(FieldType)
  CustomType(String)
}

/// A parsed Gleam type definition (single-constructor record).
pub type TypeDef {
  TypeDef(name: String, constructor: String, fields: List(FieldDef))
}

// --- Public API ---

/// Generate a decoder function from a Gleam type definition source string.
///
/// The source should contain a `pub type` definition with one constructor.
/// Returns the generated decoder function as a string, or an error message.
pub fn generate_decoder(source: String) -> Result(String, String) {
  case parse_type_def(source) {
    Ok(type_def) -> Ok(emit_decoder(type_def))
    Error(e) -> Error(e)
  }
}

/// Generate a decoder from a source file that may contain multiple types.
///
/// Extracts the named type definition and generates a decoder for it.
pub fn generate_decoder_for(
  source: String,
  type_name: String,
) -> Result(String, String) {
  case extract_type_def(source, type_name) {
    Ok(type_source) -> generate_decoder(type_source)
    Error(e) -> Error(e)
  }
}

/// Generate a decoder function from a pre-parsed `TypeDef`.
pub fn emit_decoder(type_def: TypeDef) -> String {
  let fn_name = to_snake_case(type_def.name) <> "_decoder"
  let fields = type_def.fields
  let indent = "  "

  let field_lines =
    list.map(fields, fn(field) {
      case field.field_type {
        OptionType(inner) -> {
          let inner_decoder = field_type_to_decoder(inner)
          indent
          <> "use "
          <> field.name
          <> " <- decode.optional_field(\""
          <> field.name
          <> "\", "
          <> inner_decoder
          <> ", option.None)"
        }
        _ -> {
          let decoder_expr = field_type_to_decoder(field.field_type)
          indent
          <> "use "
          <> field.name
          <> " <- decode.field(\""
          <> field.name
          <> "\", "
          <> decoder_expr
          <> ")"
        }
      }
    })

  let option_fields =
    list.filter_map(fields, fn(field) {
      case field.field_type {
        OptionType(_) -> Ok(field.name)
        _ -> Error(Nil)
      }
    })

  let constructor_args =
    list.map(fields, fn(field) {
      case list.contains(option_fields, field.name) {
        True -> field.name <> ": option.Some(" <> field.name <> ")"
        False -> field.name <> ":"
      }
    })
    |> string.join(", ")

  let success_line =
    indent
    <> "decode.success("
    <> type_def.constructor
    <> "("
    <> constructor_args
    <> "))"

  let body =
    list.append(field_lines, [success_line])
    |> string.join("\n")

  "pub fn " <> fn_name <> "() {\n" <> body <> "\n}"
}

/// Parse a Gleam type definition string into a `TypeDef`.
pub fn parse_type_def(source: String) -> Result(TypeDef, String) {
  let trimmed = string.trim(source)

  case strip_prefix(trimmed, "pub type ") {
    None -> {
      case strip_prefix(trimmed, "type ") {
        None -> Error("Expected 'pub type' or 'type' definition")
        Some(rest) -> parse_after_type_keyword(rest)
      }
    }
    Some(rest) -> parse_after_type_keyword(rest)
  }
}

/// Parse a field type string into a `FieldType`.
pub fn parse_field_type(type_str: String) -> Result(FieldType, String) {
  let trimmed = string.trim(type_str)
  case trimmed {
    "String" -> Ok(StringType)
    "Int" -> Ok(IntType)
    "Float" -> Ok(FloatType)
    "Bool" -> Ok(BoolType)
    _ -> {
      case strip_prefix(trimmed, "List(") {
        Some(inner) -> parse_wrapped_type(inner, trimmed, ListType)
        None -> {
          case strip_prefix(trimmed, "Option(") {
            Some(inner) -> parse_wrapped_type(inner, trimmed, OptionType)
            None -> Ok(CustomType(trimmed))
          }
        }
      }
    }
  }
}

/// Convert PascalCase to snake_case.
pub fn to_snake_case(name: String) -> String {
  name
  |> string.to_graphemes
  |> do_snake_case(0, "")
}

// --- Internal: type extraction ---

/// Extract a single type definition from a source file by name.
fn extract_type_def(source: String, type_name: String) -> Result(String, String) {
  let lines = string.split(source, "\n")
  let marker = "type " <> type_name <> " "
  let alt_marker = "type " <> type_name <> "{"
  find_type_block(lines, marker, alt_marker, False, 0, "")
}

fn find_type_block(
  lines: List(String),
  marker: String,
  alt_marker: String,
  capturing: Bool,
  brace_depth: Int,
  acc: String,
) -> Result(String, String) {
  case lines {
    [] -> {
      case capturing {
        True -> Error("Unexpected end of file while parsing type definition")
        False -> Error("Type not found in source")
      }
    }
    [line, ..rest] -> {
      case capturing {
        False -> {
          let trimmed = string.trim(line)
          case
            string.contains(trimmed, marker)
            || string.contains(trimmed, alt_marker)
          {
            True -> {
              let depth = count_braces(line)
              case depth > 0 {
                True ->
                  find_type_block(rest, marker, alt_marker, True, depth, line)
                False ->
                  find_type_block(rest, marker, alt_marker, True, 0, line)
              }
            }
            False -> find_type_block(rest, marker, alt_marker, False, 0, "")
          }
        }
        True -> {
          let new_acc = acc <> "\n" <> line
          let new_depth = brace_depth + count_braces(line)
          case new_depth <= 0 && brace_depth > 0 {
            True -> Ok(string.trim(new_acc))
            False ->
              find_type_block(
                rest,
                marker,
                alt_marker,
                True,
                new_depth,
                new_acc,
              )
          }
        }
      }
    }
  }
}

fn count_braces(line: String) -> Int {
  let chars = string.to_graphemes(line)
  list.fold(chars, 0, fn(acc, c) {
    case c {
      "{" -> acc + 1
      "}" -> acc - 1
      _ -> acc
    }
  })
}

// --- Internal: parsing ---

fn parse_after_type_keyword(rest: String) -> Result(TypeDef, String) {
  case string.split_once(rest, "{") {
    Ok(#(type_name_part, body_part)) -> {
      let type_name = string.trim(type_name_part)
      case string.split_once(body_part, "}") {
        Ok(#(body, _)) -> {
          let body_trimmed = string.trim(body)
          parse_constructor(type_name, body_trimmed)
        }
        Error(Nil) -> Error("Missing closing '}' in type definition")
      }
    }
    Error(Nil) -> Error("Missing opening '{' in type definition")
  }
}

fn parse_constructor(type_name: String, body: String) -> Result(TypeDef, String) {
  case string.split_once(body, "(") {
    Ok(#(constructor_name, fields_part)) -> {
      let constructor = string.trim(constructor_name)
      case strip_last_paren(fields_part) {
        Ok(fields_str) -> {
          case parse_fields(fields_str) {
            Ok(fields) -> Ok(TypeDef(name: type_name, constructor:, fields:))
            Error(e) -> Error(e)
          }
        }
        Error(e) -> Error(e)
      }
    }
    Error(Nil) -> Error("Missing constructor in type body: " <> body)
  }
}

fn strip_last_paren(s: String) -> Result(String, String) {
  let trimmed = string.trim(s)
  case string.ends_with(trimmed, ")") {
    True -> Ok(string.drop_end(trimmed, 1))
    False -> {
      case string.ends_with(trimmed, ",)") {
        True -> Ok(string.drop_end(trimmed, 2))
        False -> Error("Missing closing ')' in constructor")
      }
    }
  }
}

fn parse_fields(fields_str: String) -> Result(List(FieldDef), String) {
  let trimmed = string.trim(fields_str)
  case trimmed {
    "" -> Ok([])
    _ -> {
      let field_strs = split_fields(trimmed)
      list.try_map(field_strs, parse_single_field)
    }
  }
}

fn parse_single_field(field_str: String) -> Result(FieldDef, String) {
  let trimmed = string.trim(field_str)
  case trimmed {
    "" -> Error("Empty field definition")
    _ -> {
      case string.split_once(trimmed, ":") {
        Ok(#(name, type_str)) -> {
          let field_name = string.trim(name)
          case parse_field_type(type_str) {
            Ok(field_type) -> Ok(FieldDef(name: field_name, field_type:))
            Error(e) -> Error(e)
          }
        }
        Error(Nil) ->
          Error("Expected 'name: Type' in field definition: " <> trimmed)
      }
    }
  }
}

fn parse_wrapped_type(
  inner: String,
  original: String,
  wrapper: fn(FieldType) -> FieldType,
) -> Result(FieldType, String) {
  case strip_suffix(inner, ")") {
    Some(inner_type) -> {
      case parse_field_type(inner_type) {
        Ok(ft) -> Ok(wrapper(ft))
        Error(e) -> Error(e)
      }
    }
    None -> Error("Unclosed parenthesis in type: " <> original)
  }
}

/// Split field definitions by commas, respecting nested parentheses.
fn split_fields(s: String) -> List(String) {
  do_split_fields(string.to_graphemes(s), 0, "", [])
}

fn do_split_fields(
  chars: List(String),
  depth: Int,
  current: String,
  acc: List(String),
) -> List(String) {
  case chars {
    [] -> {
      let trimmed = string.trim(current)
      case trimmed {
        "" -> list.reverse(acc)
        _ -> list.reverse([trimmed, ..acc])
      }
    }
    ["(", ..rest] -> do_split_fields(rest, depth + 1, current <> "(", acc)
    [")", ..rest] ->
      do_split_fields(rest, int.max(0, depth - 1), current <> ")", acc)
    [",", ..rest] if depth == 0 -> {
      let trimmed = string.trim(current)
      case trimmed {
        "" -> do_split_fields(rest, 0, "", acc)
        _ -> do_split_fields(rest, 0, "", [trimmed, ..acc])
      }
    }
    [c, ..rest] -> do_split_fields(rest, depth, current <> c, acc)
  }
}

// --- Code emission helpers ---

fn field_type_to_decoder(ft: FieldType) -> String {
  case ft {
    StringType -> "decode.string"
    IntType -> "decode.int"
    FloatType -> "decode.float"
    BoolType -> "decode.bool"
    ListType(inner) -> "decode.list(" <> field_type_to_decoder(inner) <> ")"
    OptionType(inner) -> field_type_to_decoder(inner)
    CustomType(name) -> to_snake_case(name) <> "_decoder()"
  }
}

fn do_snake_case(chars: List(String), index: Int, acc: String) -> String {
  case chars {
    [] -> acc
    [c, ..rest] -> {
      case is_uppercase(c) {
        True -> {
          let prefix = case index > 0 {
            True -> "_"
            False -> ""
          }
          do_snake_case(rest, index + 1, acc <> prefix <> string.lowercase(c))
        }
        False -> do_snake_case(rest, index + 1, acc <> c)
      }
    }
  }
}

fn is_uppercase(c: String) -> Bool {
  let lower = string.lowercase(c)
  c != lower
}

// --- String helpers ---

fn strip_prefix(s: String, prefix: String) -> Option(String) {
  case string.starts_with(s, prefix) {
    True -> Some(string.drop_start(s, string.length(prefix)))
    False -> None
  }
}

fn strip_suffix(s: String, suffix: String) -> Option(String) {
  case string.ends_with(s, suffix) {
    True -> Some(string.drop_end(s, string.length(suffix)))
    False -> None
  }
}
