//// Categorical Configuration Language (CCL) for Gleam.
////
//// CCL parses into an opaque `Document` that retains the original source, key
//// order, comments, and indentation. Unedited documents round-trip to their
//// original text; edits write back in place and preserve the surrounding
//// structure. `Document` stays opaque so the internal entry
//// representation can evolve without breaking the public API.
////
//// ```gleam
//// import ccl
////
//// pub fn main() {
////   let source = "/= the server block\nserver =\n  host = localhost\n  port = 8080\n"
////
////   case ccl.parse(source) {
////     Ok(doc) ->
////       case ccl.set_int(doc, ["server", "port"], 9090) {
////         Ok(updated) -> ccl.to_string(updated)
////         // -> "/= the server block\nserver =\n  host = localhost\n  port = 9090\n"
////         Error(error) -> handle_edit_error(error)
////       }
////     Error(error) -> handle_parse_error(error)
////   }
//// }
//// ```

import ccl/format
import ccl/model
import ccl/parser
import ccl/types
import gleam/bit_array
import gleam/dict.{type Dict}
import gleam/dynamic
import gleam/dynamic/decode as dynamic_decode
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

// --- Documents -------------------------------------------------------------

/// A parsed CCL document.
///
/// Documents are opaque so CCL can preserve round-trip invariants while the
/// internal entry representation changes. A document keeps the `Options` it
/// was parsed with, so reads and edits stay consistent with the parse.
pub opaque type Document {
  Document(
    entries: List(types.Entry),
    options: Options,
    /// `Some(text)` while the document still matches the text it was parsed
    /// from. Cleared by every edit so `to_string` re-emits from the entries.
    original_source: Option(String),
    /// Whether the source ended with a newline. `to_string` restores it on
    /// edited documents, since the entry list itself stores no trailing
    /// terminator.
    trailing_newline: Bool,
  )
}

/// Create an empty CCL document.
///
/// Equivalent to `parse("")` for downstream callers. The only observable
/// difference: a document from `parse("")` records that its source had no
/// trailing newline, so its edits emit none, while a document from `new`
/// always ends its output with one.
pub fn new() -> Document {
  Document(
    entries: [],
    options: default_options(),
    original_source: None,
    trailing_newline: True,
  )
}

// --- Errors ----------------------------------------------------------------

/// Errors that can occur while parsing CCL input.
///
/// Variants are part of the stable public API. Adding, removing, or renaming
/// a variant is a breaking change.
///
/// CCL's grammar accepts any text, so `parse` on a `String` does not currently
/// fail. `ParseError` exists so the library can report byte-level and future
/// strict-mode diagnostics without a breaking change; `parse_bytes` already
/// returns `InvalidEncoding`.
pub type ParseError {
  /// The raw bytes are not valid UTF-8 text.
  InvalidEncoding

  /// CCL syntax was invalid at a byte offset.
  InvalidSyntax(kind: SyntaxErrorKind, offset: Int)
}

/// Stable categories for CCL syntax errors.
///
/// Variants are part of the stable public API. Adding, removing, or renaming
/// a variant is a breaking change.
pub type SyntaxErrorKind {
  /// The parser expected a key before the `=` delimiter.
  ExpectedKey

  /// The parser expected a value after the `=` delimiter.
  ExpectedValue

  /// CCL syntax was invalid, but the parser does not expose a narrower stable
  /// category.
  InvalidCcl
}

/// Errors that can occur while reading typed values from a document.
///
/// Variants are part of the stable public API. Adding, removing, or renaming
/// a variant is a breaking change.
pub type GetError {
  /// No value exists at the requested key path.
  KeyNotFound(key: List(String))

  /// A value exists at the requested key path, but it has a different CCL
  /// shape, or its text does not parse as the requested type.
  WrongType(key: List(String), expected: ExpectedType)
}

/// CCL value kinds used in typed read errors.
///
/// Variants are part of the stable public API. Adding, removing, or renaming
/// a variant is a breaking change.
pub type ExpectedType {
  ExpectedString
  ExpectedInt
  ExpectedBool
  ExpectedFloat
  ExpectedList
  ExpectedObject
}

/// Errors that can occur while editing a document.
///
/// Variants are part of the stable public API. Adding, removing, or renaming
/// a variant is a breaking change.
pub type EditError {
  /// Edit paths must contain at least one key segment.
  EmptyKeyPath

  /// A key segment cannot be emitted as CCL. Segments may not be empty,
  /// contain a newline or an `=`, or have leading or trailing whitespace,
  /// since the parser would not read the result back as the same key.
  InvalidKeySegment(segment: String)

  /// Comments must be a single line.
  InvalidCommentText

  /// The edit requires an existing key, but no value exists at that key path.
  MissingEditKey(key: List(String))

  /// Descending through the path would have to replace an existing terminal
  /// value with a nested block.
  KeyConflict(key: List(String))

  /// The supplied value cannot be represented in the requested edit context.
  /// A `set_string` value containing a newline is the common case; use
  /// `set_value` with an `ObjectValue` or `ListValue` for multi-line data.
  InvalidValue
}

/// Errors that can occur while parsing CCL and decoding it with a dynamic
/// decoder.
pub type DecodeError {
  /// The input did not parse as CCL.
  DecodeParseError(ParseError)

  /// The input parsed successfully, but the supplied decoder did not match the
  /// data.
  DecodeDynamicError(List(dynamic_decode.DecodeError))
}

// --- Values ----------------------------------------------------------------

