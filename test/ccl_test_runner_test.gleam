import startest
import startest/expect

pub fn main() {
  startest.run(startest.default_config())
}

// Standalone tests (auto-discovered by startest via `_test` suffix)

pub fn hello_world_test() {
  let name = "Joe"
  let greeting = "Hello, " <> name <> "!"
  greeting
  |> expect.to_equal("Hello, Joe!")
}
