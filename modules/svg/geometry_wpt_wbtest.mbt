///|
test "wpt rect-01 fill" {
  let svg = "<svg><rect x=\"10\" y=\"10\" width=\"50\" height=\"50\" fill=\"blue\"/></svg>"
  match parse_svg_document(svg) {
    Some(doc) => {
      let image = Image::new(80, 80)
      let setter : ColorSink = {
        set: (x, y, color) => image.set_pixel(x, y, color),
      }
      let ctx = RenderState::new(setter, 80, 80)
      doc.render(ctx)
      inspect(image.get_pixel(9, 9).is_transparent(), content="true")
      inspect(image.get_pixel(10, 10).b, content="255")
      inspect(image.get_pixel(59, 59).b, content="255")
      inspect(image.get_pixel(60, 60).is_transparent(), content="true")
    }
    None => panic()
  }
}

///|
test "wpt rect-02 stroke" {
  let svg = "<svg><rect x=\"10\" y=\"10\" width=\"50\" height=\"50\" fill=\"none\" stroke=\"blue\" stroke-width=\"4\"/></svg>"
  match parse_svg_document(svg) {
    Some(doc) => {
      let image = Image::new(80, 80)
      let setter : ColorSink = {
        set: (x, y, color) => image.set_pixel(x, y, color),
      }
      let ctx = RenderState::new(setter, 80, 80)
      doc.render(ctx)
      inspect(image.get_pixel(15, 15).is_transparent(), content="true")
      inspect(image.get_pixel(10, 10).b, content="255")
      inspect(image.get_pixel(8, 8).b, content="255")
    }
    None => panic()
  }
}

///|
test "wpt rect-03 rounded fill" {
  let svg = "<svg><rect x=\"10\" y=\"10\" width=\"50\" height=\"50\" rx=\"8\" ry=\"8\" fill=\"blue\"/></svg>"
  match parse_svg_document(svg) {
    Some(doc) => {
      let image = Image::new(80, 80)
      let setter : ColorSink = {
        set: (x, y, color) => image.set_pixel(x, y, color),
      }
      let ctx = RenderState::new(setter, 80, 80)
      doc.render(ctx)
      inspect(image.get_pixel(10, 10).is_transparent(), content="true")
      inspect(image.get_pixel(17, 17).b, content="255")
    }
    None => panic()
  }
}

///|
test "wpt rect-04 rounded stroke" {
  let svg = "<svg><rect x=\"10\" y=\"10\" width=\"50\" height=\"50\" rx=\"8\" ry=\"8\" fill=\"none\" stroke=\"blue\" stroke-width=\"4\"/></svg>"
  match parse_svg_document(svg) {
    Some(doc) => {
      let image = Image::new(80, 80)
      let setter : ColorSink = {
        set: (x, y, color) => image.set_pixel(x, y, color),
      }
      let ctx = RenderState::new(setter, 80, 80)
      doc.render(ctx)
      inspect(image.get_pixel(20, 20).is_transparent(), content="true")
      inspect(image.get_pixel(12, 12).b, content="255")
    }
    None => panic()
  }
}

///|
test "wpt rect-05 zero size" {
  let svg = "<svg width=\"100\" height=\"100\"><rect x=\"30\" y=\"50\" width=\"0\" height=\"10\" fill=\"red\" stroke=\"red\" stroke-width=\"4\"/><rect x=\"50\" y=\"50\" width=\"10\" height=\"0\" fill=\"red\" stroke=\"red\" stroke-width=\"4\"/><rect x=\"70\" y=\"50\" width=\"0\" height=\"0\" fill=\"red\" stroke=\"red\" stroke-width=\"4\"/></svg>"
  match parse_svg_document(svg) {
    Some(doc) => {
      let image = Image::new(100, 100)
      let setter : ColorSink = {
        set: (x, y, color) => image.set_pixel(x, y, color),
      }
      let ctx = RenderState::new(setter, 100, 100)
      doc.render(ctx)
      let mut any_drawn = false
      for y in 0..<image.height {
        for x in 0..<image.width {
          if !image.get_pixel(x, y).is_transparent() {
            any_drawn = true
          }
        }
      }
      inspect(any_drawn, content="false")
    }
    None => panic()
  }
}

