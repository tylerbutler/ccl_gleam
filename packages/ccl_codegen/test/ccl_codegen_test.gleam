import ccl_codegen/gen.{
  BoolType, CustomType, FieldDef, FloatType, IntType, ListType, OptionType,
  StringType, TypeDef,
}
import startest
import startest/expect

pub fn main() {
  startest.run(startest.default_config())
}

// --- parse_field_type ---

pub fn parse_string_type_test() {
  gen.parse_field_type("String")
  |> expect.to_equal(Ok(StringType))
}

pub fn parse_int_type_test() {
  gen.parse_field_type("Int")
  |> expect.to_equal(Ok(IntType))
}

pub fn parse_float_type_test() {
  gen.parse_field_type("Float")
  |> expect.to_equal(Ok(FloatType))
}

pub fn parse_bool_type_test() {
  gen.parse_field_type("Bool")
  |> expect.to_equal(Ok(BoolType))
}

pub fn parse_list_type_test() {
  gen.parse_field_type("List(String)")
  |> expect.to_equal(Ok(ListType(StringType)))
}

pub fn parse_option_type_test() {
  gen.parse_field_type("Option(Int)")
  |> expect.to_equal(Ok(OptionType(IntType)))
}

pub fn parse_nested_list_type_test() {
  gen.parse_field_type("List(List(String))")
  |> expect.to_equal(Ok(ListType(ListType(StringType))))
}

pub fn parse_custom_type_test() {
  gen.parse_field_type("DatabaseConfig")
  |> expect.to_equal(Ok(CustomType("DatabaseConfig")))
}

pub fn parse_whitespace_trimmed_test() {
  gen.parse_field_type("  String  ")
  |> expect.to_equal(Ok(StringType))
}

// --- parse_type_def ---

pub fn parse_single_line_type_test() {
  let source = "pub type Config { Config(host: String, port: Int) }"
  gen.parse_type_def(source)
  |> expect.to_equal(
    Ok(
      TypeDef("Config", "Config", [
        FieldDef("host", StringType),
        FieldDef("port", IntType),
      ]),
    ),
  )
}

pub fn parse_multiline_type_test() {
  let source =
    "pub type Config {
  Config(
    host: String,
    port: Int,
    debug: Bool,
  )
}"
  gen.parse_type_def(source)
  |> expect.to_equal(
    Ok(
      TypeDef("Config", "Config", [
        FieldDef("host", StringType),
        FieldDef("port", IntType),
        FieldDef("debug", BoolType),
      ]),
    ),
  )
}

pub fn parse_type_with_list_field_test() {
  let source = "pub type Config { Config(tags: List(String), count: Int) }"
  gen.parse_type_def(source)
  |> expect.to_equal(
    Ok(
      TypeDef("Config", "Config", [
        FieldDef("tags", ListType(StringType)),
        FieldDef("count", IntType),
      ]),
    ),
  )
}

pub fn parse_type_with_option_field_test() {
  let source = "pub type Config { Config(name: String, bio: Option(String)) }"
  gen.parse_type_def(source)
  |> expect.to_equal(
    Ok(
      TypeDef("Config", "Config", [
        FieldDef("name", StringType),
        FieldDef("bio", OptionType(StringType)),
      ]),
    ),
  )
}

pub fn parse_type_with_custom_field_test() {
  let source = "pub type App { App(db: DatabaseConfig) }"
  gen.parse_type_def(source)
  |> expect.to_equal(
    Ok(TypeDef("App", "App", [FieldDef("db", CustomType("DatabaseConfig"))])),
  )
}

pub fn parse_private_type_test() {
  let source = "type Config { Config(name: String) }"
  gen.parse_type_def(source)
  |> expect.to_equal(
    Ok(TypeDef("Config", "Config", [FieldDef("name", StringType)])),
  )
}

// --- to_snake_case ---

pub fn snake_case_simple_test() {
  gen.to_snake_case("DatabaseConfig")
  |> expect.to_equal("database_config")
}

