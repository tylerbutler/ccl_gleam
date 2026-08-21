//// Tests for the public `ccl` module.

import ccl
import gleam/dynamic/decode
import gleam/option.{None, Some}
import startest/expect

// --- Parsing and round-tripping --------------------------------------------

pub fn api_parse_round_trips_source_test() {
  let source =
    "/= a comment\nserver =\n  host = localhost\n  port = 8080\nname = app\n"
  let assert Ok(doc) = ccl.parse(source)

  ccl.to_string(doc)
  |> expect.to_equal(source)
}

pub fn api_parse_bytes_reads_utf8_test() {
  let assert Ok(doc) = ccl.parse_bytes(<<"answer = 42\n":utf8>>)

  ccl.get_int(doc, ["answer"])
  |> expect.to_equal(Ok(42))
}

pub fn api_parse_bytes_rejects_invalid_encoding_test() {
  ccl.parse_bytes(<<110, 97, 109, 101, 32, 61, 32, 255, 10>>)
  |> expect.to_equal(Error(ccl.InvalidEncoding))
}

pub fn api_parse_indented_detects_baseline_test() {
  let assert Ok(doc) = ccl.parse_indented("    host = localhost\n")

  ccl.get_string(doc, ["host"])
  |> expect.to_equal(Ok("localhost"))
}

pub fn api_parse_value_single_line_is_terminal_test() {
  ccl.parse_value("a=b")
  |> expect.to_equal(Ok(ccl.StringValue("a=b")))
}

