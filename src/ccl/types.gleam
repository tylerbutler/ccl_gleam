/// Core CCL types.
///
/// CCL values use a tagged union, as the CCL docs recommend for languages
/// that need a structure-preserving `print`. The tags keep string values
/// separate from nested structures, unlike OCaml's uniform `Fix of t KeyMap.t`.
import gleam/dict.{type Dict}

/// A flat key-value entry produced by parsing.
///
/// The parser trims all whitespace, including newlines, from the key.
/// The value keeps its internal structure: newlines and indentation for
/// nested content.
///
/// Special keys:
/// - Empty string `""` → list item (from `= value` syntax)
/// - `"/"` → comment entry (from `/= text` syntax)
pub type Entry {
  Entry(key: String, value: String)
}

/// A CCL value — tagged union for structure-preserving operations.
pub type CCLValue {
  /// Terminal value — no `=` in content, fixed point reached.
  CclString(String)
  /// Nested object — the value contains `=` and expands recursively.
  CclObject(Dict(String, CCLValue))
  /// List — built from repeated empty-key entries.
  CclList(List(CCLValue))
}

/// A parsed CCL configuration. Top-level is always a string-keyed dict.
pub type CCL =
  Dict(String, CCLValue)

/// Canonical recursive map-of-maps model, mirroring OCaml's `Fix of t KeyMap.t`.
///
/// `build_model` produces this shape: terminal string values become keys
/// pointing to `Model(empty)`; nested structures are recursive. There are no
/// strings or lists at the value level — leaves are always `Model(empty)`.
/// The model is order-agnostic; ordering choices belong to typed projections.
pub type Model {
  Model(Dict(String, Model))
}

// --- Options types for configurable behaviours ---

/// Controls how the parser treats CRLF line endings.
pub type LineEndingBehaviour {
  /// Convert all \r\n to \n before parsing (cross-platform default).
  NormalizeToLf
  /// Preserve \r characters exactly as they appear.
  PreserveLiteral
}

/// Controls how the parser treats tab characters.
pub type TabBehaviour {
  /// Both spaces and tabs count as whitespace for indentation.
  TabsAsWhitespace
  /// Only spaces count as whitespace; tabs stay in the value as content.
  TabsAsContent
}

/// Controls the top-level indentation baseline during parsing.
pub type ContinuationBaseline {
  /// The top-level baseline is always N=0 (OCaml reference behaviour).
  IndentStrip
  /// The parser detects the top-level baseline from the first content line.
  IndentPreserve
}

/// Options for parsing behaviour.
pub type ParseOptions {
  ParseOptions(
    line_endings: LineEndingBehaviour,
    tab_handling: TabBehaviour,
    continuation_baseline: ContinuationBaseline,
    delimiter_strategy: DelimiterStrategy,
  )
}

/// The default parse options.
pub fn default_parse_options() -> ParseOptions {
  ParseOptions(
    line_endings: NormalizeToLf,
    tab_handling: TabsAsWhitespace,
    continuation_baseline: IndentStrip,
    delimiter_strategy: DelimiterPreferSpaced,
  )
}

/// Controls which strings the boolean readers accept.
pub type BooleanParsing {
  /// Only true/false (case-insensitive).
  BooleanStrict
  /// Also accepts yes/no, on/off, 1/0 (case-insensitive).
  BooleanLenient
}

/// Controls how get_list behaves on non-list values.
pub type ListCoercion {
  /// get_list errors on non-list values.
  CoercionDisabled
  /// get_list wraps single values in a list.
  CoercionEnabled
}

/// Options for typed access functions.
pub type AccessOptions {
  AccessOptions(boolean_parsing: BooleanParsing, list_coercion: ListCoercion)
}

/// The default access options.
pub fn default_access_options() -> AccessOptions {
  AccessOptions(boolean_parsing: BooleanStrict, list_coercion: CoercionDisabled)
}

/// Controls the order of list elements during hierarchy building.
pub type ArrayOrder {
  /// Elements appear in source order.
  InsertionOrder
  /// The builder sorts elements lexicographically.
  LexicographicOrder
}

/// Options for hierarchy building.
pub type BuildOptions {
  BuildOptions(array_order: ArrayOrder)
}

/// The default build options.
pub fn default_build_options() -> BuildOptions {
  BuildOptions(array_order: InsertionOrder)
}

/// Controls how the parser finds the `=` delimiter when a line contains more
/// than one `=`.
pub type DelimiterStrategy {
  /// Split on the first `=` character in the line.
  DelimiterFirstEquals
  /// Prefer ` = ` (space-equals-space) as the delimiter; if no spaced form
  /// exists, split on the first `=`. This permits keys that contain `=`
  /// (e.g. URLs with query parameters) when spaces surround the real delimiter.
  DelimiterPreferSpaced
}
