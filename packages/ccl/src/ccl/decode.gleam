/// Composable decoders for converting CCL values into typed Gleam records.
///
/// Uses the combinator pattern with Gleam's `use` syntax for ergonomic decoding:
///
/// ```gleam
/// type Config {
///   Config(host: String, port: Int, debug: Bool)
/// }
///
/// let decoder = {
///   use host <- decode.field("host", decode.string)
///   use port <- decode.field("port", decode.int)
///   use debug <- decode.optional_field("debug", decode.bool, False)
///   decode.success(Config(host:, port:, debug:))
/// }
///
/// let assert Ok(config) = decode.decode("host = localhost\nport = 8080", decoder)
/// ```
import ccl/hierarchy
import ccl/parser
import ccl/types.{type CCL, type CCLValue, CclList, CclObject, CclString}
import gleam/dict
import gleam/float
import gleam/int
import gleam/list
import gleam/string

// --- Types ---

/// A decoder that converts a `CCLValue` into a value of type `a`.
///
/// Since this is a type alias for a function, primitive decoders like `string`
/// and `int` can be passed by reference without calling them:
///
/// ```gleam
/// use name <- decode.field("name", decode.string)
/// ```
pub type Decoder(a) =
  fn(CCLValue) -> Result(a, List(DecodeError))

/// An error encountered during decoding.
pub type DecodeError {
  DecodeError(expected: String, found: String, path: List(String))
}

// --- Entry points ---

/// Run a decoder on a `CCLValue`.
pub fn run(decoder: Decoder(a), value: CCLValue) -> Result(a, List(DecodeError)) {
  decoder(value)
}

/// Run a decoder on a parsed `CCL` dict.
///
/// Wraps the dict as a `CclObject` and runs the decoder against it.
pub fn from_ccl(ccl: CCL, decoder: Decoder(a)) -> Result(a, List(DecodeError)) {
  decoder(CclObject(ccl))
}

/// Parse CCL text and decode it in one step.
///
/// Composes `parser.parse` → `hierarchy.build_hierarchy` → decoder.
pub fn decode(text: String, decoder: Decoder(a)) -> Result(a, List(DecodeError)) {
  case parser.parse(text) {
    Ok(entries) -> {
      let ccl = hierarchy.build_hierarchy(entries)
      from_ccl(ccl, decoder)
    }
    Error(parse_error) -> {
      Error([DecodeError("valid CCL", parse_error, [])])
    }
  }
}

// --- Primitive decoders ---

/// Decode a `CclString` into a `String`.
pub fn string(value: CCLValue) -> Result(String, List(DecodeError)) {
  case value {
    CclString(s) -> Ok(s)
    _ -> Error([DecodeError("String", describe_value(value), [])])
  }
}

/// Decode a `CclString` by parsing it as an `Int`.
pub fn int(value: CCLValue) -> Result(Int, List(DecodeError)) {
  case value {
    CclString(s) -> {
      let trimmed = string.trim(s)
      case int.parse(trimmed) {
        Ok(n) -> Ok(n)
        Error(Nil) -> Error([DecodeError("Int", "\"" <> s <> "\"", [])])
      }
    }
    _ -> Error([DecodeError("Int", describe_value(value), [])])
  }
}

/// Decode a `CclString` by parsing it as a `Bool`.
///
/// Strict mode: only accepts `true` and `false` (case-insensitive).
pub fn bool(value: CCLValue) -> Result(Bool, List(DecodeError)) {
  case value {
    CclString(s) -> {
      case string.lowercase(string.trim(s)) {
        "true" -> Ok(True)
        "false" -> Ok(False)
        _ -> Error([DecodeError("Bool", "\"" <> s <> "\"", [])])
      }
    }
    _ -> Error([DecodeError("Bool", describe_value(value), [])])
  }
}