///|
test "wpt circle-01 r0" {
  let svg = "<svg width=\"100\" height=\"100\"><circle cx=\"50\" cy=\"50\" r=\"0\" fill=\"red\" stroke=\"red\" stroke-width=\"5\"/></svg>"
  match parse_svg_document(svg) {
    Some(doc) => {
      let image = Image::new(100, 100)
      let setter : ColorSink = {
        set: (x, y, color) => image.set_pixel(x, y, color),
      }
      let ctx = RenderState::new(setter, 100, 100)
      doc.render(ctx)
      let mut any_drawn = false
      for y in 0..<image.height {
        for x in 0..<image.width {
          if !image.get_pixel(x, y).is_transparent() {
            any_drawn = true
          }
        }
      }
      inspect(any_drawn, content="false")
    }
    None => panic()
  }
}

///|
test "wpt ellipse-09 zero" {
  let svg = "<svg width=\"100\" height=\"100\"><ellipse cx=\"30\" cy=\"50\" rx=\"0\" ry=\"10\" fill=\"red\" stroke=\"red\" stroke-width=\"5\"/><ellipse cx=\"50\" cy=\"50\" rx=\"10\" ry=\"0\" fill=\"red\" stroke=\"red\" stroke-width=\"5\"/><ellipse cx=\"70\" cy=\"50\" rx=\"0\" ry=\"0\" fill=\"red\" stroke=\"red\" stroke-width=\"5\"/></svg>"
  match parse_svg_document(svg) {
    Some(doc) => {
      let image = Image::new(100, 100)
      let setter : ColorSink = {
        set: (x, y, color) => image.set_pixel(x, y, color),
      }
      let ctx = RenderState::new(setter, 100, 100)
      doc.render(ctx)
      let mut any_drawn = false
      for y in 0..<image.height {
        for x in 0..<image.width {
          if !image.get_pixel(x, y).is_transparent() {
            any_drawn = true
          }
        }
      }
      inspect(any_drawn, content="false")
    }
    None => panic()
  }
}

///|
test "wpt line basic" {
  let svg = "<svg width=\"40\" height=\"40\"><line x1=\"10\" y1=\"10\" x2=\"20\" y2=\"20\" stroke=\"blue\"/></svg>"
  match parse_svg_document(svg) {
    Some(doc) => {
      let image = Image::new(40, 40)
      let setter : ColorSink = {
        set: (x, y, color) => image.set_pixel(x, y, color),
      }
      let ctx = RenderState::new(setter, 40, 40)
      doc.render(ctx)
      inspect(image.get_pixel(10, 10).b, content="255")
      inspect(image.get_pixel(19, 19).b, content="255")
      inspect(image.get_pixel(20, 20).is_transparent(), content="true")
    }
    None => panic()
  }
}

///|
test "wpt linecap butt no extend" {
  let svg = "<svg width=\"40\" height=\"40\"><line x1=\"10\" y1=\"20\" x2=\"30\" y2=\"20\" stroke=\"blue\" stroke-width=\"6\" stroke-linecap=\"butt\"/></svg>"
  match parse_svg_document(svg) {
    Some(doc) => {
      let image = Image::new(40, 40)
      let setter : ColorSink = {
        set: (x, y, color) => image.set_pixel(x, y, color),
      }
      let ctx = RenderState::new(setter, 40, 40)
      doc.render(ctx)
      inspect(image.get_pixel(7, 20).is_transparent(), content="true")
      inspect(image.get_pixel(10, 20).b, content="255")
    }
    None => panic()
  }
}

///|
test "wpt linecap square extends" {
  let svg = "<svg width=\"40\" height=\"40\"><line x1=\"10\" y1=\"20\" x2=\"30\" y2=\"20\" stroke=\"blue\" stroke-width=\"6\" stroke-linecap=\"square\"/></svg>"
  match parse_svg_document(svg) {
    Some(doc) => {
      let image = Image::new(40, 40)
      let setter : ColorSink = {
        set: (x, y, color) => image.set_pixel(x, y, color),
      }
      let ctx = RenderState::new(setter, 40, 40)
      doc.render(ctx)
      inspect(image.get_pixel(7, 20).b, content="255")
      inspect(image.get_pixel(32, 20).b, content="255")
      inspect(image.get_pixel(33, 20).is_transparent(), content="true")
    }
    None => panic()
  }
}

///|
test "wpt linecap round extends" {
  let svg = "<svg width=\"40\" height=\"40\"><line x1=\"10\" y1=\"20\" x2=\"30\" y2=\"20\" stroke=\"blue\" stroke-width=\"6\" stroke-linecap=\"round\"/></svg>"
  match parse_svg_document(svg) {
    Some(doc) => {
      let image = Image::new(40, 40)
      let setter : ColorSink = {
        set: (x, y, color) => image.set_pixel(x, y, color),
      }
      let ctx = RenderState::new(setter, 40, 40)
      doc.render(ctx)
      inspect(image.get_pixel(7, 20).b, content="255")
      inspect(image.get_pixel(32, 20).b, content="255")
      inspect(image.get_pixel(33, 20).is_transparent(), content="true")
    }
    None => panic()
  }
}