/// A CCL value.
///
/// Variants are part of the stable public API. Adding, removing, or renaming
/// a variant is a breaking change.
///
/// `ObjectValue` exposes its entries as an ordered association list of
/// `#(key, value)` pairs, and this shape is stable, so source order survives
/// a read. Repeated empty keys (`= a`, `= b`) collect into a
/// `ListValue` stored under the `""` key of their enclosing object.
pub type Value {
  /// A terminal value — the fixed point, with no further `=` to expand.
  StringValue(String)

  /// A nested block, in source order.
  ObjectValue(List(#(String, Value)))

  /// A list accumulated from repeated empty-key entries.
  ListValue(List(Value))
}

/// A flat key/value entry, as produced by CCL's first parsing pass.
///
/// The parser trims surrounding whitespace from keys. Values keep their
/// internal structure, so a nested block's value is the multi-line text under
/// it, indentation included. Two keys are special: `""` marks a list item written
/// as `= value`, and `"/"` marks a comment written as `/= text`.
pub type Entry {
  Entry(key: String, value: String)
}

/// CCL's canonical recursive model, mirroring the OCaml reference's
/// `Fix of t KeyMap.t`.
///
/// Terminal strings become keys pointing at the empty model, duplicate keys
/// merge, and every leaf is `Model([])`. Unlike `Value`, the model is
/// order-agnostic by construction; ordering belongs to the typed projections.
pub type Model {
  Model(List(#(String, Model)))
}

// --- Source positions ------------------------------------------------------

/// A one-based source position.
///
/// Positions are opaque so later versions can add more source-location detail
/// without a change to the public constructor shape. Use `position_line` and
/// `position_column` to inspect one.
pub opaque type Position {
  Position(line: Int, column: Int)
}

/// Convert a byte offset into a one-based line and column.
///
/// Offsets beyond the end of the input return the position just after the last
/// character. CRLF counts as a single line break.
pub fn line_column(input: String, offset: Int) -> Position {
  count_position(bit_array.from_string(input), offset, 1, 1)
}

/// Return the one-based line number for a source position.
pub fn position_line(position: Position) -> Int {
  position.line
}

/// Return the one-based column number for a source position.
pub fn position_column(position: Position) -> Int {
  position.column
}

fn count_position(
  bytes: BitArray,
  remaining: Int,
  line: Int,
  column: Int,
) -> Position {
  case remaining <= 0, bytes {
    True, _ -> Position(line, column)
    False, <<0x0D, 0x0A, rest:bits>> ->
      count_position(rest, remaining - 2, line + 1, 1)
    False, <<0x0A, rest:bits>> ->
      count_position(rest, remaining - 1, line + 1, 1)
    False, <<_, rest:bits>> ->
      count_position(rest, remaining - 1, line, column + 1)
    False, _ -> Position(line, column)
  }
}

// --- Options ---------------------------------------------------------------

/// Parsing, reading, and list-building behaviour for a document.
///
/// `Options` is opaque so new settings can be added without breaking callers.
/// Start from `default_options` and pipe through the `with_*` builders:
///
/// ```gleam
/// let options =
///   ccl.default_options()
///   |> ccl.with_delimiter(ccl.FirstEquals)
///   |> ccl.with_booleans(ccl.BooleanLenient)
///
/// ccl.parse_with(source, options)
/// ```
pub opaque type Options {
  Options(
    parse: types.ParseOptions,
    access: types.AccessOptions,
    build: types.BuildOptions,
  )
}

/// How the parser treats CRLF line endings.
pub type LineEndings {
  /// Rewrite every `\r\n` to `\n` before parsing. The cross-platform default.
  NormalizeCrlf

  /// Keep `\r` characters exactly as they appear in the source.
  PreserveCrlf
}

/// How the parser treats tab characters.
pub type Tabs {
  /// Spaces and tabs both count as indentation whitespace. The default.
  TabsAsWhitespace

  /// Only spaces count as indentation; tabs stay in the value as content.
  TabsAsContent
}

/// The indentation baseline used for top-level entries.
pub type Baseline {
  /// The top-level baseline is always column 0, matching the OCaml reference.
  /// The default.
  StripToplevelIndent

  /// The parser detects the top-level baseline from the first content line,
  /// so uniformly indented documents parse as if they started at column 0.
  PreserveToplevelIndent
}

/// How the parser locates the `=` delimiter on a line that contains more
/// than one.
pub type Delimiter {
  /// Always split on the first `=` in the line.
  FirstEquals

  /// Prefer a spaced ` = ` delimiter; when the line has no spaced form, split
  /// on the first `=`. Lets keys contain `=`, such as URLs with query
  /// parameters. The default.
  PreferSpaced
}

/// Which strings `get_bool` and `as_bool` accept.
pub type Booleans {
  /// Only `true` and `false`, case-insensitively. The default.
  BooleanStrict

  /// Also accept `yes`/`no`, `on`/`off`, and `1`/`0`, case-insensitively.
  BooleanLenient
}

/// Whether a single value can stand in for a one-element list.
pub type ListCoercion {
  /// Reading a list from a terminal value is a `WrongType` error. The default.
  CoercionDisabled

  /// A terminal value reads as a one-element list.
  CoercionEnabled
}

/// The order in which repeated empty-key entries are collected.
pub type ListOrder {
  /// Elements keep their source order. The default.
  InsertionOrder

  /// Elements sort lexicographically by their terminal text.
  LexicographicOrder
}

/// The default options: CRLF normalised to LF, tabs as whitespace, a
/// stripped top-level indent, spaced-delimiter preference, strict booleans, no
/// list coercion, and insertion-ordered lists.
pub fn default_options() -> Options {
  Options(
    parse: types.default_parse_options(),
    access: types.default_access_options(),
    build: types.default_build_options(),
  )
}

/// Set how the parser treats CRLF line endings.
pub fn with_line_endings(
  options: Options,
  line_endings: LineEndings,
) -> Options {
  let behaviour = case line_endings {
    NormalizeCrlf -> types.NormalizeToLf
    PreserveCrlf -> types.PreserveLiteral
  }
  Options(
    ..options,
    parse: types.ParseOptions(..options.parse, line_endings: behaviour),
  )
}

/// Set how the parser treats tab characters.
pub fn with_tabs(options: Options, tabs: Tabs) -> Options {
  let behaviour = case tabs {
    TabsAsWhitespace -> types.TabsAsWhitespace
    TabsAsContent -> types.TabsAsContent
  }
  Options(
    ..options,
    parse: types.ParseOptions(..options.parse, tab_handling: behaviour),
  )
}

/// Set the indentation baseline used for top-level entries.
pub fn with_baseline(options: Options, baseline: Baseline) -> Options {
  let behaviour = case baseline {
    StripToplevelIndent -> types.IndentStrip
    PreserveToplevelIndent -> types.IndentPreserve
  }
  Options(
    ..options,
    parse: types.ParseOptions(..options.parse, continuation_baseline: behaviour),
  )
}

/// Set how the parser locates the `=` delimiter.
pub fn with_delimiter(options: Options, delimiter: Delimiter) -> Options {
  let behaviour = case delimiter {
    FirstEquals -> types.DelimiterFirstEquals
    PreferSpaced -> types.DelimiterPreferSpaced
  }
  Options(
    ..options,
    parse: types.ParseOptions(..options.parse, delimiter_strategy: behaviour),
  )
}

/// Set which strings `get_bool` and `as_bool` accept.
pub fn with_booleans(options: Options, booleans: Booleans) -> Options {
  let behaviour = case booleans {
    BooleanStrict -> types.BooleanStrict
    BooleanLenient -> types.BooleanLenient
  }
  Options(
    ..options,
    access: types.AccessOptions(..options.access, boolean_parsing: behaviour),
  )
}

/// Set whether a terminal value reads as a one-element list.
pub fn with_list_coercion(options: Options, coercion: ListCoercion) -> Options {
  let behaviour = case coercion {
    CoercionDisabled -> types.CoercionDisabled
    CoercionEnabled -> types.CoercionEnabled
  }
  Options(
    ..options,
    access: types.AccessOptions(..options.access, list_coercion: behaviour),
  )
}

/// Set the order in which repeated empty-key entries are collected.
pub fn with_list_order(options: Options, order: ListOrder) -> Options {
  let behaviour = case order {
    InsertionOrder -> types.InsertionOrder
    LexicographicOrder -> types.LexicographicOrder
  }
  Options(..options, build: types.BuildOptions(array_order: behaviour))
}

/// Return the options a document was parsed with.
pub fn options(doc: Document) -> Options {
  doc.options
}

// --- Parsing ---------------------------------------------------------------

/// Parse CCL text into a document using the default options.
///
/// The returned `Document` preserves the source text, key order, comments, and
/// indentation for round-tripping.
///
/// ```gleam
/// let assert Ok(doc) = ccl.parse("answer = 42\n")
/// let assert Ok(42) = ccl.get_int(doc, ["answer"])
/// ```
pub fn parse(input: String) -> Result(Document, ParseError) {
  parse_with(input, default_options())
}

/// Parse CCL text into a document with the given options.
pub fn parse_with(
  input: String,
  options: Options,
) -> Result(Document, ParseError) {
  use entries <- result.try(
    to_parse_error(parser.parse_with(input, options.parse)),
  )
  Ok(Document(
    entries: entries,
    options: options,
    original_source: Some(input),
    trailing_newline: string.ends_with(input, "\n"),
  ))
}

/// Parse pre-indented CCL text, detecting the baseline indentation from the
/// first content line rather than assuming column 0.
///
/// Use this for a CCL fragment lifted out of a larger document, where every
/// line still has the enclosing block's indentation.
///
/// ```gleam
/// let assert Ok(doc) = ccl.parse_indented("    host = localhost\n")
/// let assert Ok("localhost") = ccl.get_string(doc, ["host"])
/// ```
pub fn parse_indented(input: String) -> Result(Document, ParseError) {
  parse_indented_with(input, default_options())
}

/// Parse pre-indented CCL text with the given options.
pub fn parse_indented_with(
  input: String,
  options: Options,
) -> Result(Document, ParseError) {
  use entries <- result.try(
    to_parse_error(parser.parse_indented_with(input, options.parse)),
  )
  Ok(Document(
    entries: entries,
    options: options,
    original_source: Some(input),
    trailing_newline: string.ends_with(input, "\n"),
  ))
}

/// Parse CCL bytes into a document.
///
/// This validates that the input is UTF-8 before parsing.
///
/// ```gleam
/// let assert Ok(doc) = ccl.parse_bytes(<<"answer = 42\n":utf8>>)
///
/// ccl.parse_bytes(<<110, 97, 109, 101, 32, 61, 32, 255, 10>>)
/// // -> Error(ccl.InvalidEncoding)
/// ```
pub fn parse_bytes(input: BitArray) -> Result(Document, ParseError) {
  parse_bytes_with(input, default_options())
}

/// Parse CCL bytes into a document with the given options.
pub fn parse_bytes_with(
  input: BitArray,
  options: Options,
) -> Result(Document, ParseError) {
  case bit_array.to_string(input) {
    Ok(text) -> parse_with(text, options)
    Error(_) -> Error(InvalidEncoding)
  }
}

/// Parse a standalone CCL value, as it would appear on the right-hand side of
/// an `=`.
///
/// A single-line input is always a terminal `StringValue`, even when it
/// contains an `=` — that `=` is content, not a delimiter. A multi-line input
/// expands into an `ObjectValue` or `ListValue`.
///
/// ```gleam
/// ccl.parse_value("localhost")
/// // -> Ok(ccl.StringValue("localhost"))
///
/// ccl.parse_value("\n  host = localhost\n")
/// // -> Ok(ccl.ObjectValue([#("host", ccl.StringValue("localhost"))]))
/// ```
pub fn parse_value(input: String) -> Result(Value, ParseError) {
  parse_value_with(input, default_options())
}

/// Parse a standalone CCL value with the given options.
pub fn parse_value_with(
  input: String,
  options: Options,
) -> Result(Value, ParseError) {
  Ok(resolve_value(input, options))
}

/// Parse CCL text into decoder-friendly dynamic data.
///
/// See `to_dynamic` for the shape of the result.
pub fn parse_dynamic(input: String) -> Result(dynamic.Dynamic, ParseError) {
  parse_dynamic_with(input, default_options())
}

/// Parse CCL text into decoder-friendly dynamic data with the given options.
pub fn parse_dynamic_with(
  input: String,
  options: Options,
) -> Result(dynamic.Dynamic, ParseError) {
  use doc <- result.map(parse_with(input, options))
  to_dynamic(doc)
}

/// Parse CCL text and run a `gleam/dynamic/decode` decoder against it.
///
/// This is a convenience wrapper around `parse_dynamic` and `decode.run`.
///
/// ```gleam
/// import gleam/dynamic/decode
///
/// let server_decoder = {
///   use host <- decode.field("host", decode.string)
///   use port <- decode.field("port", decode.string)
///   decode.success(#(host, port))
/// }
///
/// ccl.decode("host = localhost\nport = 8080\n", server_decoder)
/// // -> Ok(#("localhost", "8080"))
/// ```
///
/// Every CCL terminal value is text, so `decode.int`, `decode.bool`, and
/// `decode.float` do not match. Use `int_decoder`, `bool_decoder`, and
/// `float_decoder` for those fields.
pub fn decode(
  input: String,
  decoder: dynamic_decode.Decoder(a),
) -> Result(a, DecodeError) {
  decode_with(input, default_options(), decoder)
}

/// Parse CCL text with the given options and run a dynamic decoder against it.
pub fn decode_with(
  input: String,
  options: Options,
  decoder: dynamic_decode.Decoder(a),
) -> Result(a, DecodeError) {
  case parse_dynamic_with(input, options) {
    Error(error) -> Error(DecodeParseError(error))
    Ok(data) ->
      dynamic_decode.run(data, decoder)
      |> result.map_error(DecodeDynamicError)
  }
}

// The underlying parser accepts any text, so its `String` error channel is
// currently unreachable. Map it to the stable variant rather than leaking the
// internal message, so a future strict mode is not a breaking change.
fn to_parse_error(
  parsed: Result(List(types.Entry), String),
) -> Result(List(types.Entry), ParseError) {
  result.map_error(parsed, fn(_) { InvalidSyntax(InvalidCcl, 0) })
}

/// A decoder for CCL's integer text.
///
/// Every CCL terminal value is text, so `decode.int` never matches a parsed
/// document. This reads the same lexical form `get_int` accepts, and is what
/// belongs in a decoder for an `Int` field.
///
/// ```gleam
/// import gleam/dynamic/decode
///
/// let decoder = {
///   use port <- decode.field("port", ccl.int_decoder())
///   decode.success(port)
/// }
///
/// ccl.decode("port = 8080\n", decoder)
/// // -> Ok(8080)
/// ```
pub fn int_decoder() -> dynamic_decode.Decoder(Int) {
  use text <- dynamic_decode.then(dynamic_decode.string)
  case parse_int(text) {
    Ok(number) -> dynamic_decode.success(number)
    Error(_) -> dynamic_decode.failure(0, "Int")
  }
}

/// A decoder for CCL's boolean text, accepting only `true` and `false`.
///
/// See `int_decoder` for why `decode.bool` does not work here.
pub fn bool_decoder() -> dynamic_decode.Decoder(Bool) {
  use text <- dynamic_decode.then(dynamic_decode.string)
  case parse_bool(text, default_options()) {
    Ok(boolean) -> dynamic_decode.success(boolean)
    Error(_) -> dynamic_decode.failure(False, "Bool")
  }
}

/// A decoder for CCL's float text. An integer literal decodes as a float.
///
/// See `int_decoder` for why `decode.float` does not work here.
pub fn float_decoder() -> dynamic_decode.Decoder(Float) {
  use text <- dynamic_decode.then(dynamic_decode.string)
  case parse_float(text) {
    Ok(number) -> dynamic_decode.success(number)
    Error(_) -> dynamic_decode.failure(0.0, "Float")
  }
}

// --- Output ----------------------------------------------------------------

/// Emit a document as CCL text.
///
/// Unedited parsed documents round-trip to their original source text. An
/// edited document re-emits from its entries and keeps key order, comments,
/// and the indentation of untouched blocks.
pub fn to_string(doc: Document) -> String {
  case doc.original_source {
    Some(source) -> source
    None -> {
      let text = render_entries(doc.entries, 0)
      case doc.trailing_newline, text {
        _, "" -> ""
        True, _ -> text <> "\n"
        False, _ -> text
      }
    }
  }
}

/// Emit a document in CCL's canonical form: normalised two-space indentation,
/// keys sorted lexicographically, and duplicate keys merged.
///
/// This preserves meaning rather than layout, so comments and source order do
/// not survive.
pub fn to_canonical_string(doc: Document) -> String {
  let base_indent = case doc.options.parse.continuation_baseline {
    types.IndentPreserve -> parser.detect_baseline(to_string(doc))
    _ -> 0
  }
  format.canonical_format(to_dict(doc), base_indent)
}

/// Read a document as a single `ObjectValue`, in source order.
///
/// Equivalent to `get(doc, [])`.
pub fn to_value(doc: Document) -> Value {
  ObjectValue(document_pairs(doc))
}

/// Read a document's flat entries, in source order and before any nesting is
/// expanded.
///
/// This is CCL's first parsing pass: every top-level `key = value` pair, with
/// nested blocks left as the raw multi-line text of their value. Use
/// `to_value` for the expanded tree.
///
/// ```gleam
/// let assert Ok(doc) = ccl.parse("server =\n  host = localhost\n")
/// ccl.entries(doc)
/// // -> [ccl.Entry("server", "\n  host = localhost")]
/// ```
pub fn entries(doc: Document) -> List(Entry) {
  list.map(doc.entries, fn(entry) { Entry(entry.key, entry.value) })
}

/// Emit a flat entry list as CCL text.
///
/// This is CCL's structure-preserving `print`, the inverse of the parse pass:
/// `print(entries(doc))` reproduces the document's source for standard-format
/// input, without a trailing newline. Use `to_string` to emit a whole document
/// with its original trailing newline restored.
pub fn print(entries entries: List(Entry)) -> String {
  render_entries(
    list.map(entries, fn(entry) { types.Entry(entry.key, entry.value) }),
    0,
  )
}

/// Read a document as CCL's canonical recursive `Model`.
pub fn to_model(doc: Document) -> Model {
  model.build_model_with(doc.entries, doc.options.parse)
  |> from_internal_model
}

/// Convert a document to decoder-friendly dynamic data.
///
/// The shape is intentionally JSON-like: nested blocks become property maps,
/// repeated empty-key entries become lists, and terminal values become
/// strings. A block that holds only a list — CCL's `key =\n  = a\n  = b` —
/// becomes the list itself rather than a map with an empty-string key.
pub fn to_dynamic(doc: Document) -> dynamic.Dynamic {
  value_to_dynamic(to_value(doc))
}

fn value_to_dynamic(value: Value) -> dynamic.Dynamic {
  case value {
    StringValue(text) -> dynamic.string(text)
    ListValue(items) -> dynamic.list(list.map(items, value_to_dynamic))
    ObjectValue([#("", ListValue(items))]) ->
      dynamic.list(list.map(items, value_to_dynamic))
    ObjectValue(pairs) ->
      pairs
      |> list.map(fn(pair) {
        #(dynamic.string(pair.0), value_to_dynamic(pair.1))
      })
      |> dynamic.properties
  }
}

fn from_internal_model(m: types.Model) -> Model {
  let types.Model(children) = m
  Model(
    children
    |> dict.to_list
    |> list.sort(fn(a, b) { string.compare(a.0, b.0) })
    |> list.map(fn(pair) { #(pair.0, from_internal_model(pair.1)) }),
  )
}

fn to_dict(doc: Document) -> Dict(String, types.CCLValue) {
  document_pairs(doc)
  |> list.map(fn(pair) { #(pair.0, to_internal_value(pair.1)) })
  |> dict.from_list
}

fn to_internal_value(value: Value) -> types.CCLValue {
  case value {
    StringValue(text) -> types.CclString(text)
    ListValue(items) -> types.CclList(list.map(items, to_internal_value))
    ObjectValue(pairs) ->
      types.CclObject(
        pairs
        |> list.map(fn(pair) { #(pair.0, to_internal_value(pair.1)) })
        |> dict.from_list,
      )
  }
}

// --- Building values from entries ------------------------------------------

// The ordered projection of a document. `ccl/hierarchy` produces the same
// shape over a `Dict`, which cannot promise an order; this walk keeps every
// object's keys in first-occurrence order so `to_value` and `to_string` agree.
fn document_pairs(doc: Document) -> List(#(String, Value)) {
  build_pairs(doc.entries, doc.options)
}

fn build_pairs(
  entries: List(types.Entry),
  options: Options,
) -> List(#(String, Value)) {
  list.fold(entries, [], fn(acc, entry) {
    insert_pair(acc, entry.key, resolve_value(entry.value, options), options)
  })
}

// Only a multi-line value containing an `=` is structurally nested. A
// single-line value is terminal even when it contains an `=`, because that `=`
// is content rather than a delimiter.
fn resolve_value(raw: String, options: Options) -> Value {
  case parser.is_nested_value(raw) {
    False -> StringValue(raw)
    True ->
      case parser.parse_value_with(raw, options.parse) {
        Ok([]) -> StringValue(raw)
        Ok(nested) -> ObjectValue(build_pairs(nested, options))
        Error(_) -> StringValue(raw)
      }
  }
}

fn insert_pair(
  pairs: List(#(String, Value)),
  key: String,
  value: Value,
  options: Options,
) -> List(#(String, Value)) {
  case key {
    // An empty key is a list item, and collects into a list from the first
    // occurrence rather than only on the second.
    "" ->
      case list.key_find(pairs, "") {
        Error(_) -> list.append(pairs, [#("", ListValue([value]))])
        Ok(ListValue(items)) ->
          replace_pair(
            pairs,
            "",
            ListValue(sort_items(list.append(items, [value]), options)),
          )
        Ok(existing) ->
          replace_pair(
            pairs,
            "",
            ListValue(sort_items([existing, value], options)),
          )
      }
    _ ->
      case list.key_find(pairs, key) {
        Error(_) -> list.append(pairs, [#(key, value)])
        Ok(existing) ->
          replace_pair(pairs, key, merge_values(existing, value, options))
      }
  }
}

// Merge a repeated key in place, so the key keeps its first-occurrence
// position. Two blocks merge recursively; anything else accumulates a list.
fn merge_values(existing: Value, new: Value, options: Options) -> Value {
  case existing, new {
    ObjectValue(a), ObjectValue(b) -> ObjectValue(merge_pairs(a, b, options))
    ListValue(items), _ ->
      ListValue(sort_items(list.append(items, [new]), options))
    _, _ -> ListValue(sort_items([existing, new], options))
  }
}

fn merge_pairs(
  a: List(#(String, Value)),
  b: List(#(String, Value)),
  options: Options,
) -> List(#(String, Value)) {
  list.fold(b, a, fn(acc, pair) {
    let #(key, value) = pair
    case list.key_find(acc, key) {
      Error(_) -> list.append(acc, [#(key, value)])
      Ok(existing) ->
        replace_pair(acc, key, merge_values(existing, value, options))
    }
  })
}

fn replace_pair(
  pairs: List(#(String, Value)),
  key: String,
  value: Value,
) -> List(#(String, Value)) {
  list.map(pairs, fn(pair) {
    case pair.0 == key {
      True -> #(key, value)
      False -> pair
    }
  })
}

// Lexicographic order mirrors the OCaml reference, which derives lists from
// the model's map keys — an empty item is an empty key and vanishes, so it is
// dropped here. Insertion order keeps empty items (see
// `list_with_whitespace_*` in the test data for both expectations).
fn sort_items(items: List(Value), options: Options) -> List(Value) {
  case options.build.array_order {
    types.LexicographicOrder ->
      items
      |> list.filter(fn(item) { item != StringValue("") })
      |> list.sort(fn(a, b) { string.compare(sort_key(a), sort_key(b)) })
    _ -> items
  }
}

fn sort_key(value: Value) -> String {
  case value {
    StringValue(text) -> text
    _ -> ""
  }
}

// --- Reading ---------------------------------------------------------------

/// Read a CCL value at a key path.
///
/// An empty path returns the whole document as an `ObjectValue`. Use `get`
/// instead of the typed `get_*` helpers when you need to inspect nested blocks
/// or lists.
///
/// A path segment that is a non-negative decimal indexes into a list, either a
/// `ListValue` directly or the list held under an enclosing block's empty key,
/// so `get(doc, ["ports", "0"])` reads the first item of `ports =\n  = 80`.
///
/// ```gleam
/// let assert Ok(doc) = ccl.parse("server =\n  host = localhost\n")
/// ccl.get(doc, ["server"])
/// // -> Ok(ccl.ObjectValue([#("host", ccl.StringValue("localhost"))]))
/// ```
pub fn get(doc: Document, key: List(String)) -> Result(Value, GetError) {
  navigate(to_value(doc), key, key)
}

/// Read a value nested inside a `Value`.
///
/// Mirrors `get`, but operates on a `Value` already obtained from `get`, so
/// nested data can be read without re-walking from the document root. Errors
/// report the path relative to the supplied value.
pub fn value_get(value: Value, key: List(String)) -> Result(Value, GetError) {
  navigate(value, key, key)
}

fn navigate(
  value: Value,
  path: List(String),
  full: List(String),
) -> Result(Value, GetError) {
  case path, value {
    [], _ -> Ok(value)
    [head, ..rest], ObjectValue(pairs) ->
      case list.key_find(pairs, head) {
        Ok(found) -> navigate(found, rest, full)
        // When the key is absent, index the block's own list, so a caller can
        // address a named list as `["ports", "0"]` without naming the empty
        // key.
        Error(_) ->
          case list.key_find(pairs, "") {
            Ok(ListValue(items)) -> navigate_index(items, head, rest, full)
            _ -> Error(KeyNotFound(full))
          }
      }
    [head, ..rest], ListValue(items) -> navigate_index(items, head, rest, full)
    [_, ..], StringValue(_) -> Error(WrongType(full, ExpectedObject))
  }
}

fn navigate_index(
  items: List(Value),
  head: String,
  rest: List(String),
  full: List(String),
) -> Result(Value, GetError) {
  case int.parse(head) {
    Ok(index) if index >= 0 ->
      case list_at(items, index) {
        Ok(found) -> navigate(found, rest, full)
        Error(_) -> Error(KeyNotFound(full))
      }
    _ -> Error(KeyNotFound(full))
  }
}

fn list_at(items: List(Value), index: Int) -> Result(Value, Nil) {
  case items, index {
    [], _ -> Error(Nil)
    [first, ..], 0 -> Ok(first)
    [_, ..rest], _ -> list_at(rest, index - 1)
  }
}

/// Read a terminal string value at a key path.
pub fn get_string(
  doc: Document,
  key: List(String),
) -> Result(String, GetError) {
  use value <- result.try(get(doc, key))
  case value {
    StringValue(text) -> Ok(text)
    _ -> Error(WrongType(key, ExpectedString))
  }
}

/// Read a terminal value at a key path and parse it as an integer.
pub fn get_int(doc: Document, key: List(String)) -> Result(Int, GetError) {
  use text <- result.try(get_string(doc, key))
  parse_int(text)
  |> result.replace_error(WrongType(key, ExpectedInt))
}

/// Read a terminal value at a key path and parse it as a boolean.
///
/// The document's `Booleans` option controls which strings match;
/// `BooleanStrict` (the default) accepts only `true` and `false`,
/// case-insensitively.
pub fn get_bool(doc: Document, key: List(String)) -> Result(Bool, GetError) {
  use text <- result.try(get_string(doc, key))
  parse_bool(text, doc.options)
  |> result.replace_error(WrongType(key, ExpectedBool))
}

/// Read a terminal value at a key path and parse it as a float.
///
/// An integer literal reads as a float, so `2` yields `2.0`.
pub fn get_float(doc: Document, key: List(String)) -> Result(Float, GetError) {
  use text <- result.try(get_string(doc, key))
  parse_float(text)
  |> result.replace_error(WrongType(key, ExpectedFloat))
}

/// Read a list of terminal strings at a key path.
///
/// This reads both a bare list and CCL's usual named-list shape, where the
/// items live under the empty key of a nested block:
///
/// ```gleam
/// let assert Ok(doc) = ccl.parse("ports =\n  = 80\n  = 443\n")
/// ccl.get_list(doc, ["ports"])
/// // -> Ok(["80", "443"])
/// ```
///
/// A non-list value is a `WrongType` error unless the document was parsed with
/// `with_list_coercion(CoercionEnabled)`, which reads it as a single item.
pub fn get_list(
  doc: Document,
  key: List(String),
) -> Result(List(String), GetError) {
  use values <- result.try(get_values(doc, key))
  strings_of(values, key)
}

/// Read a list of values at a key path, keeping nested items intact.
///
/// This accepts the same list shapes as `get_list`.
pub fn get_values(
  doc: Document,
  key: List(String),
) -> Result(List(Value), GetError) {
  use value <- result.try(get(doc, key))
  values_of(value, doc.options, key)
}

/// Read the keys of the block at a key path, in source order.
///
/// An empty path returns the document's top-level keys.
///
/// ```gleam
/// let assert Ok(doc) = ccl.parse("server =\n  host = localhost\n  port = 8080\n")
/// ccl.keys(doc, ["server"])
/// // -> Ok(["host", "port"])
/// ```
pub fn keys(
  doc: Document,
  key: List(String),
) -> Result(List(String), GetError) {
  use value <- result.try(get(doc, key))
  case value {
    ObjectValue(pairs) -> Ok(list.map(pairs, fn(pair) { pair.0 }))
    _ -> Error(WrongType(key, ExpectedObject))
  }
}

/// Read a string from a `Value`.
///
/// Mirrors `get_string`, but operates on a `Value` already obtained from
/// `get`. On a type mismatch the error reports an empty key path, since a bare
/// `Value` has no path context.
pub fn as_string(value: Value) -> Result(String, GetError) {
  case value {
    StringValue(text) -> Ok(text)
    _ -> Error(WrongType([], ExpectedString))
  }
}

/// Read an integer from a `Value`. See `as_string` for the error convention.
pub fn as_int(value: Value) -> Result(Int, GetError) {
  use text <- result.try(as_string(value))
  parse_int(text)
  |> result.replace_error(WrongType([], ExpectedInt))
}

/// Read a boolean from a `Value`, accepting only `true` and `false`.
///
/// Use `as_bool_with` to apply a document's `Booleans` option. See `as_string`
/// for the error convention.
pub fn as_bool(value: Value) -> Result(Bool, GetError) {
  as_bool_with(value, default_options())
}

/// Read a boolean from a `Value` using the given options.
pub fn as_bool_with(value: Value, options: Options) -> Result(Bool, GetError) {
  use text <- result.try(as_string(value))
  parse_bool(text, options)
  |> result.replace_error(WrongType([], ExpectedBool))
}

/// Read a float from a `Value`. See `as_string` for the error convention.
pub fn as_float(value: Value) -> Result(Float, GetError) {
  use text <- result.try(as_string(value))
  parse_float(text)
  |> result.replace_error(WrongType([], ExpectedFloat))
}

/// Read a list of terminal strings from a `Value`, without list coercion.
///
/// Use `as_list_with` to apply a document's `ListCoercion` option. See
/// `as_string` for the error convention.
pub fn as_list(value: Value) -> Result(List(String), GetError) {
  as_list_with(value, default_options())
}

/// Read a list of terminal strings from a `Value` using the given options.
pub fn as_list_with(
  value: Value,
  options: Options,
) -> Result(List(String), GetError) {
  use values <- result.try(as_values_with(value, options))
  strings_of(values, [])
}

/// Read a list of values from a `Value`, without list coercion.
pub fn as_values(value: Value) -> Result(List(Value), GetError) {
  as_values_with(value, default_options())
}

/// Read a list of values from a `Value` using the given options.
pub fn as_values_with(
  value: Value,
  options: Options,
) -> Result(List(Value), GetError) {
  values_of(value, options, [])
}

/// Read a block's entries from a `Value`, in source order.
///
/// See `as_string` for the error convention.
pub fn as_pairs(value: Value) -> Result(List(#(String, Value)), GetError) {
  case value {
    ObjectValue(pairs) -> Ok(pairs)
    _ -> Error(WrongType([], ExpectedObject))
  }
}

fn values_of(
  value: Value,
  options: Options,
  key: List(String),
) -> Result(List(Value), GetError) {
  case value {
    ListValue(items) -> Ok(items)
    // CCL writes a named list as a block whose items sit under the empty key.
    ObjectValue(pairs) ->
      case list.key_find(pairs, "") {
        Ok(ListValue(items)) -> Ok(items)
        _ -> Error(WrongType(key, ExpectedList))
      }
    StringValue(text) ->
      case options.access.list_coercion {
        types.CoercionEnabled -> Ok([StringValue(text)])
        _ -> Error(WrongType(key, ExpectedList))
      }
  }
}

fn strings_of(
  values: List(Value),
  key: List(String),
) -> Result(List(String), GetError) {
  list.try_map(values, fn(item) {
    case item {
      StringValue(text) -> Ok(text)
      _ -> Error(WrongType(key, ExpectedString))
    }
  })
}

fn parse_int(text: String) -> Result(Int, Nil) {
  int.parse(text)
}

fn parse_float(text: String) -> Result(Float, Nil) {
  case float.parse(text) {
    Ok(number) -> Ok(number)
    Error(_) -> result.map(int.parse(text), int.to_float)
  }
}

fn parse_bool(text: String, options: Options) -> Result(Bool, Nil) {
  case options.access.boolean_parsing, string.lowercase(text) {
    types.BooleanLenient, "true" | types.BooleanLenient, "yes" -> Ok(True)
    types.BooleanLenient, "on" | types.BooleanLenient, "1" -> Ok(True)
    types.BooleanLenient, "false" | types.BooleanLenient, "no" -> Ok(False)
    types.BooleanLenient, "off" | types.BooleanLenient, "0" -> Ok(False)
    types.BooleanLenient, _ -> Error(Nil)
    _, "true" -> Ok(True)
    _, "false" -> Ok(False)
    _, _ -> Error(Nil)
  }
}

// --- Editing ---------------------------------------------------------------

/// Set a terminal string value at a key path, creating intermediate blocks as
/// needed.
///
/// The value may not contain a newline; use `set_value` with an `ObjectValue`
/// or `ListValue` for multi-line data.
///
/// ```gleam
/// let assert Ok(doc) = ccl.parse("server =\n  host = localhost\n")
/// let assert Ok(updated) = ccl.set_string(doc, ["server", "host"], "example.com")
/// ccl.to_string(updated)
/// // -> "server =\n  host = example.com\n"
/// ```
pub fn set_string(
  doc: Document,
  key: List(String),
  value: String,
) -> Result(Document, EditError) {
  set_value(doc, key, StringValue(value))
}

/// Set an integer value at a key path.
pub fn set_int(
  doc: Document,
  key: List(String),
  value: Int,
) -> Result(Document, EditError) {
  set_value(doc, key, StringValue(int.to_string(value)))
}

/// Set a boolean value at a key path, written as `true` or `false`.
pub fn set_bool(
  doc: Document,
  key: List(String),
  value: Bool,
) -> Result(Document, EditError) {
  let text = case value {
    True -> "true"
    False -> "false"
  }
  set_value(doc, key, StringValue(text))
}

/// Set a float value at a key path.
pub fn set_float(
  doc: Document,
  key: List(String),
  value: Float,
) -> Result(Document, EditError) {
  set_value(doc, key, StringValue(float.to_string(value)))
}

/// Set a list of terminal strings at a key path, written as CCL's named-list
/// shape.
///
/// ```gleam
/// let assert Ok(doc) = ccl.set_list(ccl.new(), ["ports"], ["80", "443"])
/// ccl.to_string(doc)
/// // -> "ports =\n  = 80\n  = 443\n"
/// ```
pub fn set_list(
  doc: Document,
  key: List(String),
  values: List(String),
) -> Result(Document, EditError) {
  set_value(doc, key, ListValue(list.map(values, StringValue)))
}

/// Set a nested block at a key path from an ordered list of entries.
pub fn set_object(
  doc: Document,
  key: List(String),
  pairs: List(#(String, Value)),
) -> Result(Document, EditError) {
  set_value(doc, key, ObjectValue(pairs))
}

/// Set any `Value` at a key path, creating intermediate blocks as needed.
///
/// This writes nested values with two-space indentation relative to their
/// parent. It replaces an existing key in place, so the key keeps its
/// position and the comments around it.
pub fn set_value(
  doc: Document,
  key: List(String),
  value: Value,
) -> Result(Document, EditError) {
  use _ <- result.try(validate_path(key))
  use _ <- result.try(validate_value(value))
  use entries <- result.map(set_in_entries(doc.entries, key, value, 0, doc, []))
  edited(doc, entries)
}

/// Append an item to the list at a key path, creating the list if the key does
/// not exist yet.
///
/// ```gleam
/// let assert Ok(doc) = ccl.parse("ports =\n  = 80\n")
/// let assert Ok(updated) =
///   ccl.append_list_item(doc, ["ports"], ccl.StringValue("443"))
/// ccl.to_string(updated)
/// // -> "ports =\n  = 80\n  = 443\n"
/// ```
pub fn append_list_item(
  doc: Document,
  key: List(String),
  value: Value,
) -> Result(Document, EditError) {
  use _ <- result.try(validate_path(key))
  use _ <- result.try(validate_value(value))
  let existing = case get(doc, key) {
    Ok(found) -> values_of(found, doc.options, key) |> result.unwrap([])
    Error(_) -> []
  }
  set_value(doc, key, ListValue(list.append(existing, [value])))
}

/// Remove the value at a key path.
///
/// Removing a key that appears more than once removes every occurrence.
/// Removing the last entry of a nested block leaves the block's key in place
/// with an empty value.
pub fn remove(doc: Document, key: List(String)) -> Result(Document, EditError) {
  use _ <- result.try(validate_path(key))
  use entries <- result.map(remove_in_entries(doc.entries, key, doc, []))
  edited(doc, entries)
}

/// Insert a comment line immediately before the entry at a key path.
///
/// CCL writes comments as `/= text`. The text may not contain a newline; call
/// this once per line for a multi-line comment.
///
/// ```gleam
/// let assert Ok(doc) = ccl.parse("port = 8080\n")
/// let assert Ok(updated) =
///   ccl.insert_comment_before(doc, ["port"], "the listening port")
/// ccl.to_string(updated)
/// // -> "/= the listening port\nport = 8080\n"
/// ```
pub fn insert_comment_before(
  doc: Document,
  key: List(String),
  text: String,
) -> Result(Document, EditError) {
  use _ <- result.try(validate_path(key))
  case string.contains(text, "\n") {
    True -> Error(InvalidCommentText)
    False -> {
      use entries <- result.map(
        comment_in_entries(doc.entries, key, text, doc, []),
      )
      edited(doc, entries)
    }
  }
}

// Replace a document's entries and drop the cached source, so the next
// `to_string` re-emits from the edited entries. Every edit routes through
// here; leaving the cache to each mutator risks silently emitting pre-edit
// text.
fn edited(doc: Document, entries: List(types.Entry)) -> Document {
  Document(..doc, entries: entries, original_source: None)
}

fn validate_path(key: List(String)) -> Result(Nil, EditError) {
  case key {
    [] -> Error(EmptyKeyPath)
    _ -> list.try_each(key, validate_segment)
  }
}

// Reject any segment the parser would not read back as the same key: an empty
// segment is CCL's list-item marker, `=` would split the line elsewhere, and
// surrounding whitespace is trimmed away on the next parse.
fn validate_segment(segment: String) -> Result(Nil, EditError) {
  case
    segment == "",
    string.contains(segment, "\n"),
    string.contains(segment, "="),
    string.trim(segment) != segment
  {
    False, False, False, False -> Ok(Nil)
    _, _, _, _ -> Error(InvalidKeySegment(segment))
  }
}

fn validate_value(value: Value) -> Result(Nil, EditError) {
  case value {
    StringValue(text) ->
      case string.contains(text, "\n") {
        True -> Error(InvalidValue)
        False -> Ok(Nil)
      }
    ListValue(items) -> list.try_each(items, validate_value)
    ObjectValue(pairs) ->
      list.try_each(pairs, fn(pair) {
        // An empty key inside a block is CCL's list-item marker, written as
        // `= value`, so this permits it even though paths reject it.
        use _ <- result.try(case pair.0 {
          "" -> Ok(Nil)
          segment -> validate_segment(segment)
        })
        validate_value(pair.1)
      })
  }
}

fn set_in_entries(
  entries: List(types.Entry),
  path: List(String),
  value: Value,
  indent: Int,
  doc: Document,
  visited: List(String),
) -> Result(List(types.Entry), EditError) {
  case path {
    [] -> Error(EmptyKeyPath)
    [key] -> {
      let raw = value_to_raw(value, indent)
      case list.any(entries, fn(entry) { entry.key == key }) {
        True ->
          Ok(
            list.map(entries, fn(entry) {
              case entry.key == key {
                True -> types.Entry(key: key, value: raw)
                False -> entry
              }
            }),
          )
        False -> Ok(list.append(entries, [types.Entry(key: key, value: raw)]))
      }
    }
    [key, ..rest] -> {
      let here = list.append(visited, [key])
      case list.key_find(entry_pairs(entries), key) {
        // The key is missing: build the whole remaining path as a fresh block.
        Error(_) -> {
          use nested <- result.map(set_in_entries(
            [],
            rest,
            value,
            indent + 2,
            doc,
            here,
          ))
          list.append(entries, [
            types.Entry(key: key, value: nested_raw(nested, indent + 2)),
          ])
        }
        Ok(raw) ->
          case parser.is_nested_value(raw), raw {
            // An empty value is an empty block, so descending into it is fine.
            False, "" -> {
              use nested <- result.map(set_in_entries(
                [],
                rest,
                value,
                indent + 2,
                doc,
                here,
              ))
              replace_entry(entries, key, nested_raw(nested, indent + 2))
            }
            // Descending would have to discard an existing terminal value.
            False, _ -> Error(KeyConflict(here))
            True, _ -> {
              let child_indent = nested_indent(raw, indent + 2)
              use existing <- result.try(
                parser.parse_value_with(raw, doc.options.parse)
                |> result.replace_error(KeyConflict(here)),
              )
              use nested <- result.map(set_in_entries(
                existing,
                rest,
                value,
                child_indent,
                doc,
                here,
              ))
              replace_entry(entries, key, nested_raw(nested, child_indent))
            }
          }
      }
    }
  }
}

fn remove_in_entries(
  entries: List(types.Entry),
  path: List(String),
  doc: Document,
  visited: List(String),
) -> Result(List(types.Entry), EditError) {
  case path {
    [] -> Error(EmptyKeyPath)
    [key] -> {
      let kept = list.filter(entries, fn(entry) { entry.key != key })
      case list.length(kept) == list.length(entries) {
        True -> Error(MissingEditKey(list.append(visited, [key])))
        False -> Ok(kept)
      }
    }
    [key, ..rest] -> {
      let here = list.append(visited, [key])
      case list.key_find(entry_pairs(entries), key) {
        Error(_) -> Error(MissingEditKey(here))
        Ok(raw) ->
          case parser.is_nested_value(raw) {
            False -> Error(MissingEditKey(list.append(here, rest)))
            True -> {
              let child_indent = nested_indent(raw, 2)
              use existing <- result.try(
                parser.parse_value_with(raw, doc.options.parse)
                |> result.replace_error(MissingEditKey(here)),
              )
              use nested <- result.map(remove_in_entries(
                existing,
                rest,
                doc,
                here,
              ))
              replace_entry(entries, key, nested_raw(nested, child_indent))
            }
          }
      }
    }
  }
}

fn comment_in_entries(
  entries: List(types.Entry),
  path: List(String),
  text: String,
  doc: Document,
  visited: List(String),
) -> Result(List(types.Entry), EditError) {
  case path {
    [] -> Error(EmptyKeyPath)
    [key] -> {
      case list.any(entries, fn(entry) { entry.key == key }) {
        False -> Error(MissingEditKey(list.append(visited, [key])))
        True ->
          Ok(insert_before_first(
            entries,
            key,
            types.Entry(key: comment_key, value: text),
          ))
      }
    }
    [key, ..rest] -> {
      let here = list.append(visited, [key])
      case list.key_find(entry_pairs(entries), key) {
        Error(_) -> Error(MissingEditKey(here))
        Ok(raw) ->
          case parser.is_nested_value(raw) {
            False -> Error(MissingEditKey(list.append(here, rest)))
            True -> {
              let child_indent = nested_indent(raw, 2)
              use existing <- result.try(
                parser.parse_value_with(raw, doc.options.parse)
                |> result.replace_error(MissingEditKey(here)),
              )
              use nested <- result.map(comment_in_entries(
                existing,
                rest,
                text,
                doc,
                here,
              ))
              replace_entry(entries, key, nested_raw(nested, child_indent))
            }
          }
      }
    }
  }
}

fn insert_before_first(
  entries: List(types.Entry),
  key: String,
  new: types.Entry,
) -> List(types.Entry) {
  case entries {
    [] -> []
    [first, ..rest] ->
      case first.key == key {
        True -> [new, first, ..rest]
        False -> [first, ..insert_before_first(rest, key, new)]
      }
  }
}

fn entry_pairs(entries: List(types.Entry)) -> List(#(String, String)) {
  list.map(entries, fn(entry) { #(entry.key, entry.value) })
}

fn replace_entry(
  entries: List(types.Entry),
  key: String,
  raw: String,
) -> List(types.Entry) {
  case entries {
    [] -> []
    [first, ..rest] ->
      case first.key == key {
        True -> [types.Entry(key: key, value: raw), ..rest]
        False -> [first, ..replace_entry(rest, key, raw)]
      }
  }
}

// --- Rendering -------------------------------------------------------------

// CCL writes a comment as `/= text`, which the parser reads as an entry under
// this key.
const comment_key = "/"

// Render entries as the body of a nested block: a leading newline, then every
// entry at `indent`. A nested value already includes the absolute indentation
// of its own deeper lines, so only this level needs a prefix.
fn nested_raw(entries: List(types.Entry), indent: Int) -> String {
  case entries {
    [] -> ""
    _ -> "\n" <> render_entries(entries, indent)
  }
}

fn render_entries(entries: List(types.Entry), indent: Int) -> String {
  let prefix = string.repeat(" ", indent)
  entries
  |> list.map(fn(entry) { prefix <> entry_text(entry.key, entry.value) })
  |> string.join("\n")
}

// Mirrors `format.print`'s entry layout, with one addition: a comment entry
// writes back as `/= text` rather than `/ = text`, so a comment survives an
// edit in its original spelling.
fn entry_text(key: String, raw: String) -> String {
  case key, raw {
    "", "" -> "="
    "", "\n" <> _ -> "=" <> raw
    "", _ -> "= " <> raw
    _, _ if key == comment_key -> "/= " <> raw
    _, "" -> key <> " ="
    _, "\n" <> _ -> key <> " =" <> raw
    _, _ -> key <> " = " <> raw
  }
}

// Render a `Value` as an entry's raw value text, where `indent` is the
// indentation of the entry's own line. Children sit two spaces deeper.
fn value_to_raw(value: Value, indent: Int) -> String {
  case value {
    StringValue(text) -> text
    ObjectValue([]) -> ""
    ObjectValue(pairs) -> "\n" <> render_pairs(pairs, indent + 2)
    ListValue([]) -> ""
    ListValue(items) -> "\n" <> render_items(items, indent + 2)
  }
}

fn render_pairs(pairs: List(#(String, Value)), indent: Int) -> String {
  let prefix = string.repeat(" ", indent)
  pairs
  |> list.map(fn(pair) {
    prefix <> entry_text(pair.0, value_to_raw(pair.1, indent))
  })
  |> string.join("\n")
}

fn render_items(items: List(Value), indent: Int) -> String {
  let prefix = string.repeat(" ", indent)
  items
  |> list.map(fn(item) { prefix <> entry_text("", value_to_raw(item, indent)) })
  |> string.join("\n")
}

// The indentation an existing nested block's children already use, so an edit
// inside it keeps the document's own layout rather than imposing two spaces.
fn nested_indent(raw: String, fallback: Int) -> Int {
  // A `\r\n` is a single grapheme here, so dropping one covers both endings.
  case string.starts_with(raw, "\r\n"), string.first(raw) {
    True, _ -> parser.detect_baseline(string.drop_start(raw, 1))
    False, Ok("\n") -> parser.detect_baseline(string.drop_start(raw, 1))
    False, _ -> fallback
  }
}
