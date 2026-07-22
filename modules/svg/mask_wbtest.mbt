// ============================================================================
// Mask Tests
// ============================================================================

///|
test "mask new" {
  let content = [rect("mask-rect", 0.0, 0.0, 100.0, 100.0)]
  let mask = Mask::new("test-mask", content)
  inspect(mask.id, content="test-mask")
  inspect(mask.content.length(), content="1")
  inspect(mask.mask_type, content="Luminance")
}

///|
test "mask with bounds" {
  let content = [circle("mask-circle", 50.0, 50.0, 50.0)]
  let mask = Mask::with_bounds("bounded-mask", content, 0.0, 0.0, 1.0, 1.0)
  inspect(mask.x, content="0")
  inspect(mask.y, content="0")
  inspect(mask.width, content="1")
  inspect(mask.height, content="1")
}

///|
test "render with mask" {
  let svg = "<svg><defs><mask id=\"m\" maskUnits=\"userSpaceOnUse\" maskContentUnits=\"userSpaceOnUse\"><rect x=\"0\" y=\"0\" width=\"10\" height=\"10\" fill=\"white\"/></mask></defs><rect x=\"0\" y=\"0\" width=\"20\" height=\"20\" fill=\"red\" mask=\"url(#m)\"/></svg>"
  match parse_svg_document(svg) {
    Some(doc) => {
      let drawn_pixels : Array[(Int, Int, Color)] = []
      let setter : ColorSink = {
        set: (x, y, color) => drawn_pixels.push((x, y, color)),
      }
      let ctx = RenderState::new(setter, 20, 20)
      doc.render(ctx)
      // Masked to 10x10
      inspect(drawn_pixels.length(), content="100")
    }
    None => panic()
  }
}

///|
test "render with mask objectBoundingBox content" {
  let svg = "<svg><defs><mask id=\"m\" maskContentUnits=\"objectBoundingBox\"><rect x=\"0\" y=\"0\" width=\"0.5\" height=\"1\" fill=\"white\"/></mask></defs><rect x=\"0\" y=\"0\" width=\"20\" height=\"10\" fill=\"red\" mask=\"url(#m)\"/></svg>"
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

///|
test "mask bounds percent values" {
  let svg = "<svg><defs><mask id=\"m\" maskUnits=\"objectBoundingBox\" maskContentUnits=\"objectBoundingBox\" x=\"25%\" y=\"0%\" width=\"50%\" height=\"100%\"><rect x=\"0\" y=\"0\" width=\"1\" height=\"1\" fill=\"white\"/></mask></defs><rect x=\"0\" y=\"0\" width=\"20\" height=\"10\" fill=\"red\" mask=\"url(#m)\"/></svg>"
  match parse_svg_document(svg) {
    Some(doc) => {
      let drawn_pixels : Array[(Int, Int, Color)] = []
      let setter : ColorSink = {
        set: (x, y, color) => drawn_pixels.push((x, y, color)),
      }
      let ctx = RenderState::new(setter, 20, 10)
      doc.render(ctx)
      // 25% offset, 50% width => 10x10 area
      inspect(drawn_pixels.length(), content="100")
    }
    None => panic()
  }
}

///|
test "maskUnits userSpaceOnUse respects viewBox scale" {
  let svg = "<svg viewBox=\"0 0 10 10\"><defs><mask id=\"m\" maskUnits=\"userSpaceOnUse\" maskContentUnits=\"userSpaceOnUse\" x=\"0\" y=\"0\" width=\"5\" height=\"10\"><rect x=\"0\" y=\"0\" width=\"5\" height=\"10\" fill=\"white\"/></mask></defs><rect x=\"0\" y=\"0\" width=\"10\" height=\"10\" fill=\"red\" mask=\"url(#m)\"/></svg>"
  match parse_svg_document(svg) {
    Some(doc) => {
      let drawn_pixels : Array[(Int, Int, Color)] = []
      let setter : ColorSink = {
        set: (x, y, color) => drawn_pixels.push((x, y, color)),
      }
      let ctx = RenderState::new(setter, 20, 20)
      doc.render(ctx)
      // ViewBox scales by 2: mask width 5 -> 10, height 10 -> 20
      inspect(drawn_pixels.length(), content="200")
    }
    None => panic()
  }
}

///|
test "maskUnits userSpaceOnUse with rotation transform" {
  let svg = "<svg><defs><mask id=\"m\" maskUnits=\"userSpaceOnUse\" maskContentUnits=\"userSpaceOnUse\" x=\"0\" y=\"0\" width=\"10\" height=\"5\"><rect x=\"0\" y=\"0\" width=\"10\" height=\"5\" fill=\"white\"/></mask></defs><rect x=\"0\" y=\"0\" width=\"10\" height=\"10\" fill=\"red\" transform=\"rotate(90)\" mask=\"url(#m)\"/></svg>"
  match parse_svg_document(svg) {
    Some(doc) => {
      let drawn_pixels : Array[(Int, Int, Color)] = []
      let setter : ColorSink = {
        set: (x, y, color) => drawn_pixels.push((x, y, color)),
      }
      let ctx = RenderState::new(setter, 30, 30)
      doc.render(ctx)
      let mut min_x = 9999
      let mut max_x = -9999
      for p in drawn_pixels {
        if p.0 < min_x {
          min_x = p.0
        }
        if p.0 > max_x {
          max_x = p.0
        }
      }
      let width = max_x - min_x + 1
      inspect(width >= 4 && width <= 6, content="true")
    }
    None => panic()
  }
}

///|
test "node mask operations" {
  let node = SVGNode::new(
    Rect(x=0.0, y=0.0, width=100.0, height=100.0, rx=0.0, ry=0.0),
  )
  inspect(node.mask_id is None, content="true")
  node.set_mask("my-mask")
  inspect(node.mask_id is None, content="false")
  node.clear_mask()
  inspect(node.mask_id is None, content="true")
}

///|
test "node clip path operations" {
  let node = SVGNode::new(
    Rect(x=0.0, y=0.0, width=100.0, height=100.0, rx=0.0, ry=0.0),
  )
  inspect(node.clip_path_id is None, content="true")
  node.set_clip_path("my-clip")
  inspect(node.clip_path_id is None, content="false")
  node.clear_clip_path()
  inspect(node.clip_path_id is None, content="true")
}

///|
test "mask get bounds object bounding box" {
  let mask = Mask::new("test", [])
  let target : BoundingBox = {
    min_x: 100.0,
    min_y: 100.0,
    max_x: 200.0,
    max_y: 200.0,
  }
  let bounds = mask.get_mask_bounds(target)
  // Default mask is -0.1 to 1.1 relative, so should extend beyond target
  inspect(bounds.min_x < 100.0, content="true")
  inspect(bounds.max_x > 200.0, content="true")
}
