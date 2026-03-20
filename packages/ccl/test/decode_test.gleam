import startest
import startest/expect

import ccl/decode.{DecodeError}
import ccl/types.{CclList, CclObject, CclString}
import gleam/dict

pub fn main() {
  startest.run(startest.default_config())
}

fn assert_is_error(result: Result(a, b)) -> Nil {
  case result {
    Error(_) -> Nil
    Ok(_) -> panic as "Expected Error, got Ok"
  }
}

// --- Primitive decoders ---

pub fn string_decodes_ccl_string_test() {
  decode.string(CclString("hello"))
  |> expect.to_equal(Ok("hello"))
}

pub fn string_rejects_object_test() {
  decode.string(CclObject(dict.new()))
  |> assert_is_error
}

pub fn string_rejects_list_test() {
  decode.string(CclList([]))
  |> assert_is_error
}

pub fn int_parses_integer_string_test() {
  decode.int(CclString("42"))
  |> expect.to_equal(Ok(42))
}

pub fn int_parses_negative_test() {
  decode.int(CclString("-7"))
  |> expect.to_equal(Ok(-7))
}

pub fn int_trims_whitespace_test() {
  decode.int(CclString("  99  "))
  |> expect.to_equal(Ok(99))
}

pub fn int_rejects_non_integer_test() {
  decode.int(CclString("abc"))
  |> assert_is_error
}

pub fn int_rejects_float_string_test() {
  decode.int(CclString("3.14"))
  |> assert_is_error
}

pub fn bool_parses_true_test() {
  decode.bool(CclString("true"))
  |> expect.to_equal(Ok(True))
}

pub fn bool_parses_false_test() {
  decode.bool(CclString("false"))
  |> expect.to_equal(Ok(False))
}

pub fn bool_case_insensitive_test() {
  decode.bool(CclString("TRUE"))
  |> expect.to_equal(Ok(True))
}

pub fn bool_rejects_yes_strict_test() {
  decode.bool(CclString("yes"))
  |> assert_is_error
}

pub fn float_parses_float_string_test() {
  decode.float(CclString("3.14"))
  |> expect.to_equal(Ok(3.14))
}

pub fn float_converts_int_string_test() {
  decode.float(CclString("42"))
  |> expect.to_equal(Ok(42.0))
}

pub fn float_rejects_non_numeric_test() {
  decode.float(CclString("abc"))
  |> assert_is_error
}

// --- Structural decoders ---

pub fn value_returns_any_value_test() {
  let v = CclString("anything")
  decode.value(v)
  |> expect.to_equal(Ok(v))
}

pub fn list_decodes_string_list_test() {
  let input = CclList([CclString("a"), CclString("b"), CclString("c")])
  decode.run(decode.list(decode.string), input)
  |> expect.to_equal(Ok(["a", "b", "c"]))
}

pub fn list_decodes_int_list_test() {
  let input = CclList([CclString("1"), CclString("2"), CclString("3")])
  decode.run(decode.list(decode.int), input)
  |> expect.to_equal(Ok([1, 2, 3]))
}

pub fn list_rejects_non_list_test() {
  decode.run(decode.list(decode.string), CclString("not a list"))
  |> assert_is_error
}

pub fn list_empty_test() {
  decode.run(decode.list(decode.string), CclList([]))
  |> expect.to_equal(Ok([]))
}

// --- Field extraction ---

