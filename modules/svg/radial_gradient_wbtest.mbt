// ============================================================================
// Marker Tests
// ============================================================================

///|
test "radial gradient new" {
  let grad = RadialGradient::new(0.5, 0.5, 0.5, [
    { offset: 0.0, color: Color::rgb(255, 255, 255), },
    { offset: 1.0, color: Color::rgb(0, 0, 0), },
  ])
  inspect(grad.cx, content="0.5")
  inspect(grad.cy, content="0.5")
  inspect(grad.r, content="0.5")
  inspect(grad.stops.length(), content="2")
}

///|
test "paint radial grad" {
  let grad = RadialGradient::new(0.5, 0.5, 0.5, [
    { offset: 0.0, color: Color::rgb(255, 0, 0), },
    { offset: 1.0, color: Color::rgb(0, 0, 255), },
  ])
  let paint : Paint = RadialGrad(grad)
  match paint {
    RadialGrad(g) => inspect(g.cx, content="0.5")
    _ => panic()
  }
}
