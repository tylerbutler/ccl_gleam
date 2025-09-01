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

  parse_lines(string.split(input, "\n"))
}

fn parse_lines(lines: List(String)) -> Result(List(Entry), ParseError) {
  parse_loop(lines, 1, None, [])
}

fn parse_loop(
  lines: List(String),
  line_no: Int,
  current: Option(#(String, List(String))),
  acc: List(Entry),
) -> Result(List(Entry), ParseError) {
  case list.first(lines) {
    Error(_) ->
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
    Ok(line) -> {
      let tail = list.drop(lines, 1)
      case as_key_line(line) {
        Some(#(key, value_fragment)) -> {
          let acc2 = case current {
            None -> acc
            Some(#(k, vlines_rev)) -> [
              Entry(k, join_and_trim_value_lines(vlines_rev)),
              ..acc
            ]
          }
          let first_value_line =
            rstrip_whitespace(lstrip_spaces(value_fragment))
          let vlines_rev = case string.length(first_value_line) == 0 {
            True -> []
            False -> [first_value_line]
          }
          parse_loop(tail, line_no + 1, Some(#(key, vlines_rev)), acc2)
        }
        None ->
          case current {
            None ->
              case string.length(string.trim(line)) == 0 {
                True -> parse_loop(tail, line_no + 1, current, acc)
                // Skip empty lines
                False ->
                  Error(ParseError(
                    line_no,
                    "Unexpected line without equals sign: '" <> line <> "'",
                  ))
              }
            Some(#(k, vlines_rev)) -> {
              let trimmed = rstrip_whitespace(lstrip_spaces(line))
              let vlines_rev2 = [trimmed, ..vlines_rev]
              parse_loop(tail, line_no + 1, Some(#(k, vlines_rev2)), acc)
            }
          }
      }
    }
  }
}

fn as_key_line(line: String) -> Option(#(String, String)) {
  case string.split_once(line, "=") {
    Ok(#(left, right)) -> {
      let key = strip_key_whitespace(left)
      // Allow empty keys for list representation
      Some(#(key, right))
    }
    Error(_) -> None
  }
}

fn strip_key_whitespace(s: String) -> String {
  s |> lstrip_spaces_tabs |> rstrip_spaces_tabs
}

fn rstrip_whitespace(s: String) -> String {
  rstrip_while(s, fn(c) { c == " " || c == "\t" })
}

fn lstrip_spaces(s: String) -> String {
  lstrip_while(s, fn(c) { c == " " })
}

fn lstrip_spaces_tabs(s: String) -> String {
  lstrip_while(s, fn(c) { c == " " || c == "\t" })
}

fn rstrip_spaces_tabs(s: String) -> String {
  rstrip_while(s, fn(c) { c == " " || c == "\t" })
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
  rstrip_all_whitespace(out)
}

fn rstrip_all_whitespace(s: String) -> String {
  rstrip_while(s, fn(c) { c == " " || c == "\t" || c == "\n" || c == "\r" })
}
