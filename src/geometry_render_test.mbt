///|
fn render_geometry_fixture(svg : String, width : Int, height : Int) -> Image {
  render_svg_to_image(svg, width, height).unwrap_or(Image::new(width, height))
}

///|
test "rounded rect omitted radius mirrors the specified radius" {
  let prefix = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"12\" height=\"8\">"
  let suffix = "</svg>"
  let explicit = render_geometry_fixture(
    prefix +
    "<rect x=\"1\" y=\"1\" width=\"10\" height=\"6\" rx=\"3\" ry=\"3\"/>" +
    suffix,
    12,
    8,
  )
  let rx_only = render_geometry_fixture(
    prefix +
    "<rect x=\"1\" y=\"1\" width=\"10\" height=\"6\" rx=\"3\"/>" +
    suffix,
    12,
    8,
  )
  let ry_only = render_geometry_fixture(
    prefix +
    "<rect x=\"1\" y=\"1\" width=\"10\" height=\"6\" ry=\"3\"/>" +
    suffix,
    12,
    8,
  )
  inspect(image_difference_count(explicit, rx_only), content="0")
  inspect(image_difference_count(explicit, ry_only), content="0")
}

///|
test "rounded rect radii clamp to half the side lengths" {
  let oversized = render_geometry_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"10\" height=\"6\"><rect x=\"1\" y=\"1\" width=\"8\" height=\"4\" rx=\"100\" ry=\"100\"/></svg>",
    10, 6,
  )
  let clamped = render_geometry_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"10\" height=\"6\"><rect x=\"1\" y=\"1\" width=\"8\" height=\"4\" rx=\"4\" ry=\"2\"/></svg>",
    10, 6,
  )
  inspect(image_difference_count(oversized, clamped), content="0")
}

///|
test "circle ellipse and fully rounded rect share curve coverage" {
  let circle = render_geometry_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"10\" height=\"10\"><circle cx=\"5\" cy=\"5\" r=\"4\"/></svg>",
    10, 10,
  )
  let ellipse = render_geometry_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"10\" height=\"10\"><ellipse cx=\"5\" cy=\"5\" rx=\"4\" ry=\"4\"/></svg>",
    10, 10,
  )
  let rounded = render_geometry_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"10\" height=\"10\"><rect x=\"1\" y=\"1\" width=\"8\" height=\"8\" rx=\"4\" ry=\"4\"/></svg>",
    10, 10,
  )
  inspect(image_difference_count(circle, ellipse), content="0")
  inspect(image_difference_count(circle, rounded), content="0")
}

///|
test "polygon and closed polyline use identical fill edges" {
  let polygon = render_geometry_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"12\" height=\"12\"><polygon points=\"1,1 10,2 8,10 2,9\"/></svg>",
    12, 12,
  )
  let polyline = render_geometry_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"12\" height=\"12\"><polyline points=\"1,1 10,2 8,10 2,9 1,1\"/></svg>",
    12, 12,
  )
  inspect(image_difference_count(polygon, polyline), content="0")
}

///|
test "line and equivalent path share dashed stroke coverage" {
  let line = render_geometry_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"14\" height=\"10\"><line x1=\"1\" y1=\"5\" x2=\"12\" y2=\"5\" stroke=\"black\" stroke-width=\"3\" stroke-linecap=\"round\" stroke-dasharray=\"3 2\"/></svg>",
    14, 10,
  )
  let path = render_geometry_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"14\" height=\"10\"><path d=\"M1 5 L12 5\" fill=\"none\" stroke=\"black\" stroke-width=\"3\" stroke-linecap=\"round\" stroke-dasharray=\"3 2\"/></svg>",
    14, 10,
  )
  inspect(image_difference_count(line, path), content="0")
}

///|
test "odd dash patterns continue across polyline segments" {
  let polyline = render_geometry_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"14\" height=\"14\"><polyline points=\"1,3 9,3 9,12\" fill=\"none\" stroke=\"black\" stroke-width=\"3\" stroke-linecap=\"square\" stroke-linejoin=\"bevel\" stroke-dasharray=\"3 2 1\" stroke-dashoffset=\"1\"/></svg>",
    14, 14,
  )
  let path = render_geometry_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"14\" height=\"14\"><path d=\"M1 3 L9 3 L9 12\" fill=\"none\" stroke=\"black\" stroke-width=\"3\" stroke-linecap=\"square\" stroke-linejoin=\"bevel\" stroke-dasharray=\"3 2 1\" stroke-dashoffset=\"1\"/></svg>",
    14, 14,
  )
  inspect(image_difference_count(polyline, path), content="0")
}

///|
test "polygon and path share cap and join rasterization" {
  for join in ["miter", "bevel", "round"] {
    let polygon = render_geometry_fixture(
      "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"14\" height=\"14\"><polygon points=\"2,2 11,4 7,12\" fill=\"none\" stroke=\"black\" stroke-width=\"4\" stroke-linejoin=\"" +
      join +
      "\" stroke-miterlimit=\"2\"/></svg>",
      14,
      14,
    )
    let path = render_geometry_fixture(
      "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"14\" height=\"14\"><path d=\"M2 2 L11 4 L7 12 Z\" fill=\"none\" stroke=\"black\" stroke-width=\"4\" stroke-linejoin=\"" +
      join +
      "\" stroke-miterlimit=\"2\"/></svg>",
      14,
      14,
    )
    inspect(image_difference_count(polygon, path), content="0")
  }
}

