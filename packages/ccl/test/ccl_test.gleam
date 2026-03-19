import startest
import startest/expect

import ccl/parser
import ccl/types.{Entry}

pub fn main() {
  startest.run(startest.default_config())
}
pub fn parse_basic_key_value_test() {
  let input = "key = value"
  let result = parser.parse(input)
  result
  |> expect.to_equal(Ok([Entry(key: "key", value: "value")]))
}

pub fn parse_empty_input_test() {
  let result = parser.parse("")
  result
  |> expect.to_equal(Ok([]))
}
