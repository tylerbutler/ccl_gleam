/// Core CCL types.
///
/// CCL values use a tagged union representation, recommended by the CCL docs
/// for languages that need structure-preserving `print`. This lets us distinguish
/// string values from nested structures, unlike OCaml's uniform `Fix of t KeyMap.t`.
import gleam/dict.{type Dict}

/// A flat key-value entry produced by parsing.
///
/// Key is trimmed of all whitespace (including newlines).
/// Value preserves internal structure (newlines + indentation for nested content).
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
  /// Nested object — value contained `=` and was recursively parsed.
  CclObject(Dict(String, CCLValue))
  /// List — accumulated from multiple empty-key entries.
  CclList(List(CCLValue))
}

/// A parsed CCL configuration. Top-level is always a string-keyed dict.
pub type CCL =
  Dict(String, CCLValue)

// --- Options types for configurable behaviours ---

/// Controls how CRLF line endings are handled during parsing.
pub type LineEndingBehaviour {
  /// Convert all \r\n to \n before parsing (cross-platform default).
  NormalizeToLf
  /// Preserve \r characters exactly as they appear.
  PreserveLiteral
}

/// Controls how tab characters are handled during parsing.
pub type TabBehaviour {
  /// Both spaces and tabs count as whitespace for indentation.
  TabsAsWhitespace
  /// Only spaces count as whitespace; tabs are preserved as content.
  TabsAsContent
}

/// Controls top-level indentation baseline during parsing.
pub type ContinuationBaseline {
  /// Top-level baseline is always N=0 (OCaml reference behaviour).
  IndentStrip
  /// Top-level baseline is detected from first content line.
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

/// Default parse options matching current hardcoded behaviour.
pub fn default_parse_options() -> ParseOptions {
  ParseOptions(
    line_endings: NormalizeToLf,
    tab_handling: TabsAsWhitespace,
    continuation_baseline: IndentStrip,
    delimiter_strategy: DelimiterPreferSpaced,
  )
}

/// Controls which string values are accepted as booleans.
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

/// Default access options matching current hardcoded behaviour.
pub fn default_access_options() -> AccessOptions {
  AccessOptions(boolean_parsing: BooleanStrict, list_coercion: CoercionDisabled)
}

/// Controls the order of list elements during hierarchy building.
pub type ArrayOrder {
  /// Elements appear in source order.
  InsertionOrder
  /// Elements are sorted lexicographically.
  LexicographicOrder
}

/// Options for hierarchy building.
pub type BuildOptions {
  BuildOptions(array_order: ArrayOrder)
}

/// Default build options matching current hardcoded behaviour.
pub fn default_build_options() -> BuildOptions {
  BuildOptions(array_order: InsertionOrder)
}

/// Controls how the `=` delimiter is identified when a line contains multiple `=`.
pub type DelimiterStrategy {
  /// Split on the first `=` character in the line.
  DelimiterFirstEquals
  /// Prefer ` = ` (space-equals-space) as delimiter; fall back to first `=`
  /// if no spaced version exists. This allows keys containing `=` (e.g. URLs
  /// with query parameters) when the "real" delimiter is surrounded by spaces.
  DelimiterPreferSpaced
}