///|
test "wpt linejoin miter extends" {
  let svg = "<svg width=\"400\" height=\"400\"><polyline points=\"210,200 230,200 210,201\" fill=\"none\" stroke=\"blue\" stroke-width=\"6\" stroke-linejoin=\"miter\" stroke-miterlimit=\"100\"/></svg>"
  match parse_svg_document(svg) {
    Some(doc) => {
      let image = Image::new(400, 400)
      let setter : ColorSink = {
        set: (x, y, color) => image.set_pixel(x, y, color),
      }
      let ctx = RenderState::new(setter, 400, 400)
      doc.render(ctx)
      let (probe_x, probe_y) = miter_triangle_probe(
        210, 200, 230, 200, 210, 201, 6,
      )
      inspect(image.get_pixel(probe_x, probe_y).b, content="255")
    }
    None => panic()
  }
}

///|
test "wpt linejoin miterlimit bevel" {
  let svg = "<svg width=\"400\" height=\"400\"><polyline points=\"210,200 230,200 210,201\" fill=\"none\" stroke=\"blue\" stroke-width=\"6\" stroke-linejoin=\"miter\" stroke-miterlimit=\"1\"/></svg>"
  match parse_svg_document(svg) {
    Some(doc) => {
      let image = Image::new(400, 400)
      let setter : ColorSink = {
        set: (x, y, color) => image.set_pixel(x, y, color),
      }
      let ctx = RenderState::new(setter, 400, 400)
      doc.render(ctx)
      let (probe_x, probe_y) = miter_triangle_probe(
        210, 200, 230, 200, 210, 201, 6,
      )
      inspect(
        image.get_pixel(probe_x, probe_y).is_transparent(),
        content="true",
      )
    }
    None => panic()
  }
}

///|
test "wpt polyline basic" {
  let svg = "<svg width=\"40\" height=\"40\"><polyline points=\"10,10 20,10 20,20\" fill=\"none\" stroke=\"blue\"/></svg>"
  match parse_svg_document(svg) {
    Some(doc) => {
      let image = Image::new(40, 40)
      let setter : ColorSink = {
        set: (x, y, color) => image.set_pixel(x, y, color),
      }
      let ctx = RenderState::new(setter, 40, 40)
      doc.render(ctx)
      inspect(image.get_pixel(15, 10).b, content="255")
      inspect(image.get_pixel(20, 15).b, content="255")
      inspect(image.get_pixel(15, 15).is_transparent(), content="true")
    }
    None => panic()
  }
}

///|
test "wpt path fill-rule evenodd hole" {
  let svg = "<svg width=\"40\" height=\"40\"><path d=\"M 5 5 L 35 5 L 35 35 L 5 35 Z M 10 10 L 30 10 L 30 30 L 10 30 Z\" fill=\"blue\" fill-rule=\"evenodd\"/></svg>"
  match parse_svg_document(svg) {
    Some(doc) => {
      let image = Image::new(40, 40)
      let setter : ColorSink = {
        set: (x, y, color) => image.set_pixel(x, y, color),
      }
      let ctx = RenderState::new(setter, 40, 40)
      doc.render(ctx)
      inspect(image.get_pixel(6, 6).b, content="255")
      inspect(image.get_pixel(20, 20).is_transparent(), content="true")
    }
    None => panic()
  }
}

///|
test "wpt path fill-rule nonzero solid" {
  let svg = "<svg width=\"40\" height=\"40\"><path d=\"M 5 5 L 35 5 L 35 35 L 5 35 Z M 10 10 L 30 10 L 30 30 L 10 30 Z\" fill=\"blue\" fill-rule=\"nonzero\"/></svg>"
  match parse_svg_document(svg) {
    Some(doc) => {
      let image = Image::new(40, 40)
      let setter : ColorSink = {
        set: (x, y, color) => image.set_pixel(x, y, color),
      }
      let ctx = RenderState::new(setter, 40, 40)
      doc.render(ctx)
      inspect(image.get_pixel(6, 6).b, content="255")
      inspect(image.get_pixel(20, 20).b, content="255")
    }
    None => panic()
  }
}

///|
test "wpt polygon basic fill" {
  let svg = "<svg width=\"40\" height=\"40\"><polygon points=\"10,10 20,10 20,20 10,20\" fill=\"blue\"/></svg>"
  match parse_svg_document(svg) {
    Some(doc) => {
      let image = Image::new(40, 40)
      let setter : ColorSink = {
        set: (x, y, color) => image.set_pixel(x, y, color),
      }
      let ctx = RenderState::new(setter, 40, 40)
      doc.render(ctx)
      inspect(image.get_pixel(15, 15).b, content="255")
      inspect(image.get_pixel(5, 5).is_transparent(), content="true")
    }
    None => panic()
  }
}

