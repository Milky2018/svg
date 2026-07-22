///|
test "premultiplied half opacity rounds to alpha 128" {
  let solid = PremulColor16::from_color(Color::rgba(20, 40, 60, 255))
  let half = solid.scaled(unit_to_channel16(0.5)).to_color()
  debug_inspect((half.r, half.g, half.b, half.a), content="(20, 40, 60, 128)")
}

///|
test "premultiplied source-over preserves transparent identity" {
  let source = PremulColor16::from_color(Color::rgba(200, 40, 10, 128))
  let transparent = transparent_premul16()
  inspect(source.source_over(transparent) == source, content="true")
  inspect(transparent.source_over(source) == source, content="true")
}

///|
test "premultiplied source-over composes fractional alpha" {
  let backdrop = PremulColor16::from_color(Color::rgba(0, 0, 255, 128))
  let source = PremulColor16::from_color(Color::rgba(255, 0, 0, 128))
  let result = source.source_over(backdrop).to_color()
  debug_inspect(
    (result.r, result.g, result.b, result.a),
    content="(170, 0, 85, 192)",
  )
}

///|
test "working-space conversion round trips opaque sRGB bytes" {
  for value in [0, 1, 12, 64, 128, 192, 254, 255] {
    let source = PremulColor16::from_color(Color::rgba(value, 80, 210, 255))
    let round_trip = source
      .convert_space(SRGB, LinearRGB)
      .convert_space(LinearRGB, SRGB)
      .to_color()
    inspect(
      (round_trip.r - value).abs() <= 1 &&
      (round_trip.g - 80).abs() <= 1 &&
      (round_trip.b - 210).abs() <= 1 &&
      round_trip.a == 255,
      content="true",
    )
  }
}

///|
test "surface region uses device coordinates" {
  let surface = RenderSurface::new(10, 20, 3, 2, SRGB)
  let color = PremulColor16::from_color(Color::rgba(1, 2, 3, 255))
  surface.set_device(11, 21, color)
  inspect(surface.get_device(11, 21) == color, content="true")
  inspect(surface.get_device(1, 1) == transparent_premul16(), content="true")
}

///|
test "surface pool clears and relocates reused storage" {
  let pool = RenderSurfacePool::new(max_surfaces=1)
  let first = pool.acquire(0, 0, 2, 2, SRGB)
  first.set_device(0, 0, PremulColor16::from_color(Color::black()))
  pool.release(first)
  let reused = pool.acquire(5, 7, 2, 2, SRGB)
  debug_inspect((reused.origin_x, reused.origin_y), content="(5, 7)")
  inspect(reused.get_device(5, 7) == transparent_premul16(), content="true")
}
