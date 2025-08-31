import gleam/list
import gleam/result.{Result, Ok, Error}
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

  let lines = string.split(input, "\n")
  parse_lines(lines)
}

fn parse_lines(lines: List(String)) -> Result(List(Entry), ParseError) {
  parse_loop(lines, 1, None, [])
}

fn parse_loop(
  lines: List(String),
  line_no: Int,
  current: Option(#(String, List(String))),  // key, accumulated value lines
  acc: List(Entry),
) -> Result(List(Entry), ParseError) {
  case lines {
    [] ->
      case current {
        None -> Ok(list.reverse(acc))
        Some(#(k, vlines)) ->
          let value = join_and_trim_value_lines(vlines)
          Ok(list.reverse([Entry(k, value), ..acc]))
      }

    [line, ..tail] ->
      case as_key_line(line) {
        Some(#(key, value_fragment)) ->
          if string.length(key) == 0 {
            Error(ParseError(line_no, "Empty key"))
          } else {
            let acc2 =
              case current {
                None -> acc
                Some(#(k, vlines)) ->
                  let value = join_and_trim_value_lines(vlines)
                  [Entry(k, value), ..acc]
              }

            let first_value_line =
              rstrip_whitespace(lstrip_spaces(value_fragment))

            let vlines =
              if string.length(first_value_line) == 0 {
                []
              } else {
                [first_value_line]
              }

            parse_loop(tail, line_no + 1, Some(#(key, vlines)), acc2)
          }

        None ->
          case current {
            None ->
              // Ignore stray lines before first key
              parse_loop(tail, line_no + 1, current, acc)

            Some(#(k, vlines)) ->
              let trimmed =
                rstrip_whitespace(lstrip_spaces(line))
              let vlines2 = [trimmed, ..vlines]
              parse_loop(tail, line_no + 1, Some(#(k, vlines2)), acc)
          }
      }
  }
}

// Detect a key line by the first '=' anywhere in the line.
// The left side, after trimming spaces/tabs, must be non-empty.
fn as_key_line(line: String) -> Option(#(String, String)) {
  case string.index_of(line, "=") {
    Ok(i) ->
      let left = string.slice(line, 0, i)
      let right = string.slice(line, i + 1, string.length(line))
      let key = strip_key_whitespace(left)
      if string.length(key) == 0 {
        None
      } else {
        Some(#(key, right))
      }
    Error(_) -> None
  }
}

// Key trimming: remove spaces and tabs from both ends (Unicode-safe).
fn strip_key_whitespace(s: String) -> String {
  s |> lstrip_spaces_tabs |> rstrip_spaces_tabs
}

// Value leading trim: remove spaces (U+0020) only.
fn lstrip_spaces(s: String) -> String {
  lstrip_while(s, fn(c) { c == " " })
}

// Value trailing trim: remove spaces or tabs (whitespace) at end.
fn rstrip_whitespace(s: String) -> String {
  rstrip_while(s, fn(c) { c == " " || c == "\t" })
}

// Helpers for key trimming
fn lstrip_spaces_tabs(s: String) -> String {
  lstrip_while(s, fn(c) { c == " " || c == "\t" })
}

fn rstrip_spaces_tabs(s: String) -> String {
  rstrip_while(s, fn(c) { c == " " || c == "\t" })
}

// Generic left-strip by predicate over graphemes.
fn lstrip_while(s: String, keep: fn(String) -> Bool) -> String {
  let graphemes = string.graphemes(s)
  let idx = list.find_index(graphemes, fn(g) { !keep(g) })
  case idx {
    None -> ""
    Some(i) -> string.join(list.drop(graphemes, i), "")
  }
}

// Generic right-strip by predicate over graphemes.
fn rstrip_while(s: String, keep: fn(String) -> Bool) -> String {
  let graphemes = string.graphemes(s)
  let rev = list.reverse(graphemes)
  let idx = list.find_index(rev, fn(g) { !keep(g) })
  case idx {
    None -> ""
    Some(i) -> string.join(list.reverse(list.drop(rev, i)), "")
  }
}

// Join accumulated lines in order and apply a final trailing trim.
fn join_and_trim_value_lines(vlines_rev: List(String)) -> String {
  let vlines = list.reverse(vlines_rev)
  let out = string.join(vlines, "\n")
  rstrip_whitespace(out)
}
