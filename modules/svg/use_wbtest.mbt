// ============================================================================
// Text Layout Tests
// ============================================================================

///|
test "symbol creation" {
  let content = rect("content", 0.0, 0.0, 50.0, 50.0)
  let symbol = Symbol::new("mySymbol", content)
  inspect(symbol.id, content="mySymbol")
}

///|
test "use element get_id" {
  let use_elem = UseElement::new("#mySymbol", 10.0, 20.0)
  inspect(use_elem.get_id(), content="mySymbol")
}

///|
fn node_has_rect(node : SVGNode) -> Bool {
  match node.shape {
    Rect(..) => true
    _ => {
      for child in node.children {
        if node_has_rect(child) {
          return true
        }
      }
      false
    }
  }
}

///|
test "use element from defs" {
  let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\">" +
    "<defs><g id=\"g\"><rect width=\"10\" height=\"10\" fill=\"green\"/></g></defs>" +
    "<use href=\"#g\"/></svg>"
  let has_rect = match parse_svg_document(svg) {
    Some(doc) => node_has_rect(doc.root)
    None => false
  }
  inspect(has_rect, content="true")
}

///|
test "use inline style overrides all presentation attributes" {
  let style_first = "<svg><defs><rect id=\"source\" width=\"10\" height=\"10\"/></defs><use id=\"instance\" href=\"#source\" style=\"fill: red; x: 7; y: 8; width: 20; height: 30; transform: translate(5, 6); paint-order: stroke fill\" fill=\"blue\" x=\"2\" y=\"3\" width=\"10\" height=\"11\" transform=\"translate(1, 1)\" paint-order=\"fill stroke\"/></svg>"
  let style_last = "<svg><defs><rect id=\"source\" width=\"10\" height=\"10\"/></defs><use id=\"instance\" href=\"#source\" fill=\"blue\" x=\"2\" y=\"3\" width=\"10\" height=\"11\" transform=\"translate(1, 1)\" paint-order=\"fill stroke\" style=\"fill: red; x: 7; y: 8; width: 20; height: 30; transform: translate(5, 6); paint-order: stroke fill\"/></svg>"
  for svg in [style_first, style_last] {
    match parse_svg_document(svg) {
      Some(document) =>
        match find_test_node(document.root, "instance") {
          Some(node) => {
            match node.fill {
              SolidColor(color) => {
                assert_eq(color.r, 255)
                assert_eq(color.g, 0)
                assert_eq(color.b, 0)
              }
              _ => fail("expected a solid fill")
            }
            assert_eq(node.viewport_width, Some(20.0))
            assert_eq(node.viewport_height, Some(30.0))
            let (x, y) = node.transform.apply(0.0, 0.0)
            assert_eq(x, 12.0)
            assert_eq(y, 14.0)
            assert_true(node.paint_order.order[0] is Stroke)
          }
          None => fail("expected the use instance")
        }
      None => fail("expected SVG parsing to succeed")
    }
  }
}

///|
test "last inline paint order declaration wins on use" {
  let svg = "<svg><defs><rect id=\"source\" width=\"10\" height=\"10\"/></defs><use id=\"instance\" href=\"#source\" style=\"paint-order: stroke fill; paint-order: fill stroke\"/></svg>"
  match parse_svg_document(svg) {
    Some(document) =>
      match find_test_node(document.root, "instance") {
        Some(node) => assert_true(node.paint_order.order[0] is Fill)
        None => fail("expected the use instance")
      }
    None => fail("expected SVG parsing to succeed")
  }
}

///|
test "use element render with viewBox scaling" {
  let svg = "<svg><symbol id=\"box\" viewBox=\"0 0 10 10\"><rect x=\"0\" y=\"0\" width=\"10\" height=\"10\"/></symbol><use href=\"#box\" x=\"0\" y=\"0\" width=\"20\" height=\"20\"/></svg>"
  match parse_svg_document(svg) {
    Some(doc) => {
      let drawn_pixels : Array[(Int, Int, Color)] = []
      let setter : ColorSink = {
        set: (x, y, color) => drawn_pixels.push((x, y, color)),
      }
      let ctx = RenderState::new(setter, 30, 30)
      doc.render(ctx)
      // 20x20 rect = 400 pixels
      inspect(drawn_pixels.length(), content="400")
    }
    None => panic()
  }
}

///|
test "document registers and instantiates symbols" {
  let content = rect("box", 0.0, 0.0, 30.0, 30.0)
  let symbol = Symbol::new("box", content)
  let document = SVGDocument::new(SVGNode::new(Group))
  document.add_symbol(symbol)
  let use_elem = UseElement::new("#box", 100.0, 100.0)
  match document.instantiate_use(use_elem) {
    Some(node) => {
      // Check transform includes translation
      let (tx, ty) = node.transform.get_translate()
      inspect(tx, content="100")
      inspect(ty, content="100")
    }
    None => inspect("failed", content="should instantiate")
  }
}

///|
test "use element referencing element outside defs" {
  // <use> should be able to reference any element with an id, not just those in <defs>
  let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\">" +
    "<rect id=\"myRect\" width=\"10\" height=\"10\" fill=\"red\"/>" +
    "<use href=\"#myRect\" x=\"20\" y=\"0\"/></svg>"
  match parse_svg_document(svg) {
    Some(doc) => {
      let drawn_pixels : Array[(Int, Int, Color)] = []
      let setter : ColorSink = {
        set: (x, y, color) => drawn_pixels.push((x, y, color)),
      }
      let ctx = RenderState::new(setter, 40, 20)
      doc.render(ctx)
      // Original rect (10x10) + use clone (10x10 at x=20) = 200 pixels
      inspect(drawn_pixels.length(), content="200")
    }
    None => panic()
  }
}

///|
test "use element referencing element defined after use (forward reference)" {
  // Forward references: <use> appears before the referenced element
  let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\">" +
    "<use href=\"#laterRect\" x=\"20\" y=\"0\"/>" +
    "<rect id=\"laterRect\" width=\"10\" height=\"10\" fill=\"blue\"/></svg>"
  match parse_svg_document(svg) {
    Some(doc) => {
      let drawn_pixels : Array[(Int, Int, Color)] = []
      let setter : ColorSink = {
        set: (x, y, color) => drawn_pixels.push((x, y, color)),
      }
      let ctx = RenderState::new(setter, 40, 20)
      doc.render(ctx)
      // Forward reference may not resolve during parsing (element not yet registered)
      // Only the original rect renders = 100 pixels
      inspect(drawn_pixels.length(), content="100")
    }
    None => panic()
  }
}
