/// CCL Codegen CLI — generates decoder functions from Gleam type definitions.
///
/// Usage:
///   gleam run -- generate <file.gleam> <TypeName>
import argv
import ccl_codegen/gen
import gleam/io
import glint
import simplifile

pub fn main() {
  glint.new()
  |> glint.with_name("ccl_codegen")
  |> glint.pretty_help(glint.default_pretty_help())
  |> glint.add(at: ["generate"], do: generate_command())
  |> glint.run(argv.load().arguments)
}

fn generate_command() -> glint.Command(Nil) {
  use <- glint.command_help(
    "Generate a CCL decoder from a Gleam type definition",
  )
  use _flags, args, _ <- glint.command()
  case args {
    [file_path, type_name] -> {
      case simplifile.read(file_path) {
        Ok(source) -> {
          case gen.generate_decoder_for(source, type_name) {
            Ok(decoder_code) -> {
              io.println("// Generated decoder for " <> type_name)
              io.println(decoder_code)
            }
            Error(e) -> {
              io.println_error("Error: " <> e)
            }
          }
        }
        Error(_) -> {
          io.println_error("Error: Could not read file: " <> file_path)
        }
      }
    }
    _ -> {
      io.println_error("Usage: ccl_codegen generate <file.gleam> <TypeName>")
    }
  }
}
