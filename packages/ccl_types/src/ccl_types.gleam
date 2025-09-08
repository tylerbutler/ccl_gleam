import gleam/dict

// === CORE CCL TYPES ===
// These are the fundamental types used across all CCL packages

pub type Entry {
  Entry(key: String, value: String)
}

pub type ParseError {
  ParseError(line: Int, reason: String)  
}

pub type CCL {
  CCL(map: dict.Dict(String, CCL))
}