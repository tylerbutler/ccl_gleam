/// CCL Codegen CLI — generates decoder functions from Gleam type definitions.
///
/// Usage:
///   gleam run -- generate <file.gleam> <TypeName>
import argv
import ccl_codegen/gen
import gleam/io
import simplifile

pub fn main() {
  case argv.load().arguments {
    ["generate", file_path, type_name] ->
      case simplifile.read(file_path) {
        Ok(source) ->
          case gen.generate_decoder_for(source, type_name) {
            Ok(decoder_code) -> {
              io.println("// Generated decoder for " <> type_name)
              io.println(decoder_code)
            }
            Error(e) -> io.println_error("Error: " <> e)
          }
        Error(_) ->
          io.println_error("Error: Could not read file: " <> file_path)
      }
    _ -> io.println_error("Usage: ccl_codegen generate <file.gleam> <TypeName>")
  }
}
