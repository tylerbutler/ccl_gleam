import gleeunit/should
import render/typed

// --- int_to_string ---

pub fn int_to_string_positive_test() {
  typed.int_to_string(42)
  |> should.equal("42")
}

pub fn int_to_string_zero_test() {
  typed.int_to_string(0)
  |> should.equal("0")
}

pub fn int_to_string_negative_test() {
  typed.int_to_string(-7)
  |> should.equal("-7")
}

// --- float_to_string ---

pub fn float_to_string_whole_test() {
  typed.float_to_string(3.0)
  |> should.equal("3.0")
}

pub fn float_to_string_decimal_test() {
  typed.float_to_string(1.5)
  |> should.equal("1.5")
}

pub fn float_to_string_negative_test() {
  typed.float_to_string(-2.5)
  |> should.equal("-2.5")
}

// --- bool_to_string ---

pub fn bool_to_string_true_test() {
  typed.bool_to_string(True)
  |> should.equal("true")
}

pub fn bool_to_string_false_test() {
  typed.bool_to_string(False)
  |> should.equal("false")
}
