import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

pub type Entry {
  Entry(key: String, value: String)
}

pub type ParseError {
  ParseError(line: Int, reason: String)
}

pub fn parse(text: String) -> Result(List(Entry), ParseError) {
  let input =
    text
    |> string.replace("\r\n", "\n")
    |> string.replace("\r", "\n")

  // Handle truly empty input
  case string.length(string.trim(text)) == 0 && string.length(text) == 0 {
    True -> Ok([])
    False -> {
      // Handle whitespace-only input as error
      case string.length(string.trim(text)) == 0 {
        True -> Error(ParseError(1, "Input contains only whitespace"))
        False -> parse_with_indentation(string.split(input, "\n"))
      }
    }
  }
}

fn parse_with_indentation(lines: List(String)) -> Result(List(Entry), ParseError) {
  case find_first_key_line(lines, 1) {
    Error(err) -> Error(err)
    Ok(#(first_line, _)) -> {
      let base_indent = count_leading_spaces(first_line)
      parse_lines_with_base_indent(lines, base_indent, 1, None, [])
    }
  }
}

fn find_first_key_line(
  lines: List(String),
  line_no: Int,
) -> Result(#(String, Int), ParseError) {
  case lines {
    [] -> Error(ParseError(line_no, "No key-value pairs found"))
    [line, ..rest] -> {
      case is_empty_line(line) {
        True -> find_first_key_line(rest, line_no + 1)
        False ->
          case string.contains(line, "=") {
            True -> Ok(#(line, line_no))
            False ->
              Error(ParseError(
                line_no,
                "First non-empty line must contain a key-value pair with '='",
              ))
          }
      }
    }
  }
}

fn parse_lines_with_base_indent(
  lines: List(String),
  base_indent: Int,
  line_no: Int,
  current: Option(#(String, List(String))),
  acc: List(Entry),
) -> Result(List(Entry), ParseError) {
  case lines {
    [] ->
      case current {
        None -> Ok(list.reverse(acc))
        Some(#(k, vlines_rev)) ->
          Ok(
            list.reverse([
              Entry(k, join_and_trim_value_lines(vlines_rev)),
              ..acc
            ]),
          )
      }
    [line, ..rest] -> {
      case is_empty_line(line) {
        True ->
          case current {
            None ->
              parse_lines_with_base_indent(
                rest,
                base_indent,
                line_no + 1,
                current,
                acc,
              )
            Some(#(k, vlines_rev)) -> {
              let vlines_rev2 = ["", ..vlines_rev]
              parse_lines_with_base_indent(
                rest,
                base_indent,
                line_no + 1,
                Some(#(k, vlines_rev2)),
                acc,
              )
            }
          }
        False -> {
          let line_indent = count_leading_spaces(line)
          case line_indent > base_indent {
            True -> {
              case current {
                None ->
                  Error(ParseError(
                    line_no,
                    "Continuation line found without preceding key-value pair",
                  ))
                Some(#(k, vlines_rev)) -> {
                  let continuation_value = rstrip_whitespace(line)
                  let vlines_rev2 = [continuation_value, ..vlines_rev]
                  parse_lines_with_base_indent(
                    rest,
                    base_indent,
                    line_no + 1,
                    Some(#(k, vlines_rev2)),
                    acc,
                  )
                }
              }
            }
            False -> {
              case string.contains(line, "=") {
                True -> {
                  let acc2 = case current {
                    None -> acc
                    Some(#(k, vlines_rev)) -> [
                      Entry(k, join_and_trim_value_lines(vlines_rev)),
                      ..acc
                    ]
                  }
                  case string.split_once(line, "=") {
                    Ok(#(key_part, value_part)) -> {
                      let key = string.trim(key_part)
                      let value_line = trim_value_line(value_part)
                      let vlines_rev = case string.length(value_line) == 0 {
                        True -> [""]
                        False -> [value_line]
                      }
                      parse_lines_with_base_indent(
                        rest,
                        base_indent,
                        line_no + 1,
                        Some(#(key, vlines_rev)),
                        acc2,
                      )
                    }
                    Error(_) ->
                      Error(ParseError(line_no, "Invalid key-value line"))
                  }
                }
                False -> {
                  case current {
                    None ->
                      Error(ParseError(
                        line_no,
                        "Non-continuation line without equals sign",
                      ))
                    Some(#(k, vlines_rev)) -> {
                      let continuation_value = rstrip_whitespace(line)
                      let vlines_rev2 = [continuation_value, ..vlines_rev]
                      parse_lines_with_base_indent(
                        rest,
                        base_indent,
                        line_no + 1,
                        Some(#(k, vlines_rev2)),
                        acc,
                      )
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}

fn is_empty_line(line: String) -> Bool {
  string.length(string.trim(line)) == 0
}


fn count_leading_spaces(line: String) -> Int {
  count_leading_spaces_helper(string.to_graphemes(line), 0)
}

fn count_leading_spaces_helper(graphemes: List(String), count: Int) -> Int {
  case graphemes {
    [] -> count
    [" ", ..rest] -> count_leading_spaces_helper(rest, count + 1)
    _ -> count
  }
}

fn trim_value_line(line: String) -> String {
  line
  |> lstrip_spaces
  |> rstrip_whitespace
}

fn lstrip_spaces(s: String) -> String {
  lstrip_while(s, fn(c) { c == " " })
}

fn rstrip_whitespace(s: String) -> String {
  rstrip_while(s, fn(c) { c == " " || c == "\t" || c == "\n" || c == "\r" })
}

fn lstrip_while(s: String, keep: fn(String) -> Bool) -> String {
  lstrip_while_helper(string.to_graphemes(s), keep)
}

fn lstrip_while_helper(gs: List(String), keep: fn(String) -> Bool) -> String {
  case gs {
    [] -> ""
    [g, ..rest] ->
      case keep(g) {
        True -> lstrip_while_helper(rest, keep)
        False -> string.join(gs, "")
      }
  }
}

fn rstrip_while(s: String, keep: fn(String) -> Bool) -> String {
  let rev = list.reverse(string.to_graphemes(s))
  let kept_rev = rstrip_while_helper(rev, keep)
  string.join(list.reverse(kept_rev), "")
}

fn rstrip_while_helper(
  gs: List(String),
  keep: fn(String) -> Bool,
) -> List(String) {
  case gs {
    [] -> []
    [g, ..rest] ->
      case keep(g) {
        True -> rstrip_while_helper(rest, keep)
        False -> gs
      }
  }
}

fn join_and_trim_value_lines(vlines_rev: List(String)) -> String {
  let vlines = list.reverse(vlines_rev)
  let out = string.join(vlines, "\n")
  out
  |> lstrip_spaces
  |> rstrip_whitespace
}