pub fn field_extracts_string_test() {
  let obj = CclObject(dict.from_list([#("name", CclString("Alice"))]))
  let decoder = {
    use name <- decode.field("name", decode.string)
    decode.success(name)
  }
  decode.run(decoder, obj)
  |> expect.to_equal(Ok("Alice"))
}

pub fn field_extracts_multiple_fields_test() {
  let obj =
    CclObject(
      dict.from_list([
        #("name", CclString("Alice")),
        #("age", CclString("30")),
      ]),
    )
  let decoder = {
    use name <- decode.field("name", decode.string)
    use age <- decode.field("age", decode.int)
    decode.success(#(name, age))
  }
  decode.run(decoder, obj)
  |> expect.to_equal(Ok(#("Alice", 30)))
}

pub fn field_missing_returns_error_test() {
  let obj = CclObject(dict.from_list([#("name", CclString("Alice"))]))
  let decoder = {
    use _missing <- decode.field("missing", decode.string)
    decode.success(Nil)
  }
  decode.run(decoder, obj)
  |> assert_is_error
}

pub fn field_on_non_object_returns_error_test() {
  let decoder = {
    use _x <- decode.field("key", decode.string)
    decode.success(Nil)
  }
  decode.run(decoder, CclString("not an object"))
  |> assert_is_error
}

// --- Optional fields ---

pub fn optional_field_present_test() {
  let obj = CclObject(dict.from_list([#("debug", CclString("true"))]))
  let decoder = {
    use debug <- decode.optional_field("debug", decode.bool, False)
    decode.success(debug)
  }
  decode.run(decoder, obj)
  |> expect.to_equal(Ok(True))
}

pub fn optional_field_missing_uses_default_test() {
  let obj = CclObject(dict.new())
  let decoder = {
    use debug <- decode.optional_field("debug", decode.bool, False)
    decode.success(debug)
  }
  decode.run(decoder, obj)
  |> expect.to_equal(Ok(False))
}

pub fn optional_field_present_but_invalid_errors_test() {
  let obj = CclObject(dict.from_list([#("port", CclString("not_a_number"))]))
  let decoder = {
    use _port <- decode.optional_field("port", decode.int, 8080)
    decode.success(Nil)
  }
  decode.run(decoder, obj)
  |> assert_is_error
}

// --- Nested objects ---

pub fn nested_object_decoding_test() {
  let obj =
    CclObject(
      dict.from_list([
        #(
          "database",
          CclObject(
            dict.from_list([
              #("host", CclString("localhost")),
              #("port", CclString("5432")),
            ]),
          ),
        ),
        #("log_level", CclString("info")),
      ]),
    )

  let db_decoder = {
    use host <- decode.field("host", decode.string)
    use port <- decode.field("port", decode.int)
    decode.success(#(host, port))
  }

  let config_decoder = {
    use db <- decode.field("database", db_decoder)
    use log_level <- decode.field("log_level", decode.string)
    decode.success(#(db, log_level))
  }

  decode.run(config_decoder, obj)
  |> expect.to_equal(Ok(#(#("localhost", 5432), "info")))
}

// --- Full text-to-type decode ---

pub fn decode_from_text_test() {
  let text = "host = localhost\nport = 8080\ndebug = true"
  let decoder = {
    use host <- decode.field("host", decode.string)
    use port <- decode.field("port", decode.int)
    use debug <- decode.field("debug", decode.bool)
    decode.success(#(host, port, debug))
  }
  decode.decode(text, decoder)
  |> expect.to_equal(Ok(#("localhost", 8080, True)))
}

pub fn decode_nested_ccl_text_test() {
  let text =
    "database =
  host = localhost
  port = 5432
app_name = MyApp"
  let decoder = {
    use db <- decode.field("database", {
      use host <- decode.field("host", decode.string)
      use port <- decode.field("port", decode.int)
      decode.success(#(host, port))
    })
    use name <- decode.field("app_name", decode.string)
    decode.success(#(db, name))
  }
  decode.decode(text, decoder)
  |> expect.to_equal(Ok(#(#("localhost", 5432), "MyApp")))
}

pub fn decode_invalid_ccl_errors_test() {
  // Empty decoders on valid empty CCL should succeed
  let decoder = decode.success("ok")
  decode.decode("", decoder)
  |> expect.to_equal(Ok("ok"))
}

// --- from_ccl ---

pub fn from_ccl_test() {
  let ccl =
    dict.from_list([
      #("key", CclString("value")),
    ])
  let decoder = {
    use key <- decode.field("key", decode.string)
    decode.success(key)
  }
  decode.from_ccl(ccl, decoder)
  |> expect.to_equal(Ok("value"))
}

// --- map ---

pub fn map_transforms_result_test() {
  let upper_string =
    decode.map(decode.string, fn(s) {
      let assert Ok(first) = case s {
        "" -> Ok("")
        _ -> Ok(s)
      }
      first
    })
  decode.run(upper_string, CclString("hello"))
  |> expect.to_equal(Ok("hello"))
}

pub fn map_preserves_errors_test() {
  let decoder = decode.map(decode.int, fn(n) { n * 2 })
  decode.run(decoder, CclString("abc"))
  |> assert_is_error
}

// --- one_of ---

pub fn one_of_takes_first_success_test() {
  let decoder =
    decode.one_of([
      decode.int,
      decode.map(decode.bool, fn(b) {
        case b {
          True -> 1
          False -> 0
        }
      }),
    ])
  decode.run(decoder, CclString("42"))
  |> expect.to_equal(Ok(42))
}

pub fn one_of_falls_through_test() {
  let decoder =
    decode.one_of([
      decode.int,
      decode.map(decode.bool, fn(b) {
        case b {
          True -> 1
          False -> 0
        }
      }),
    ])
  decode.run(decoder, CclString("true"))
  |> expect.to_equal(Ok(1))
}

pub fn one_of_all_fail_test() {
  let decoder =
    decode.one_of([
      decode.int,
      decode.map(decode.bool, fn(b) {
        case b {
          True -> 1
          False -> 0
        }
      }),
    ])
  decode.run(decoder, CclString("hello"))
  |> assert_is_error
}

// --- at (deep path navigation) ---

pub fn at_navigates_nested_path_test() {
  let obj =
    CclObject(
      dict.from_list([
        #(
          "a",
          CclObject(
            dict.from_list([
              #("b", CclObject(dict.from_list([#("c", CclString("deep"))]))),
            ]),
          ),
        ),
      ]),
    )
  decode.run(decode.at(["a", "b", "c"], decode.string), obj)
  |> expect.to_equal(Ok("deep"))
}

pub fn at_empty_path_test() {
  decode.run(decode.at([], decode.string), CclString("direct"))
  |> expect.to_equal(Ok("direct"))
}

pub fn at_missing_path_returns_error_test() {
  let obj = CclObject(dict.from_list([#("a", CclString("value"))]))
  decode.run(decode.at(["a", "b"], decode.string), obj)
  |> assert_is_error
}

// --- Error formatting ---

pub fn error_to_string_no_path_test() {
  let error = DecodeError("Int", "\"abc\"", [])
  decode.error_to_string(error)
  |> expect.to_equal("Expected Int, got \"abc\"")
}

pub fn error_to_string_with_path_test() {
  let error = DecodeError("Int", "\"abc\"", ["database", "port"])
  decode.error_to_string(error)
  |> expect.to_equal("Expected Int, got \"abc\" at database.port")
}

pub fn errors_to_string_test() {
  let errors = [
    DecodeError("Int", "\"abc\"", ["port"]),
    DecodeError("field \"host\"", "nothing", ["host"]),
  ]
  decode.errors_to_string(errors)
  |> expect.to_equal(
    "Expected Int, got \"abc\" at port\nExpected field \"host\", got nothing at host",
  )
}

// --- Error path tracking ---

pub fn field_error_includes_path_test() {
  let obj = CclObject(dict.from_list([#("port", CclString("abc"))]))
  let decoder = {
    use _port <- decode.field("port", decode.int)
    decode.success(Nil)
  }
  case decode.run(decoder, obj) {
    Ok(_) -> expect.to_equal(True, False)
    Error(errors) -> {
      let assert [DecodeError(_, _, path)] = errors
      path
      |> expect.to_equal(["port"])
    }
  }
}

pub fn nested_field_error_includes_full_path_test() {
  let obj =
    CclObject(
      dict.from_list([
        #("db", CclObject(dict.from_list([#("port", CclString("abc"))]))),
      ]),
    )
  let decoder = {
    use _db <- decode.field("db", {
      use _port <- decode.field("port", decode.int)
      decode.success(Nil)
    })
    decode.success(Nil)
  }
  case decode.run(decoder, obj) {
    Ok(_) -> expect.to_equal(True, False)
    Error(errors) -> {
      let assert [DecodeError(_, _, path)] = errors
      path
      |> expect.to_equal(["db", "port"])
    }
  }
}
