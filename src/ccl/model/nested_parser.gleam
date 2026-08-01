import ccl/parser
import ccl/types.{type Entry, type ParseOptions}
import gleam/result

@internal
pub fn parse(
  raw_value: String,
  parse_options: ParseOptions,
) -> Result(List(Entry), Nil) {
  case parser.is_nested_value(raw_value) {
    True ->
      parser.parse_value_with(raw_value, parse_options)
      |> result.map_error(fn(_) { Nil })
    False -> Error(Nil)
  }
}