///|
test "disabled polyline empty points" {
  let svg = "<svg width=\"40\" height=\"40\"><polyline points=\"\" fill=\"none\" stroke=\"red\"/></svg>"
  match parse_svg_document(svg) {
    Some(doc) => {
      let image = Image::new(40, 40)
      let setter : ColorSink = {
        set: (x, y, color) => image.set_pixel(x, y, color),
      }
      let ctx = RenderState::new(setter, 40, 40)
      doc.render(ctx)
      let mut any_drawn = false
      for y in 0..<image.height {
        for x in 0..<image.width {
          if !image.get_pixel(x, y).is_transparent() {
            any_drawn = true
          }
        }
      }
      inspect(any_drawn, content="false")
    }
    None => panic()
  }
}

///|
test "disabled polyline single point" {
  let svg = "<svg width=\"40\" height=\"40\"><polyline points=\"10,10\" fill=\"none\" stroke=\"red\"/></svg>"
  match parse_svg_document(svg) {
    Some(doc) => {
      let image = Image::new(40, 40)
      let setter : ColorSink = {
        set: (x, y, color) => image.set_pixel(x, y, color),
      }
      let ctx = RenderState::new(setter, 40, 40)
      doc.render(ctx)
      let mut any_drawn = false
      for y in 0..<image.height {
        for x in 0..<image.width {
          if !image.get_pixel(x, y).is_transparent() {
            any_drawn = true
          }
        }
      }
      inspect(any_drawn, content="false")
    }
    None => panic()
  }
}

///|
test "disabled polygon too few points" {
  let svg = "<svg width=\"40\" height=\"40\"><polygon points=\"10,10 20,20\" fill=\"blue\" stroke=\"blue\"/></svg>"
  match parse_svg_document(svg) {
    Some(doc) => {
      let image = Image::new(40, 40)
      let setter : ColorSink = {
        set: (x, y, color) => image.set_pixel(x, y, color),
      }
      let ctx = RenderState::new(setter, 40, 40)
      doc.render(ctx)
      let mut any_drawn = false
      for y in 0..<image.height {
        for x in 0..<image.width {
          if !image.get_pixel(x, y).is_transparent() {
            any_drawn = true
          }
        }
      }
      inspect(any_drawn, content="false")
    }
    None => panic()
  }
}

///|
test "polyline stroke width" {
  let svg = "<svg width=\"40\" height=\"40\"><polyline points=\"10,10 30,10\" fill=\"none\" stroke=\"blue\" stroke-width=\"6\"/></svg>"
  match parse_svg_document(svg) {
    Some(doc) => {
      let image = Image::new(40, 40)
      let setter : ColorSink = {
        set: (x, y, color) => image.set_pixel(x, y, color),
      }
      let ctx = RenderState::new(setter, 40, 40)
      doc.render(ctx)
      inspect(image.get_pixel(20, 9).b, content="255")
      inspect(image.get_pixel(20, 11).b, content="255")
    }
    None => panic()
  }
}

///|
test "polygon stroke width" {
  let svg = "<svg width=\"40\" height=\"40\"><polygon points=\"10,10 30,10 30,30 10,30\" fill=\"none\" stroke=\"blue\" stroke-width=\"6\"/></svg>"
  match parse_svg_document(svg) {
    Some(doc) => {
      let image = Image::new(40, 40)
      let setter : ColorSink = {
        set: (x, y, color) => image.set_pixel(x, y, color),
      }
      let ctx = RenderState::new(setter, 40, 40)
      doc.render(ctx)
      inspect(image.get_pixel(20, 7).b, content="255")
      inspect(image.get_pixel(20, 20).is_transparent(), content="true")
    }
    None => panic()
  }
}

///|
test "disabled circle negative r" {
  let svg = "<svg width=\"100\" height=\"100\"><circle cx=\"50\" cy=\"50\" r=\"-10\" fill=\"red\" stroke=\"red\" stroke-width=\"5\"/></svg>"
  match parse_svg_document(svg) {
    Some(doc) => {
      let image = Image::new(100, 100)
      let setter : ColorSink = {
        set: (x, y, color) => image.set_pixel(x, y, color),
      }
      let ctx = RenderState::new(setter, 100, 100)
      doc.render(ctx)
      let mut any_drawn = false
      for y in 0..<image.height {
        for x in 0..<image.width {
          if !image.get_pixel(x, y).is_transparent() {
            any_drawn = true
          }
        }
      }
      inspect(any_drawn, content="false")
    }
    None => panic()
  }
}

