import atto
import atto/ops
import atto/text
import ccl/parser
import ccl/types.{type Entry, type ParseOptions}
import gleam/result
import gleam/string

@internal
pub fn parse(
  raw_value: String,
  parse_options: ParseOptions,
) -> Result(List(Entry), Nil) {
  use nested_source <- result.try(
    atto.run(nested_value_source(), text.new(raw_value), Nil)
    |> result.map_error(fn(_) { Nil }),
  )

  parser.parse_value_with(nested_source, parse_options)
  |> result.map_error(fn(_) { Nil })
}

fn nested_value_source() -> atto.Parser(String, String, String, Nil, Nil) {
  use first <- atto.do(ops.choice([atto.token("\r\n"), atto.token("\n")]))
  use rest <- atto.do(ops.many(atto.any()))
  use _ <- atto.do(atto.eof())

  atto.pure(first <> string.concat(rest))
}
