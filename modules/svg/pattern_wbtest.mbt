// ============================================================================
// Pattern Tests
// ============================================================================

///|
test "pattern creation" {
  let content = [rect("tile", 0.0, 0.0, 10.0, 10.0)]
  let pattern = Pattern::new("dots", 20.0, 20.0, content)
  inspect(pattern.width, content="20")
  inspect(pattern.height, content="20")
}

///|
test "pattern fill basic" {
  let svg = "<svg><pattern id=\"p\" width=\"1\" height=\"1\"><rect width=\"10\" height=\"10\" fill=\"green\"/></pattern><rect width=\"10\" height=\"10\" fill=\"url(#p)\"/></svg>"
  match parse_svg_document(svg) {
    Some(doc) => {
      let image = Image::new(12, 12)
      let setter : ColorSink = {
        set: (x, y, color) => image.set_pixel(x, y, color),
      }
      let ctx = RenderState::new(setter, 12, 12)
      doc.render(ctx)
      let px = image.get_pixel(5, 5)
      inspect(px.g, content="128")
    }
    None => panic()
  }
}

///|
test "render currentColor fill" {
  let svg = "<svg><g color=\"#008000\"><rect width=\"10\" height=\"10\" fill=\"currentColor\"/></g></svg>"
  match parse_svg_document(svg) {
    Some(doc) => {
      let image = Image::new(12, 12)
      let setter : ColorSink = {
        set: (x, y, color) => image.set_pixel(x, y, color),
      }
      let ctx = RenderState::new(setter, 12, 12)
      doc.render(ctx)
      let px = image.get_pixel(5, 5)
      inspect(px.g, content="128")
    }
    None => panic()
  }
}
