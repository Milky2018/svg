///|
test "Color constructors" {
  let c = Color::rgb(10, 20, 30)
  inspect(c.r, content="10")
  inspect(c.g, content="20")
  inspect(c.b, content="30")
  inspect(c.a, content="1")
  let c2 = Color::rgba(40, 50, 60, 0.5)
  inspect(c2.a, content="0.5")
  let t = Color::transparent()
  assert_true(t.is_transparent())
  let k = Color::black()
  assert_true(k.is_opaque())
  inspect(k.r, content="0")
  let w = Color::white()
  inspect(w.r, content="255")
  inspect(w.g, content="255")
  inspect(w.b, content="255")
}

///|
test "Color::is_transparent and is_opaque" {
  assert_true(Color::transparent().is_transparent())
  assert_false(Color::black().is_transparent())
  assert_true(Color::black().is_opaque())
  assert_false(Color::rgba(0, 0, 0, 0.5).is_opaque())
}

///|
test "Color::to_hex" {
  inspect(Color::rgb(255, 128, 0).to_hex(), content="#ff8000")
  inspect(Color::rgb(0, 0, 0).to_hex(), content="#000000")
  // Alpha 0.5 * 255 = 127.5 -> 127 (truncation)
  inspect(Color::rgba(255, 0, 0, 0.5).to_hex(), content="#ff00007f")
}

///|
test "Color::to_rgba_string" {
  inspect(Color::rgb(10, 20, 30).to_rgba_string(), content="rgb(10, 20, 30)")
  inspect(
    Color::rgba(10, 20, 30, 0.25).to_rgba_string(),
    content="rgba(10, 20, 30, 0.25)",
  )
}

///|
test "Color equality" {
  let a = Color::rgb(1, 2, 3)
  let b = Color::rgb(1, 2, 3)
  let c = Color::rgb(1, 2, 4)
  assert_true(a == b)
  assert_false(a == c)
}

///|
test "Color Show outputs rgb format" {
  inspect(Color::rgb(255, 0, 0), content="rgb(255, 0, 0)")
}

///|
test "BackgroundImage Show" {
  inspect(BackgroundImage::None, content="None")
  let gradient : LinearGradient = {
    angle_deg: 90.0,
    stops: [
      { color: Color::rgb(255, 0, 0), position: 0.0 },
      { color: Color::rgb(0, 0, 255), position: 1.0 },
    ],
  }
  let bg = BackgroundImage::Gradient(gradient)
  let s = bg.to_string()
  assert_true(s.has_prefix("Gradient("))
  assert_true(s.contains("angle_deg: 90"))
  assert_true(s.contains("stops: ["))
}

///|
test "GradientStop and LinearGradient Show" {
  let stop : GradientStop = { color: Color::rgb(10, 20, 30), position: 0.5 }
  let s = stop.to_string()
  assert_true(s.contains("color: rgb(10, 20, 30)"))
  assert_true(s.contains("position: 0.5"))
  let g : LinearGradient = { angle_deg: 45.0, stops: [stop] }
  let gs = g.to_string()
  assert_true(gs.contains("angle_deg: 45"))
}