pub fn api_parse_value_multiline_expands_test() {
  ccl.parse_value("\n  host = localhost")
  |> expect.to_equal(
    Ok(ccl.ObjectValue([#("host", ccl.StringValue("localhost"))])),
  )
}

pub fn api_new_document_is_empty_test() {
  ccl.to_string(ccl.new())
  |> expect.to_equal("")
}

// --- Values keep source order ----------------------------------------------

pub fn api_to_value_preserves_source_order_test() {
  let assert Ok(doc) = ccl.parse("z = 1\na = 2\nm = 3\n")

  ccl.to_value(doc)
  |> expect.to_equal(
    ccl.ObjectValue([
      #("z", ccl.StringValue("1")),
      #("a", ccl.StringValue("2")),
      #("m", ccl.StringValue("3")),
    ]),
  )
}

pub fn api_keys_are_in_source_order_test() {
  let assert Ok(doc) =
    ccl.parse("server =\n  host = localhost\n  port = 8080\n")

  ccl.keys(doc, ["server"])
  |> expect.to_equal(Ok(["host", "port"]))
}

pub fn api_keys_of_root_test() {
  let assert Ok(doc) = ccl.parse("a = 1\nb = 2\n")

  ccl.keys(doc, [])
  |> expect.to_equal(Ok(["a", "b"]))
}

pub fn api_repeated_key_merges_in_place_test() {
  let assert Ok(doc) = ccl.parse("a = 1\nb = 2\na = 3\n")

  ccl.keys(doc, [])
  |> expect.to_equal(Ok(["a", "b"]))
}

// --- Typed reads ------------------------------------------------------------

pub fn api_get_string_test() {
  let assert Ok(doc) = ccl.parse("server =\n  host = localhost\n")

  ccl.get_string(doc, ["server", "host"])
  |> expect.to_equal(Ok("localhost"))
}

pub fn api_get_int_test() {
  let assert Ok(doc) = ccl.parse("port = 8080\n")

  ccl.get_int(doc, ["port"])
  |> expect.to_equal(Ok(8080))
}

pub fn api_get_int_wrong_type_test() {
  let assert Ok(doc) = ccl.parse("port = http\n")

  ccl.get_int(doc, ["port"])
  |> expect.to_equal(Error(ccl.WrongType(["port"], ccl.ExpectedInt)))
}

pub fn api_get_missing_key_test() {
  let assert Ok(doc) = ccl.parse("port = 8080\n")

  ccl.get_string(doc, ["host"])
  |> expect.to_equal(Error(ccl.KeyNotFound(["host"])))
}

pub fn api_get_through_terminal_is_wrong_type_test() {
  let assert Ok(doc) = ccl.parse("port = 8080\n")

  ccl.get_string(doc, ["port", "inner"])
  |> expect.to_equal(
    Error(ccl.WrongType(["port", "inner"], ccl.ExpectedObject)),
  )
}

pub fn api_get_bool_strict_rejects_yes_test() {
  let assert Ok(doc) = ccl.parse("debug = yes\n")

  ccl.get_bool(doc, ["debug"])
  |> expect.to_equal(Error(ccl.WrongType(["debug"], ccl.ExpectedBool)))
}

pub fn api_get_bool_lenient_accepts_yes_test() {
  let options = ccl.default_options() |> ccl.with_booleans(ccl.BooleanLenient)
  let assert Ok(doc) = ccl.parse_with("debug = yes\n", options)

  ccl.get_bool(doc, ["debug"])
  |> expect.to_equal(Ok(True))
}

pub fn api_get_float_accepts_integer_literal_test() {
  let assert Ok(doc) = ccl.parse("ratio = 2\n")

  ccl.get_float(doc, ["ratio"])
  |> expect.to_equal(Ok(2.0))
}

pub fn api_get_list_test() {
  let assert Ok(doc) = ccl.parse("ports =\n  = 80\n  = 443\n")

  ccl.get_list(doc, ["ports"])
  |> expect.to_equal(Ok(["80", "443"]))
}

pub fn api_get_list_rejects_scalar_by_default_test() {
  let assert Ok(doc) = ccl.parse("ports = 80\n")

  ccl.get_list(doc, ["ports"])
  |> expect.to_equal(Error(ccl.WrongType(["ports"], ccl.ExpectedList)))
}

pub fn api_get_list_coercion_enabled_test() {
  let options =
    ccl.default_options() |> ccl.with_list_coercion(ccl.CoercionEnabled)
  let assert Ok(doc) = ccl.parse_with("ports = 80\n", options)

  ccl.get_list(doc, ["ports"])
  |> expect.to_equal(Ok(["80"]))
}

pub fn api_list_index_path_test() {
  let assert Ok(doc) = ccl.parse("ports =\n  = 80\n  = 443\n")

  ccl.get_string(doc, ["ports", "1"])
  |> expect.to_equal(Ok("443"))
}

pub fn api_list_index_out_of_range_test() {
  let assert Ok(doc) = ccl.parse("ports =\n  = 80\n")

  ccl.get_string(doc, ["ports", "9"])
  |> expect.to_equal(Error(ccl.KeyNotFound(["ports", "9"])))
}

pub fn api_lexicographic_list_order_test() {
  let options =
    ccl.default_options() |> ccl.with_list_order(ccl.LexicographicOrder)
  let assert Ok(doc) = ccl.parse_with("ports =\n  = 443\n  = 80\n", options)

  ccl.get_list(doc, ["ports"])
  |> expect.to_equal(Ok(["443", "80"]))
}

// --- Value converters -------------------------------------------------------

pub fn api_as_string_test() {
  ccl.as_string(ccl.StringValue("x"))
  |> expect.to_equal(Ok("x"))
}

pub fn api_as_string_wrong_type_carries_empty_path_test() {
  ccl.as_string(ccl.ListValue([]))
  |> expect.to_equal(Error(ccl.WrongType([], ccl.ExpectedString)))
}

pub fn api_as_pairs_test() {
  ccl.as_pairs(ccl.ObjectValue([#("a", ccl.StringValue("1"))]))
  |> expect.to_equal(Ok([#("a", ccl.StringValue("1"))]))
}

pub fn api_value_get_uses_relative_path_test() {
  let assert Ok(doc) = ccl.parse("server =\n  host = localhost\n")
  let assert Ok(server) = ccl.get(doc, ["server"])

  ccl.value_get(server, ["host"])
  |> expect.to_equal(Ok(ccl.StringValue("localhost")))
}

// --- Dynamic decoding -------------------------------------------------------

pub fn api_decode_test() {
  let server_decoder = {
    use host <- decode.field("host", decode.string)
    use port <- decode.field("port", decode.string)
    decode.success(#(host, port))
  }

  ccl.decode("host = localhost\nport = 8080\n", server_decoder)
  |> expect.to_equal(Ok(#("localhost", "8080")))
}

pub fn api_decode_nested_test() {
  let decoder = {
    use host <- decode.subfield(["server", "host"], decode.string)
    decode.success(host)
  }

  ccl.decode("server =\n  host = localhost\n", decoder)
  |> expect.to_equal(Ok("localhost"))
}

pub fn api_decode_list_test() {
  let decoder = {
    use ports <- decode.field("ports", decode.list(decode.string))
    decode.success(ports)
  }

  ccl.decode("ports =\n  = 80\n  = 443\n", decoder)
  |> expect.to_equal(Ok(["80", "443"]))
}

pub fn api_int_decoder_test() {
  let decoder = {
    use port <- decode.field("port", ccl.int_decoder())
    decode.success(port)
  }

  ccl.decode("port = 8080\n", decoder)
  |> expect.to_equal(Ok(8080))
}

pub fn api_int_decoder_rejects_non_numeric_test() {
  let decoder = {
    use port <- decode.field("port", ccl.int_decoder())
    decode.success(port)
  }

  let assert Error(ccl.DecodeDynamicError(_)) =
    ccl.decode("port = http\n", decoder)
  Nil
}

pub fn api_bool_decoder_test() {
  let decoder = {
    use debug <- decode.field("debug", ccl.bool_decoder())
    decode.success(debug)
  }

  ccl.decode("debug = true\n", decoder)
  |> expect.to_equal(Ok(True))
}

pub fn api_float_decoder_accepts_integer_literal_test() {
  let decoder = {
    use ratio <- decode.field("ratio", ccl.float_decoder())
    decode.success(ratio)
  }

  ccl.decode("ratio = 2\n", decoder)
  |> expect.to_equal(Ok(2.0))
}

pub fn api_scalar_decoders_compose_in_a_record_test() {
  let decoder = {
    use host <- decode.field("host", decode.string)
    use port <- decode.field("port", ccl.int_decoder())
    use debug <- decode.field("debug", ccl.bool_decoder())
    use tags <- decode.field("tags", decode.list(decode.string))
    use bio <- decode.optional_field(
      "bio",
      option.None,
      decode.optional(decode.string),
    )
    decode.success(#(host, port, debug, tags, bio))
  }

  ccl.decode(
    "host = localhost\nport = 8080\ndebug = true\ntags =\n  = a\n  = b\n",
    decoder,
  )
  |> expect.to_equal(Ok(#("localhost", 8080, True, ["a", "b"], option.None)))
}

// --- Editing ----------------------------------------------------------------

pub fn api_set_string_replaces_in_place_test() {
  let assert Ok(doc) =
    ccl.parse("server =\n  host = localhost\n  port = 8080\n")
  let assert Ok(updated) =
    ccl.set_string(doc, ["server", "host"], "example.com")

  ccl.to_string(updated)
  |> expect.to_equal("server =\n  host = example.com\n  port = 8080\n")
}

pub fn api_set_int_test() {
  let assert Ok(doc) = ccl.parse("server =\n  port = 8080\n")
  let assert Ok(updated) = ccl.set_int(doc, ["server", "port"], 9090)

  ccl.to_string(updated)
  |> expect.to_equal("server =\n  port = 9090\n")
}

pub fn api_set_preserves_comments_test() {
  let assert Ok(doc) = ccl.parse("/= the port\nport = 8080\n")
  let assert Ok(updated) = ccl.set_int(doc, ["port"], 9090)

  ccl.to_string(updated)
  |> expect.to_equal("/= the port\nport = 9090\n")
}

pub fn api_set_preserves_existing_indentation_test() {
  let assert Ok(doc) = ccl.parse("server =\n    host = localhost\n")
  let assert Ok(updated) =
    ccl.set_string(doc, ["server", "host"], "example.com")

  ccl.to_string(updated)
  |> expect.to_equal("server =\n    host = example.com\n")
}

pub fn api_set_creates_missing_path_test() {
  let assert Ok(updated) = ccl.set_string(ccl.new(), ["a", "b", "c"], "deep")

  ccl.to_string(updated)
  |> expect.to_equal("a =\n  b =\n    c = deep\n")
}

pub fn api_set_appends_new_key_at_end_test() {
  let assert Ok(doc) = ccl.parse("a = 1\n")
  let assert Ok(updated) = ccl.set_string(doc, ["b"], "2")

  ccl.to_string(updated)
  |> expect.to_equal("a = 1\nb = 2\n")
}

pub fn api_set_list_test() {
  let assert Ok(updated) = ccl.set_list(ccl.new(), ["ports"], ["80", "443"])

  ccl.to_string(updated)
  |> expect.to_equal("ports =\n  = 80\n  = 443\n")
}

pub fn api_set_object_test() {
  let assert Ok(updated) =
    ccl.set_object(ccl.new(), ["server"], [
      #("host", ccl.StringValue("localhost")),
      #("port", ccl.StringValue("8080")),
    ])

  ccl.to_string(updated)
  |> expect.to_equal("server =\n  host = localhost\n  port = 8080\n")
}

pub fn api_set_round_trips_through_parse_test() {
  let assert Ok(updated) =
    ccl.set_object(ccl.new(), ["server"], [
      #("host", ccl.StringValue("localhost")),
      #("ports", ccl.ListValue([ccl.StringValue("80")])),
    ])
  let assert Ok(reparsed) = ccl.parse(ccl.to_string(updated))

  ccl.get_list(reparsed, ["server", "ports"])
  |> expect.to_equal(Ok(["80"]))
}

pub fn api_set_bool_test() {
  let assert Ok(updated) = ccl.set_bool(ccl.new(), ["debug"], True)

  ccl.to_string(updated)
  |> expect.to_equal("debug = true\n")
}

pub fn api_append_list_item_test() {
  let assert Ok(doc) = ccl.parse("ports =\n  = 80\n")
  let assert Ok(updated) =
    ccl.append_list_item(doc, ["ports"], ccl.StringValue("443"))

  ccl.to_string(updated)
  |> expect.to_equal("ports =\n  = 80\n  = 443\n")
}

pub fn api_remove_test() {
  let assert Ok(doc) = ccl.parse("a = 1\nb = 2\n")
  let assert Ok(updated) = ccl.remove(doc, ["a"])

  ccl.to_string(updated)
  |> expect.to_equal("b = 2\n")
}

pub fn api_remove_nested_test() {
  let assert Ok(doc) =
    ccl.parse("server =\n  host = localhost\n  port = 8080\n")
  let assert Ok(updated) = ccl.remove(doc, ["server", "port"])

  ccl.to_string(updated)
  |> expect.to_equal("server =\n  host = localhost\n")
}

pub fn api_remove_missing_key_test() {
  let assert Ok(doc) = ccl.parse("a = 1\n")

  ccl.remove(doc, ["b"])
  |> expect.to_equal(Error(ccl.MissingEditKey(["b"])))
}

pub fn api_insert_comment_before_test() {
  let assert Ok(doc) = ccl.parse("port = 8080\n")
  let assert Ok(updated) =
    ccl.insert_comment_before(doc, ["port"], "the listening port")

  ccl.to_string(updated)
  |> expect.to_equal("/= the listening port\nport = 8080\n")
}

pub fn api_insert_comment_nested_test() {
  let assert Ok(doc) = ccl.parse("server =\n  port = 8080\n")
  let assert Ok(updated) =
    ccl.insert_comment_before(doc, ["server", "port"], "listening port")

  ccl.to_string(updated)
  |> expect.to_equal("server =\n  /= listening port\n  port = 8080\n")
}

pub fn api_insert_comment_rejects_newline_test() {
  let assert Ok(doc) = ccl.parse("port = 8080\n")

  ccl.insert_comment_before(doc, ["port"], "one\ntwo")
  |> expect.to_equal(Error(ccl.InvalidCommentText))
}

// --- Edit validation --------------------------------------------------------

pub fn api_set_rejects_empty_path_test() {
  ccl.set_string(ccl.new(), [], "x")
  |> expect.to_equal(Error(ccl.EmptyKeyPath))
}

pub fn api_set_rejects_key_with_equals_test() {
  ccl.set_string(ccl.new(), ["a=b"], "x")
  |> expect.to_equal(Error(ccl.InvalidKeySegment("a=b")))
}

pub fn api_set_rejects_untrimmed_key_test() {
  ccl.set_string(ccl.new(), [" a"], "x")
  |> expect.to_equal(Error(ccl.InvalidKeySegment(" a")))
}

pub fn api_set_rejects_multiline_string_test() {
  ccl.set_string(ccl.new(), ["a"], "one\ntwo")
  |> expect.to_equal(Error(ccl.InvalidValue))
}

pub fn api_set_through_terminal_is_key_conflict_test() {
  let assert Ok(doc) = ccl.parse("a = 1\n")

  ccl.set_string(doc, ["a", "b"], "x")
  |> expect.to_equal(Error(ccl.KeyConflict(["a"])))
}

// --- Canonical output and model --------------------------------------------

pub fn api_to_canonical_string_sorts_keys_test() {
  let assert Ok(doc) = ccl.parse("z = 1\na = 2\n")

  ccl.to_canonical_string(doc)
  |> expect.to_equal("a = 2\nz = 1")
}

pub fn api_to_model_test() {
  let assert Ok(doc) = ccl.parse("a = 1\n")

  ccl.to_model(doc)
  |> expect.to_equal(ccl.Model([#("a", ccl.Model([#("1", ccl.Model([]))]))]))
}

// --- Positions --------------------------------------------------------------

pub fn api_line_column_test() {
  let position = ccl.line_column("a = 1\nb = 2\n", 6)

  #(ccl.position_line(position), ccl.position_column(position))
  |> expect.to_equal(#(2, 1))
}

pub fn api_line_column_treats_crlf_as_one_break_test() {
  let position = ccl.line_column("a = 1\r\nb = 2\r\n", 7)

  #(ccl.position_line(position), ccl.position_column(position))
  |> expect.to_equal(#(2, 1))
}

// Keep `option` imported for the doc-facing assertions above without an unused
// warning when the file is trimmed.
pub fn api_options_accessor_test() {
  let assert Ok(doc) = ccl.parse("a = 1\n")
  let _ = ccl.options(doc)
  let _ = Some(None)

  ccl.get_string(doc, ["a"])
  |> expect.to_equal(Ok("1"))
}
