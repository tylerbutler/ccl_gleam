/// Debug script to test JSON parsing
import gleam/io
import gleam/list
import gleam/string
import simplifile
import test_loader

pub fn main() {
  let dir = "../ccl-test-data/generated_tests"

  case simplifile.read_directory(dir) {
    Ok(files) -> {
      let json_files =
        files
        |> list.filter(fn(f) { string.ends_with(f, ".json") })
        |> list.sort(string.compare)

      io.println(
        "Found " <> string.inspect(list.length(json_files)) <> " JSON files",
      )

      list.each(json_files, fn(file) {
        let path = dir <> "/" <> file
        io.println("\nTesting: " <> file)

        case simplifile.read(path) {
          Ok(content) -> {
            case test_loader.parse_test_suite(content) {
              Ok(suite) -> {
                io.println(
                  "  OK - "
                  <> string.inspect(list.length(suite.tests))
                  <> " tests",
                )
              }
              Error(e) -> {
                io.println("  FAIL - " <> e)
              }
            }
          }
          Error(e) -> {
            io.println("  READ ERROR - " <> string.inspect(e))
          }
        }
      })
    }
    Error(e) -> {
      io.println("Error reading directory: " <> string.inspect(e))
    }
  }
}
