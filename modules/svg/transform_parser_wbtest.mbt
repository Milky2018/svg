///|
test "parse_transform translate" {
  let t = parse_transform("translate(10, 20)")
  let (x, y) = t.apply(0.0, 0.0)
  inspect(x, content="10")
  inspect(y, content="20")
}

///|
test "parse_transform scale" {
  let t = parse_transform("scale(2)")
  let (x, y) = t.apply(5.0, 3.0)
  inspect(x, content="10")
  inspect(y, content="6")
}

///|
test "parse_transform rotate" {
  let t = parse_transform("rotate(90)")
  let (x, y) = t.apply(1.0, 0.0)
  // After 90 degree rotation, (1,0) -> (0,1)
  inspect((x * 10.0).round() / 10.0, content="0")
  inspect((y * 10.0).round() / 10.0, content="1")
}

///|
test "parse_transform skewX" {
  let t = parse_transform("skewX(45)")
  let (x, y) = t.apply(0.0, 2.0)
  inspect((x * 10.0).round() / 10.0, content="2")
  inspect(y, content="2")
}

///|
test "parse_transform skewY" {
  let t = parse_transform("skewY(45)")
  let (x, y) = t.apply(2.0, 0.0)
  inspect(x, content="2")
  inspect((y * 10.0).round() / 10.0, content="2")
}

///|
test "parse_transform names are case-sensitive" {
  let t = parse_transform("skewx(45) skewy(45)")
  let (x, y) = t.apply(2.0, 3.0)
  inspect(x, content="2")
  inspect(y, content="3")
}

///|
test "parse_transform combined" {
  let t = parse_transform("translate(10, 0) scale(2)")
  let (x, y) = t.apply(5.0, 0.0)
  // translate(10,0) then scale(2): (5,0) -> (15,0) -> (30, 0)
  inspect(x, content="20")
  inspect(y, content="0")
}

///|
test "parse_transform matrix" {
  let t = parse_transform("matrix(1, 0, 0, 1, 100, 200)")
  let (x, y) = t.apply(0.0, 0.0)
  inspect(x, content="100")
  inspect(y, content="200")
}
