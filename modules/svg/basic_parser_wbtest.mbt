///|
test "svg_node_creation" {
  let node = SVGNode::new(
    Rect(x=10.0, y=20.0, width=100.0, height=50.0, rx=0.0, ry=0.0),
  )
  inspect(node.opacity, content="1")
}

///|
test "parse_svg_simple_rect" {
  let svg = "<rect x=\"10\" y=\"20\" width=\"100\" height=\"50\" fill=\"red\"/>"
  match parse_svg(svg) {
    Some(node) =>
      match node.shape {
        Rect(x~, y~, width~, height~, ..) => {
          inspect(x, content="10")
          inspect(y, content="20")
          inspect(width, content="100")
          inspect(height, content="50")
        }
        _ => panic()
      }
    None => panic()
  }
}

///|
test "parse svg style fill and stroke" {
  let svg = "<rect style=\"fill: red; stroke: blue; stroke-width: 3\" width=\"10\" height=\"10\"/>"
  match parse_svg(svg) {
    Some(node) => {
      match node.fill {
        SolidColor(color) => inspect(color.r, content="255")
        _ => panic()
      }
      match node.stroke.paint {
        SolidColor(color) => inspect(color.b, content="255")
        _ => panic()
      }
      inspect(node.stroke.width, content="3")
    }
    None => panic()
  }
}

///|
test "inline style overrides presentation attributes regardless of order" {
  let style_first = "<rect style=\"fill: red; opacity: 0.5; x: 7\" fill=\"blue\" opacity=\"1\" x=\"2\" width=\"10\" height=\"10\"/>"
  let style_last = "<rect fill=\"blue\" opacity=\"1\" x=\"2\" width=\"10\" height=\"10\" style=\"fill: red; opacity: 0.5; x: 7\"/>"
  for svg in [style_first, style_last] {
    match parse_svg(svg) {
      Some(node) => {
        match node.fill {
          SolidColor(color) => {
            assert_eq(color.r, 255)
            assert_eq(color.g, 0)
            assert_eq(color.b, 0)
          }
          _ => fail("expected a solid fill")
        }
        assert_eq(node.opacity, 0.5)
        match node.shape {
          Rect(x~, ..) => assert_eq(x, 7.0)
          _ => fail("expected a rect")
        }
      }
      None => fail("expected SVG parsing to succeed")
    }
  }
}

///|
test "parse svg style stroke-dasharray" {
  let svg = "<rect style=\"stroke: blue; stroke-dasharray: 5,3,2\" width=\"10\" height=\"10\"/>"
  match parse_svg(svg) {
    Some(node) =>
      match node.stroke.dasharray {
        Some(arr) => {
          inspect(arr.length(), content="3")
          inspect(arr[0], content="5")
          inspect(arr[1], content="3")
          inspect(arr[2], content="2")
        }
        None => panic()
      }
    None => panic()
  }
}

///|
test "parse svg style transform" {
  let svg = "<rect style=\"transform: translate(10, 5)\" width=\"10\" height=\"10\"/>"
  match parse_svg(svg) {
    Some(node) => {
      let (x, y) = node.transform.apply(0.0, 0.0)
      inspect(x, content="10")
      inspect(y, content="5")
    }
    None => panic()
  }
}

///|
test "parse svg style opacity" {
  let svg = "<rect style=\"opacity: 0.5; fill-opacity: 0.25; stroke-opacity: 0.75\" width=\"10\" height=\"10\"/>"
  match parse_svg(svg) {
    Some(node) => {
      inspect(node.opacity, content="0.5")
      inspect(node.fill_opacity, content="0.25")
      inspect((node.stroke_opacity * 100.0).round() / 100.0, content="0.75")
    }
    None => panic()
  }
}

///|
test "parse_svg_circle" {
  let svg = "<circle cx=\"50\" cy=\"60\" r=\"25\" fill=\"blue\"/>"
  match parse_svg(svg) {
    Some(node) =>
      match node.shape {
        Circle(cx~, cy~, r~) => {
          inspect(cx, content="50")
          inspect(cy, content="60")
          inspect(r, content="25")
        }
        _ => panic()
      }
    None => panic()
  }
}

///|
test "parse_svg_group" {
  let svg = "<g id=\"group1\"><rect x=\"0\" y=\"0\" width=\"10\" height=\"10\"/></g>"
  match parse_svg(svg) {
    Some(node) => {
      inspect(node.id, content="group1")
      inspect(node.children.length(), content="1")
    }
    None => panic()
  }
}

///|
test "CSS color adapter parses hexadecimal colors" {
  // This tests the color parsing indirectly through parse_svg
  let svg = "<rect fill=\"#ff0000\" width=\"10\" height=\"10\"/>"
  match parse_svg(svg) {
    Some(node) =>
      match node.fill {
        SolidColor(c) => {
          inspect(c.r, content="255")
          inspect(c.g, content="0")
          inspect(c.b, content="0")
        }
        _ => panic()
      }
    None => panic()
  }
}

///|
test "clip rect" {
  let clip = ClipRect::new(10, 10, 100, 100)
  // Inside
  inspect(clip.contains(50, 50), content="true")
  inspect(clip.contains(10, 10), content="true")
  inspect(clip.contains(109, 109), content="true")
  // Outside
  inspect(clip.contains(9, 50), content="false")
  inspect(clip.contains(110, 50), content="false")
  inspect(clip.contains(50, 9), content="false")
  inspect(clip.contains(50, 110), content="false")
}

///|
test "bounding box intersects" {
  let a = BoundingBox::from_rect(0.0, 0.0, 100.0, 100.0)
  let b = BoundingBox::from_rect(50.0, 50.0, 100.0, 100.0)
  let c = BoundingBox::from_rect(200.0, 200.0, 100.0, 100.0)
  // a and b overlap
  inspect(a.intersects(b), content="true")
  inspect(b.intersects(a), content="true")
  // a and c don't overlap
  inspect(a.intersects(c), content="false")
  inspect(c.intersects(a), content="false")
}