///|
test "circle ellipse and rounded rect share stroke outlines" {
  let style = " fill=\"none\" stroke=\"black\" stroke-width=\"3\""
  let circle = render_geometry_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"12\" height=\"12\"><circle cx=\"6\" cy=\"6\" r=\"4\"" +
    style +
    "/></svg>",
    12,
    12,
  )
  let ellipse = render_geometry_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"12\" height=\"12\"><ellipse cx=\"6\" cy=\"6\" rx=\"4\" ry=\"4\"" +
    style +
    "/></svg>",
    12,
    12,
  )
  let rounded = render_geometry_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"12\" height=\"12\"><rect x=\"2\" y=\"2\" width=\"8\" height=\"8\" rx=\"4\" ry=\"4\"" +
    style +
    "/></svg>",
    12,
    12,
  )
  inspect(image_difference_count(circle, ellipse), content="0")
  inspect(image_difference_count(circle, rounded), content="0")
}

///|
test "rect and equivalent closed path share stroke outlines" {
  let rect = render_geometry_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"14\" height=\"12\"><rect x=\"2\" y=\"2\" width=\"9\" height=\"7\" fill=\"none\" stroke=\"black\" stroke-width=\"3\" stroke-linejoin=\"bevel\"/></svg>",
    14, 12,
  )
  let path = render_geometry_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"14\" height=\"12\"><path d=\"M2 2 H11 V9 H2 Z\" fill=\"none\" stroke=\"black\" stroke-width=\"3\" stroke-linejoin=\"bevel\"/></svg>",
    14, 12,
  )
  inspect(image_difference_count(rect, path), content="0")
}

///|
fn render_marker_geometry(
  shape : String,
  units : String,
  orient : String,
) -> Image {
  render_geometry_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"24\" height=\"24\">" +
    "<defs><marker id=\"m\" markerWidth=\"5\" markerHeight=\"5\" refX=\"2.5\" refY=\"2.5\" markerUnits=\"" +
    units +
    "\" orient=\"" +
    orient +
    "\" overflow=\"visible\">" +
    "<path d=\"M0 0 L5 2.5 L0 5 Z\" fill=\"red\"/></marker></defs>" +
    shape +
    "</svg>",
    24,
    24,
  )
}

///|
test "line and path share transformed start and end markers" {
  for units in ["userSpaceOnUse", "strokeWidth"] {
    for orient in ["auto", "auto-start-reverse"] {
      let attributes = " fill=\"none\" stroke=\"black\" stroke-width=\"2\" marker-start=\"url(#m)\" marker-end=\"url(#m)\" transform=\"translate(2 1) rotate(12 10 10)\""
      let line = render_marker_geometry(
        "<line x1=\"4\" y1=\"8\" x2=\"18\" y2=\"15\"" + attributes + "/>",
        units,
        orient,
      )
      let path = render_marker_geometry(
        "<path d=\"M4 8 L18 15\"" + attributes + "/>",
        units,
        orient,
      )
      inspect(image_difference_count(line, path), content="0")
    }
  }
}

///|
test "polyline and path share mid markers" {
  let attributes = " fill=\"none\" stroke=\"black\" stroke-width=\"2\" marker-start=\"url(#m)\" marker-mid=\"url(#m)\" marker-end=\"url(#m)\""
  let polyline = render_marker_geometry(
    "<polyline points=\"3,4 12,5 9,15 19,18\"" + attributes + "/>",
    "userSpaceOnUse",
    "auto",
  )
  let path = render_marker_geometry(
    "<path d=\"M3 4 L12 5 L9 15 L19 18\"" + attributes + "/>",
    "userSpaceOnUse",
    "auto",
  )
  inspect(image_difference_count(polyline, path), content="0")
}

///|
test "degenerate polyline and path segments share marker orientation" {
  let attributes = " fill=\"none\" stroke=\"black\" stroke-width=\"2\" marker-start=\"url(#m)\" marker-mid=\"url(#m)\" marker-end=\"url(#m)\""
  let polyline = render_marker_geometry(
    "<polyline points=\"3,4 3,4 12,5 12,5 19,17\"" + attributes + "/>",
    "userSpaceOnUse",
    "auto",
  )
  let path = render_marker_geometry(
    "<path d=\"M3 4 L3 4 L12 5 L12 5 L19 17\"" + attributes + "/>",
    "userSpaceOnUse",
    "auto",
  )
  inspect(image_difference_count(polyline, path), content="0")
}

///|
test "polygon and closed path place markers at the closure vertex" {
  let attributes = " fill=\"none\" stroke=\"black\" stroke-width=\"2\" marker-start=\"url(#m)\" marker-mid=\"url(#m)\" marker-end=\"url(#m)\""
  let polygon = render_marker_geometry(
    "<polygon points=\"4,4 18,7 10,18\"" + attributes + "/>",
    "userSpaceOnUse",
    "auto",
  )
  let path = render_marker_geometry(
    "<path d=\"M4 4 L18 7 L10 18 Z\"" + attributes + "/>",
    "userSpaceOnUse",
    "auto",
  )
  inspect(image_difference_count(polygon, path), content="0")
}
