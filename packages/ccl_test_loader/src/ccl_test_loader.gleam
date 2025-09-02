import gleam/dict
import gleam/json
import gleam/list
import ccl_core.{type CCL, CCL}

/// Convert CCL to JSON
pub fn ccl_to_json(ccl: CCL) -> json.Json {
  ccl_to_json_value(ccl)
}

/// Convert CCL to JSON Value (recursive helper)
fn ccl_to_json_value(ccl: CCL) -> json.Json {
  case ccl {
    CCL(map) -> {
      case dict.size(map) {
        0 -> json.null()
        _ -> {
          let entries = dict.to_list(map)
          json.object(list.map(entries, fn(pair) {
            let #(key, nested_ccl) = pair
            #(key, ccl_to_json_value(nested_ccl))
          }))
        }
      }
    }
  }
}

/// Convert JSON to CCL
pub fn json_to_ccl(_json_value: json.Json) -> Result(CCL, String) {
  // For now, return an error - this requires dynamic decoding
  Error("JSON to CCL conversion not yet implemented")
}

/// Convert CCL to JSON string
pub fn ccl_to_json_string(ccl: CCL) -> String {
  ccl_to_json(ccl) |> json.to_string
}

/// Parse JSON string as CCL
pub fn json_string_to_ccl(_json_string: String) -> Result(CCL, String) {
  // For now, return an error - this requires dynamic decoding
  Error("JSON string to CCL conversion not yet implemented")
}