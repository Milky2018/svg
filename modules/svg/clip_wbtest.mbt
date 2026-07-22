// ============================================================================
// ClipPath Tests
// ============================================================================

///|
test "render with clipPath" {
  let svg = "<svg><defs><clipPath id=\"clip\"><rect x=\"0\" y=\"0\" width=\"10\" height=\"10\"/></clipPath></defs><rect x=\"0\" y=\"0\" width=\"20\" height=\"20\" fill=\"red\" clip-path=\"url(#clip)\"/></svg>"
  match parse_svg_document(svg) {
    Some(doc) => {
      let drawn_pixels : Array[(Int, Int, Color)] = []
      let setter : ColorSink = {
        set: (x, y, color) => drawn_pixels.push((x, y, color)),
      }
      let ctx = RenderState::new(setter, 20, 20)
      doc.render(ctx)
      // Clipped to 10x10
      inspect(drawn_pixels.length(), content="100")
    }
    None => panic()
  }
}

///|
test "render with clipPath objectBoundingBox" {
  let svg = "<svg><defs><clipPath id=\"clip\" clipPathUnits=\"objectBoundingBox\"><rect x=\"0\" y=\"0\" width=\"0.5\" height=\"1\"/></clipPath></defs><rect x=\"0\" y=\"0\" width=\"20\" height=\"10\" fill=\"red\" clip-path=\"url(#clip)\"/></svg>"
  match parse_svg_document(svg) {
    Some(doc) => {
      let drawn_pixels : Array[(Int, Int, Color)] = []
      let setter : ColorSink = {
        set: (x, y, color) => drawn_pixels.push((x, y, color)),
      }
      let ctx = RenderState::new(setter, 20, 10)
      doc.render(ctx)
      // Half width (10x10)
      inspect(drawn_pixels.length(), content="100")
    }
    None => panic()
  }
}