///|
test "disabled circle style negative r" {
  let svg = "<svg width=\"100\" height=\"100\"><circle cx=\"50\" cy=\"50\" style=\"r: -10\" fill=\"red\"/></svg>"
  match parse_svg_document(svg) {
    Some(doc) => {
      let image = Image::new(100, 100)
      let setter : ColorSink = {
        set: (x, y, color) => image.set_pixel(x, y, color),
      }
      let ctx = RenderState::new(setter, 100, 100)
      doc.render(ctx)
      let mut any_drawn = false
      for y in 0..<image.height {
        for x in 0..<image.width {
          if !image.get_pixel(x, y).is_transparent() {
            any_drawn = true
          }
        }
      }
      inspect(any_drawn, content="false")
    }
    None => panic()
  }
}

///|
test "disabled ellipse negative rx" {
  let svg = "<svg width=\"100\" height=\"100\"><ellipse cx=\"50\" cy=\"50\" rx=\"-10\" ry=\"10\" fill=\"red\"/></svg>"
  match parse_svg_document(svg) {
    Some(doc) => {
      let image = Image::new(100, 100)
      let setter : ColorSink = {
        set: (x, y, color) => image.set_pixel(x, y, color),
      }
      let ctx = RenderState::new(setter, 100, 100)
      doc.render(ctx)
      let mut any_drawn = false
      for y in 0..<image.height {
        for x in 0..<image.width {
          if !image.get_pixel(x, y).is_transparent() {
            any_drawn = true
          }
        }
      }
      inspect(any_drawn, content="false")
    }
    None => panic()
  }
}

///|
test "disabled ellipse style auto" {
  let svg = "<svg width=\"100\" height=\"100\"><ellipse cx=\"50\" cy=\"50\" style=\"rx: auto; ry: auto\" fill=\"red\"/></svg>"
  match parse_svg_document(svg) {
    Some(doc) => {
      let image = Image::new(100, 100)
      let setter : ColorSink = {
        set: (x, y, color) => image.set_pixel(x, y, color),
      }
      let ctx = RenderState::new(setter, 100, 100)
      doc.render(ctx)
      let mut any_drawn = false
      for y in 0..<image.height {
        for x in 0..<image.width {
          if !image.get_pixel(x, y).is_transparent() {
            any_drawn = true
          }
        }
      }
      inspect(any_drawn, content="false")
    }
    None => panic()
  }
}

///|
test "render rounded rect fill" {
  let image = Image::new(30, 30)
  let setter : ColorSink = {
    set: (x, y, color) => image.set_pixel(x, y, color),
  }
  let ctx = RenderState::new(setter, 30, 30)
  let node = rect("rounded", 10.0, 10.0, 10.0, 10.0)
  node.shape = Rect(x=10.0, y=10.0, width=10.0, height=10.0, rx=4.0, ry=4.0)
  node.fill = SolidColor(Color::rgb(0, 0, 255))
  SVGDocument::new(node).render(ctx)
  inspect(image.get_pixel(10, 10).is_transparent(), content="true")
  inspect(image.get_pixel(15, 15).is_transparent(), content="false")
}

///|
test "render rect stroke width" {
  let image = Image::new(30, 30)
  let setter : ColorSink = {
    set: (x, y, color) => image.set_pixel(x, y, color),
  }
  let ctx = RenderState::new(setter, 30, 30)
  let node = rect("stroke", 10.0, 10.0, 10.0, 10.0)
  node.fill = None
  node.stroke = {
    ..node.stroke,
    paint: SolidColor(Color::rgb(0, 0, 255)),
    width: 4.0,
  }
  SVGDocument::new(node).render(ctx)
  inspect(image.get_pixel(15, 15).is_transparent(), content="true")
  inspect(image.get_pixel(8, 8).is_transparent(), content="false")
}

///|
test "rect zero size not rendered" {
  let image = Image::new(10, 10)
  let setter : ColorSink = {
    set: (x, y, color) => image.set_pixel(x, y, color),
  }
  let ctx = RenderState::new(setter, 10, 10)
  let node = rect("zero", 0.0, 0.0, 0.0, 10.0)
  node.fill = SolidColor(Color::rgb(255, 0, 0))
  SVGDocument::new(node).render(ctx)
  let mut any_drawn = false
  for y in 0..<image.height {
    for x in 0..<image.width {
      if !image.get_pixel(x, y).is_transparent() {
        any_drawn = true
      }
    }
  }
  inspect(any_drawn, content="false")
}
