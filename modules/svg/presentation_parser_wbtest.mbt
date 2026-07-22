// ============================================================================
// SVG 2.0 Text Tests
// ============================================================================

///|
test "paint order enum" {
  let normal = PaintOrder::default()
  inspect(normal.order[0], content="Fill")
  inspect(normal.order[1], content="Stroke")
  inspect(normal.order[2], content="Markers")
}

///|
test "parse svg with stroke-linecap" {
  let svg = "<rect stroke-linecap=\"round\"/>"
  match parse_svg(svg) {
    Some(node) => inspect(node.stroke.linecap, content="Round")
    None => panic()
  }
}

///|
test "parse svg with stroke-linejoin" {
  let svg = "<rect stroke-linejoin=\"bevel\"/>"
  match parse_svg(svg) {
    Some(node) => inspect(node.stroke.linejoin, content="Bevel")
    None => panic()
  }
}

///|
test "parse svg with stroke-dasharray" {
  let svg = "<rect stroke-dasharray=\"5,3,2\"/>"
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
test "parse svg with stroke-dasharray none" {
  let svg = "<rect stroke-dasharray=\"none\"/>"
  match parse_svg(svg) {
    Some(node) => inspect(node.stroke.dasharray is None, content="true")
    None => panic()
  }
}

///|
test "parse svg with fill-rule" {
  let svg = "<path fill-rule=\"evenodd\"/>"
  match parse_svg(svg) {
    Some(node) => inspect(node.fill_rule, content="EvenOdd")
    None => panic()
  }
}

///|
test "parse svg with stroke-miterlimit" {
  let svg = "<rect stroke-miterlimit=\"10\"/>"
  match parse_svg(svg) {
    Some(node) => inspect(node.stroke.miterlimit, content="10")
    None => panic()
  }
}

///|
test "parse svg with color names" {
  let svg = "<rect fill=\"red\"/>"
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
test "parse svg with rgb color" {
  let svg = "<rect fill=\"rgb(100, 150, 200)\"/>"
  match parse_svg(svg) {
    Some(node) =>
      match node.fill {
        SolidColor(c) => {
          inspect(c.r, content="100")
          inspect(c.g, content="150")
          inspect(c.b, content="200")
        }
        _ => panic()
      }
    None => panic()
  }
}

///|
test "parse svg with hex color short" {
  let svg = "<rect fill=\"#f00\"/>"
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
test "parse svg with multiple stroke attrs" {
  let svg = "<line stroke=\"blue\" stroke-width=\"3\" stroke-linecap=\"square\" stroke-dasharray=\"10,5\"/>"
  match parse_svg(svg) {
    Some(node) => {
      match node.stroke.paint {
        SolidColor(c) => inspect(c.b, content="255")
        _ => panic()
      }
      inspect(node.stroke.width, content="3")
      inspect(node.stroke.linecap, content="Square")
      match node.stroke.dasharray {
        Some(arr) => inspect(arr.length(), content="2")
        None => panic()
      }
    }
    None => panic()
  }
}
