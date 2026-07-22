///|
test "transform_identity" {
  let t = Transform::identity()
  let (x, y) = t.apply(10.0, 20.0)
  inspect(x, content="10")
  inspect(y, content="20")
}

///|
test "transform_translate" {
  let t = Transform::translate(5.0, 10.0)
  let (x, y) = t.apply(10.0, 20.0)
  inspect(x, content="15")
  inspect(y, content="30")
}

///|
test "transform_scale" {
  let t = Transform::scale(2.0, 3.0)
  let (x, y) = t.apply(10.0, 20.0)
  inspect(x, content="20")
  inspect(y, content="60")
}

///|
test "transform_multiply" {
  let t1 = Transform::translate(10.0, 0.0)
  let t2 = Transform::scale(2.0, 2.0)
  let t = t1.multiply(t2) // First scale, then translate
  let (x, y) = t.apply(5.0, 5.0)
  // Scale: (5, 5) -> (10, 10)
  // Translate: (10, 10) -> (20, 10)
  inspect(x, content="20")
  inspect(y, content="10")
}
