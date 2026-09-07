///|
test "linear gradient color interpolation" {
  // Create a simple horizontal gradient (left=red, right=blue)
  let grad = LinearGradient::{
    x1: 0.0,
    y1: 0.0,
    x2: 1.0,
    y2: 0.0,
    stops: [
      { offset: 0.0, color: Color::rgb(255, 0, 0), },
      { offset: 1.0, color: Color::rgb(0, 0, 255), },
    ],
    spread_method: Pad,
    units: ObjectBoundingBox,
    transform: Transform::identity(),
  }
  // Test color at start (t=0)
  let c0 = grad.color_at(0.0)
  inspect(c0.r, content="255")
  inspect(c0.b, content="0")
  // Test color at end (t=1)
  let c1 = grad.color_at(1.0)
  inspect(c1.r, content="0")
  inspect(c1.b, content="255")
  // Test color at middle (t=0.5)
  let c05 = grad.color_at(0.5)
  inspect(c05.r, content="128")
  inspect(c05.b, content="128")
}

///|
test "linear gradient rendering" {
  // Create a rect with gradient fill
  let grad = LinearGradient::{
    x1: 0.0,
    y1: 0.0,
    x2: 1.0,
    y2: 0.0,
    stops: [
      { offset: 0.0, color: Color::rgb(255, 0, 0), },
      { offset: 1.0, color: Color::rgb(0, 0, 255), },
    ],
    spread_method: Pad,
    units: ObjectBoundingBox,
    transform: Transform::identity(),
  }
  let rect_node = rect("grad-rect", 0.0, 0.0, 100.0, 50.0)
  rect_node.fill = LinearGrad(grad)
  let drawn_pixels : Array[(Int, Int, Color)] = []
  let setter : ColorSink = {
    set: (x, y, color) => drawn_pixels.push((x, y, color)),
  }
  let ctx = RenderState::new(setter, 100, 50)
  SVGDocument::new(rect_node).render(ctx)
  // Should have drawn pixels (100 * 50 = 5000)
  inspect(drawn_pixels.length(), content="5000")
  // Pixel centers lie just inside the gradient endpoints.
  let left = drawn_pixels[0]
  inspect(left.2.r, content="254")
  inspect(left.2.b, content="1")
  // Check right edge is nearly blue (last row, x=99)
  let right = drawn_pixels.iter().find_first(p => p.0 == 99 && p.1 == 0)
  match right {
    Some((_, _, c)) => {
      inspect(c.r, content="1")
      inspect(c.b, content="254")
    }
    None => panic()
  }
}
