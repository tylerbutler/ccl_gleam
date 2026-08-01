import ccl/parser
import ccl/types.{type Entry, type ParseOptions}
import gleam/result
import gleam/string

@internal
pub fn parse(
  raw_value: String,
  parse_options: ParseOptions,
) -> Result(List(Entry), Nil) {
  case
    string.starts_with(raw_value, "\r\n") || string.starts_with(raw_value, "\n")
  {
    True ->
      parser.parse_value_with(raw_value, parse_options)
      |> result.map_error(fn(_) { Nil })
    False -> Error(Nil)
  }
}