/// Decode a `CclString` by parsing it as a `Float`.
///
/// Falls back to parsing as `Int` and converting if float parsing fails.
pub fn float(value: CCLValue) -> Result(Float, List(DecodeError)) {
  case value {
    CclString(s) -> {
      let trimmed = string.trim(s)
      case float.parse(trimmed) {
        Ok(f) -> Ok(f)
        Error(Nil) -> {
          case int.parse(trimmed) {
            Ok(n) -> Ok(int.to_float(n))
            Error(Nil) -> Error([DecodeError("Float", "\"" <> s <> "\"", [])])
          }
        }
      }
    }
    _ -> Error([DecodeError("Float", describe_value(value), [])])
  }
}

// --- Structural decoders ---

/// Return the raw `CCLValue` without any conversion.
pub fn value(v: CCLValue) -> Result(CCLValue, List(DecodeError)) {
  Ok(v)
}

/// Decode a `CclList`, applying `decoder` to each element.
pub fn list(decoder: Decoder(a)) -> Decoder(List(a)) {
  fn(value: CCLValue) {
    case value {
      CclList(items) -> {
        decode_list_items(items, decoder, 0, [])
      }
      _ -> Error([DecodeError("List", describe_value(value), [])])
    }
  }
}

fn decode_list_items(
  items: List(CCLValue),
  decoder: Decoder(a),
  index: Int,
  acc: List(a),
) -> Result(List(a), List(DecodeError)) {
  case items {
    [] -> Ok(list.reverse(acc))
    [item, ..rest] -> {
      case decoder(item) {
        Ok(decoded) ->
          decode_list_items(rest, decoder, index + 1, [decoded, ..acc])
        Error(errors) -> Error(push_path(errors, int.to_string(index)))
      }
    }
  }
}

// --- Combinators (for `use` syntax) ---

/// Extract a required field from a `CclObject` and decode it.
///
/// Designed for use with Gleam's `use` syntax:
///
/// ```gleam
/// use name <- decode.field("name", decode.string)
/// use age <- decode.field("age", decode.int)
/// decode.success(Person(name:, age:))
/// ```
pub fn field(
  name: String,
  decoder: Decoder(a),
  next: fn(a) -> Decoder(b),
) -> Decoder(b) {
  fn(parent: CCLValue) {
    case parent {
      CclObject(dict) -> {
        case dict.get(dict, name) {
          Ok(field_value) -> {
            case decoder(field_value) {
              Ok(decoded) -> {
                let next_decoder = next(decoded)
                next_decoder(parent)
              }
              Error(errors) -> Error(push_path(errors, name))
            }
          }
          Error(Nil) ->
            Error([DecodeError("field \"" <> name <> "\"", "nothing", [name])])
        }
      }
      _ -> Error([DecodeError("Object", describe_value(parent), [])])
    }
  }
}

/// Extract an optional field, using `default` if the field is missing.
///
/// If the field exists but fails to decode, the error is propagated (not swallowed).
///
/// ```gleam
/// use debug <- decode.optional_field("debug", decode.bool, False)
/// ```
pub fn optional_field(
  name: String,
  decoder: Decoder(a),
  default: a,
  next: fn(a) -> Decoder(b),
) -> Decoder(b) {
  fn(parent: CCLValue) {
    case parent {
      CclObject(dict) -> {
        case dict.get(dict, name) {
          Ok(field_value) -> {
            case decoder(field_value) {
              Ok(decoded) -> {
                let next_decoder = next(decoded)
                next_decoder(parent)
              }
              Error(errors) -> Error(push_path(errors, name))
            }
          }
          Error(Nil) -> {
            let next_decoder = next(default)
            next_decoder(parent)
          }
        }
      }
      _ -> Error([DecodeError("Object", describe_value(parent), [])])
    }
  }
}

/// A decoder that always succeeds with the given value.
///
/// Used as the final step in a decoder chain to wrap the constructed record:
///
/// ```gleam
/// decode.success(MyRecord(field1:, field2:))
/// ```
pub fn success(val: a) -> Decoder(a) {
  fn(_: CCLValue) { Ok(val) }
}