pub fn snake_case_single_word_test() {
  gen.to_snake_case("Config")
  |> expect.to_equal("config")
}

pub fn snake_case_all_caps_letters_test() {
  gen.to_snake_case("HTTPClient")
  |> expect.to_equal("h_t_t_p_client")
}

pub fn snake_case_already_lower_test() {
  gen.to_snake_case("config")
  |> expect.to_equal("config")
}

// --- generate_decoder ---

pub fn generate_basic_decoder_test() {
  let source = "pub type Config { Config(host: String, port: Int) }"
  let expected =
    "pub fn config_decoder() {
  use host <- decode.field(\"host\", decode.string)
  use port <- decode.field(\"port\", decode.int)
  decode.success(Config(host:, port:))
}"
  gen.generate_decoder(source)
  |> expect.to_equal(Ok(expected))
}

pub fn generate_decoder_with_bool_test() {
  let source =
    "pub type Settings { Settings(name: String, debug: Bool, rate: Float) }"
  let expected =
    "pub fn settings_decoder() {
  use name <- decode.field(\"name\", decode.string)
  use debug <- decode.field(\"debug\", decode.bool)
  use rate <- decode.field(\"rate\", decode.float)
  decode.success(Settings(name:, debug:, rate:))
}"
  gen.generate_decoder(source)
  |> expect.to_equal(Ok(expected))
}

pub fn generate_decoder_with_list_test() {
  let source = "pub type Tags { Tags(items: List(String)) }"
  let expected =
    "pub fn tags_decoder() {
  use items <- decode.field(\"items\", decode.list(decode.string))
  decode.success(Tags(items:))
}"
  gen.generate_decoder(source)
  |> expect.to_equal(Ok(expected))
}

pub fn generate_decoder_with_option_test() {
  let source = "pub type User { User(name: String, bio: Option(String)) }"
  let expected =
    "pub fn user_decoder() {
  use name <- decode.field(\"name\", decode.string)
  use bio <- decode.optional_field(\"bio\", decode.string, option.None)
  decode.success(User(name:, bio: option.Some(bio)))
}"
  gen.generate_decoder(source)
  |> expect.to_equal(Ok(expected))
}

pub fn generate_decoder_with_custom_type_test() {
  let source = "pub type App { App(db: DatabaseConfig, name: String) }"
  let expected =
    "pub fn app_decoder() {
  use db <- decode.field(\"db\", database_config_decoder())
  use name <- decode.field(\"name\", decode.string)
  decode.success(App(db:, name:))
}"
  gen.generate_decoder(source)
  |> expect.to_equal(Ok(expected))
}

// --- generate_decoder_for (multi-type source) ---

pub fn generate_decoder_for_extracts_correct_type_test() {
  let source =
    "pub type Foo {
  Foo(x: Int)
}

pub type Bar {
  Bar(name: String, count: Int)
}

pub type Baz {
  Baz(ok: Bool)
}"
  let expected =
    "pub fn bar_decoder() {
  use name <- decode.field(\"name\", decode.string)
  use count <- decode.field(\"count\", decode.int)
  decode.success(Bar(name:, count:))
}"
  gen.generate_decoder_for(source, "Bar")
  |> expect.to_equal(Ok(expected))
}

pub fn generate_decoder_for_missing_type_test() {
  let source = "pub type Foo { Foo(x: Int) }"
  gen.generate_decoder_for(source, "Missing")
  |> expect.to_equal(Error("Type not found in source"))
}

// --- emit_decoder from TypeDef ---

pub fn emit_decoder_from_typedef_test() {
  let type_def =
    TypeDef("Config", "Config", [
      FieldDef("host", StringType),
      FieldDef("port", IntType),
    ])
  let expected =
    "pub fn config_decoder() {
  use host <- decode.field(\"host\", decode.string)
  use port <- decode.field(\"port\", decode.int)
  decode.success(Config(host:, port:))
}"
  gen.emit_decoder(type_def)
  |> expect.to_equal(expected)
}
