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