/// A decoder that always fails with the given error.
pub fn failure(expected: String, found: String) -> Decoder(a) {
  fn(_: CCLValue) { Error([DecodeError(expected, found, [])]) }
}

// --- Transformers ---

/// Transform the output of a decoder.
///
/// ```gleam
/// let upper_string = decode.map(decode.string, string.uppercase)
/// ```
pub fn map(decoder: Decoder(a), transform: fn(a) -> b) -> Decoder(b) {
  fn(value: CCLValue) {
    case decoder(value) {
      Ok(a) -> Ok(transform(a))
      Error(errors) -> Error(errors)
    }
  }
}

/// Chain decoders: decode a value, then use it to select the next decoder.
///
/// ```gleam
/// let decoder = decode.then(decode.string, fn(s) {
///   case s {
///     "v1" -> v1_decoder
///     "v2" -> v2_decoder
///     _ -> decode.failure("v1 or v2", s)
///   }
/// })
/// ```
pub fn then(decoder: Decoder(a), next: fn(a) -> Decoder(b)) -> Decoder(b) {
  fn(value: CCLValue) {
    case decoder(value) {
      Ok(a) -> {
        let next_decoder = next(a)
        next_decoder(value)
      }
      Error(errors) -> Error(errors)
    }
  }
}

/// Try multiple decoders in order, returning the first success.
///
/// If all fail, returns accumulated errors from all attempts.
pub fn one_of(decoders: List(Decoder(a))) -> Decoder(a) {
  fn(value: CCLValue) { try_decoders(decoders, value, []) }
}

fn try_decoders(
  decoders: List(Decoder(a)),
  value: CCLValue,
  errors: List(DecodeError),
) -> Result(a, List(DecodeError)) {
  case decoders {
    [] -> Error(errors)
    [decoder, ..rest] -> {
      case decoder(value) {
        Ok(result) -> Ok(result)
        Error(new_errors) ->
          try_decoders(rest, value, list.append(errors, new_errors))
      }
    }
  }
}

// --- Navigation ---

/// Navigate into nested objects by path, then run a decoder.
///
/// ```gleam
/// let port_decoder = decode.at(["database", "connection"], decode.int)
/// ```
pub fn at(path: List(String), decoder: Decoder(a)) -> Decoder(a) {
  case path {
    [] -> decoder
    [segment, ..rest] -> {
      fn(value: CCLValue) {
        case value {
          CclObject(dict) -> {
            case dict.get(dict, segment) {
              Ok(child) -> {
                let inner = at(rest, decoder)
                inner(child)
              }
              Error(Nil) ->
                Error([
                  DecodeError("field \"" <> segment <> "\"", "nothing", path),
                ])
            }
          }
          _ -> Error([DecodeError("Object", describe_value(value), path)])
        }
      }
    }
  }
}

// --- Error formatting ---

/// Format a single decode error as a human-readable string.
pub fn error_to_string(error: DecodeError) -> String {
  let path_str = case error.path {
    [] -> ""
    segments -> " at " <> string.join(segments, ".")
  }
  "Expected " <> error.expected <> ", got " <> error.found <> path_str
}

/// Format a list of decode errors as a human-readable string.
pub fn errors_to_string(errors: List(DecodeError)) -> String {
  errors
  |> list.map(error_to_string)
  |> string.join("\n")
}

// --- Internal helpers ---

fn push_path(errors: List(DecodeError), segment: String) -> List(DecodeError) {
  list.map(errors, fn(error) {
    DecodeError(..error, path: [segment, ..error.path])
  })
}

fn describe_value(value: CCLValue) -> String {
  case value {
    CclString(s) -> "String(\"" <> s <> "\")"
    CclObject(_) -> "Object"
    CclList(_) -> "List"
  }
}
