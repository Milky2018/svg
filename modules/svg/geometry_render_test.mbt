///|
fn render_geometry_fixture(svg : String, width : Int, height : Int) -> Image {
  render_svg_to_image(svg, width, height).unwrap_or(Image::new(width, height))
}

///|
fn visible_geometry_pixels(image : Image) -> Int {
  let mut count = 0
  for y in 0..<image.height() {
    for x in 0..<image.width() {
      if !image.get_pixel(x, y).is_transparent() {
        count = count + 1
      }
    }
  }
  count
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
test "affine line stroke matches its transformed local outline" {
  let stroke = render_geometry_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"32\" height=\"24\"><line x1=\"4\" y1=\"8\" x2=\"20\" y2=\"8\" stroke=\"black\" stroke-width=\"4\" transform=\"matrix(1 0.5 0.35 1 2 1)\"/></svg>",
    32, 24,
  )
  let outline = render_geometry_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"32\" height=\"24\"><path d=\"M4 6 H20 V10 H4 Z\" transform=\"matrix(1 0.5 0.35 1 2 1)\"/></svg>",
    32, 24,
  )
  inspect(image_difference_count(stroke, outline), content="0")
}

///|
test "non-uniform affine dashed square-cap stroke uses local geometry" {
  let stroke = render_geometry_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"40\" height=\"24\"><line x1=\"4\" y1=\"6\" x2=\"16\" y2=\"6\" stroke=\"black\" stroke-width=\"4\" stroke-linecap=\"square\" stroke-dasharray=\"4 4\" transform=\"scale(2 1)\"/></svg>",
    40, 24,
  )
  let outline = render_geometry_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"40\" height=\"24\"><path d=\"M4 4 H20 V8 H4 Z M20 4 H36 V8 H20 Z\"/></svg>",
    40, 24,
  )
  inspect(image_difference_count(stroke, outline), content="0")
}

///|
test "positive and negative shear mirror complete dashed stroke outlines" {
  let positive = render_geometry_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"40\" height=\"24\"><line x1=\"5\" y1=\"8\" x2=\"25\" y2=\"8\" stroke=\"black\" stroke-width=\"4\" stroke-linecap=\"square\" stroke-dasharray=\"5 3\" transform=\"matrix(1 0 0.5 1 0 0)\"/></svg>",
    40, 24,
  )
  let negative = render_geometry_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"40\" height=\"24\"><line x1=\"5\" y1=\"8\" x2=\"25\" y2=\"8\" stroke=\"black\" stroke-width=\"4\" stroke-linecap=\"square\" stroke-dasharray=\"5 3\" transform=\"matrix(-1 0 -0.5 1 40 0)\"/></svg>",
    40, 24,
  )
  inspect(
    (visible_geometry_pixels(positive) - visible_geometry_pixels(negative)).abs() <=
    4,
    content="true",
  )
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
test "zero-length line and path share cap rendering" {
  for cap in ["round", "square", "butt"] {
    let line = render_geometry_fixture(
      "<svg width=\"16\" height=\"16\"><line x1=\"8\" y1=\"8\" x2=\"8\" y2=\"8\" stroke=\"black\" stroke-width=\"4\" stroke-linecap=\"" +
      cap +
      "\"/></svg>",
      16,
      16,
    )
    let path = render_geometry_fixture(
      "<svg width=\"16\" height=\"16\"><path d=\"M8 8 L8 8\" fill=\"none\" stroke=\"black\" stroke-width=\"4\" stroke-linecap=\"" +
      cap +
      "\"/></svg>",
      16,
      16,
    )
    inspect(image_difference_count(line, path), content="0")
    inspect(
      visible_geometry_pixels(line) > 0,
      content=if cap == "butt" { "false" } else { "true" },
    )
  }
}

///|
test "closed dash without a gap does not add seam caps" {
  let plain = render_geometry_fixture(
    "<svg width=\"20\" height=\"20\"><path d=\"M4 4 H16 V16 H4 Z\" fill=\"none\" stroke=\"black\" stroke-width=\"4\" stroke-linecap=\"round\" stroke-linejoin=\"bevel\"/></svg>",
    20, 20,
  )
  let dashed = render_geometry_fixture(
    "<svg width=\"20\" height=\"20\"><path d=\"M4 4 H16 V16 H4 Z\" fill=\"none\" stroke=\"black\" stroke-width=\"4\" stroke-linecap=\"round\" stroke-linejoin=\"bevel\" stroke-dasharray=\"1000 1\"/></svg>",
    20, 20,
  )
  inspect(image_difference_count(plain, dashed), content="0")
}

///|
test "non-scaling stroke constructs its outline in device space" {
  let transformed = render_geometry_fixture(
    "<svg width=\"40\" height=\"24\"><path d=\"M3 8 L15 8\" transform=\"scale(2 1)\" fill=\"none\" stroke=\"black\" stroke-width=\"4\" stroke-dasharray=\"4 3\" vector-effect=\"non-scaling-stroke\"/></svg>",
    40, 24,
  )
  let device = render_geometry_fixture(
    "<svg width=\"40\" height=\"24\"><path d=\"M6 8 L30 8\" fill=\"none\" stroke=\"black\" stroke-width=\"4\" stroke-dasharray=\"4 3\"/></svg>",
    40, 24,
  )
  inspect(image_difference_count(transformed, device), content="0")
}

///|
test "curved dash construction is stable under uniform scaling" {
  let transformed = render_geometry_fixture(
    "<svg width=\"40\" height=\"30\"><path d=\"M4 16 C8 2 16 2 20 16\" transform=\"scale(1.5)\" fill=\"none\" stroke=\"black\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-dasharray=\"4 3\" stroke-dashoffset=\"1\"/></svg>",
    40, 30,
  )
  let prescaled = render_geometry_fixture(
    "<svg width=\"40\" height=\"30\"><path d=\"M6 24 C12 3 24 3 30 24\" fill=\"none\" stroke=\"black\" stroke-width=\"3\" stroke-linecap=\"round\" stroke-dasharray=\"6 4.5\" stroke-dashoffset=\"1.5\"/></svg>",
    40, 30,
  )
  inspect(image_difference_count(transformed, prescaled), content="0")
}

///|
test "marker overflow clips to its viewport unless visible" {
  fn fixture(overflow : String) -> Image {
    render_geometry_fixture(
      "<svg width=\"24\" height=\"20\"><defs><marker id=\"m\" markerWidth=\"4\" markerHeight=\"4\" refX=\"2\" refY=\"2\" markerUnits=\"userSpaceOnUse\" overflow=\"" +
      overflow +
      "\"><rect x=\"-4\" y=\"-4\" width=\"12\" height=\"12\" fill=\"red\"/></marker></defs><path d=\"M12 10 L18 10\" marker-start=\"url(#m)\"/></svg>",
      24,
      20,
    )
  }

  inspect(
    visible_geometry_pixels(fixture("visible")) >
    visible_geometry_pixels(fixture("hidden")),
    content="true",
  )
}

///|
test "skew functions and equivalent matrices render identically" {
  let skew_x = render_geometry_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"64\" height=\"48\"><rect x=\"8\" y=\"8\" width=\"16\" height=\"16\" transform=\"skewX(20)\"/></svg>",
    64, 48,
  )
  let matrix_x = render_geometry_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"64\" height=\"48\"><rect x=\"8\" y=\"8\" width=\"16\" height=\"16\" transform=\"matrix(1 0 0.36397023426620234 1 0 0)\"/></svg>",
    64, 48,
  )
  let skew_y = render_geometry_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"64\" height=\"48\"><rect x=\"8\" y=\"8\" width=\"16\" height=\"16\" transform=\"skewY(-20)\"/></svg>",
    64, 48,
  )
  let matrix_y = render_geometry_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"64\" height=\"48\"><rect x=\"8\" y=\"8\" width=\"16\" height=\"16\" transform=\"matrix(1 -0.36397023426620234 0 1 0 0)\"/></svg>",
    64, 48,
  )
  inspect(image_difference_count(skew_x, matrix_x), content="0")
  inspect(image_difference_count(skew_y, matrix_y), content="0")
}

///|
test "positive and negative skewed rects match equivalent paths" {
  for transform in ["skewX(20)", "skewX(-20)", "skewY(20)", "skewY(-20)"] {
    let rect = render_geometry_fixture(
      "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"64\" height=\"48\"><rect x=\"16\" y=\"12\" width=\"16\" height=\"16\" transform=\"" +
      transform +
      "\"/></svg>",
      64,
      48,
    )
    let path = render_geometry_fixture(
      "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"64\" height=\"48\"><path d=\"M16 12 H32 V28 H16 Z\" transform=\"" +
      transform +
      "\"/></svg>",
      64,
      48,
    )
    inspect(image_difference_count(rect, path), content="0")
  }
}

///|
test "skewed rounded rects match equivalent arc paths" {
  let attributes = " transform=\"skewX(18)\" fill=\"none\" stroke=\"black\" stroke-width=\"3\""
  let rect = render_geometry_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"64\" height=\"48\"><rect x=\"12\" y=\"8\" width=\"20\" height=\"20\" rx=\"4\" ry=\"5\"" +
    attributes +
    "/></svg>",
    64,
    48,
  )
  let path = render_geometry_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"64\" height=\"48\"><path d=\"M16 8 H28 A4 5 0 0 1 32 13 V23 A4 5 0 0 1 28 28 H16 A4 5 0 0 1 12 23 V13 A4 5 0 0 1 16 8 Z\"" +
    attributes +
    "/></svg>",
    64,
    48,
  )
  inspect(image_difference_count(rect, path), content="0")
}

///|
test "skewed circles and ellipses match equivalent arc paths" {
  let attributes = " transform=\"skewY(16)\" fill=\"black\" stroke=\"red\" stroke-width=\"2\""
  let circle = render_geometry_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"64\" height=\"48\"><circle cx=\"24\" cy=\"18\" r=\"8\"" +
    attributes +
    "/></svg>",
    64,
    48,
  )
  let circle_path = render_geometry_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"64\" height=\"48\"><path d=\"M32 18 A8 8 0 1 0 16 18 A8 8 0 1 0 32 18 Z\"" +
    attributes +
    "/></svg>",
    64,
    48,
  )
  let ellipse = render_geometry_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"64\" height=\"48\"><ellipse cx=\"24\" cy=\"18\" rx=\"10\" ry=\"6\"" +
    attributes +
    "/></svg>",
    64,
    48,
  )
  let ellipse_path = render_geometry_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"64\" height=\"48\"><path d=\"M34 18 A10 6 0 1 0 14 18 A10 6 0 1 0 34 18 Z\"" +
    attributes +
    "/></svg>",
    64,
    48,
  )
  inspect(image_difference_count(circle, circle_path) <= 1, content="true")
  inspect(image_difference_count(ellipse, ellipse_path) <= 1, content="true")
}

///|
test "non-uniformly scaled circles match equivalent paths" {
  let attributes = " transform=\"scale(2 1)\" fill=\"black\""
  let circle = render_geometry_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"64\" height=\"48\"><circle cx=\"16\" cy=\"18\" r=\"8\"" +
    attributes +
    "/></svg>",
    64,
    48,
  )
  let path = render_geometry_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"64\" height=\"48\"><path d=\"M24 18 A8 8 0 1 1 8 18 A8 8 0 1 1 24 18 Z\"" +
    attributes +
    "/></svg>",
    64,
    48,
  )
  inspect(image_difference_count(circle, path), content="0")
}

///|
test "skewed primitives retain gradient fills" {
  let linear = render_geometry_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"64\" height=\"48\"><defs><linearGradient id=\"g\"><stop offset=\"0\" stop-color=\"red\"/><stop offset=\"1\" stop-color=\"blue\"/></linearGradient></defs><rect x=\"12\" y=\"8\" width=\"20\" height=\"20\" transform=\"skewX(18)\" fill=\"url(#g)\"/></svg>",
    64, 48,
  )
  let linear_path = render_geometry_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"64\" height=\"48\"><defs><linearGradient id=\"g\"><stop offset=\"0\" stop-color=\"red\"/><stop offset=\"1\" stop-color=\"blue\"/></linearGradient></defs><path d=\"M12 8 H32 V28 H12 Z\" transform=\"skewX(18)\" fill=\"url(#g)\"/></svg>",
    64, 48,
  )
  let radial = render_geometry_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"64\" height=\"48\"><defs><radialGradient id=\"g\"><stop offset=\"0\" stop-color=\"white\"/><stop offset=\"1\" stop-color=\"black\"/></radialGradient></defs><circle cx=\"24\" cy=\"18\" r=\"8\" transform=\"skewY(16)\" fill=\"url(#g)\"/></svg>",
    64, 48,
  )
  inspect(visible_geometry_pixels(linear) > 0, content="true")
  inspect(visible_geometry_pixels(radial) > 0, content="true")
  inspect(image_difference_count(linear, linear_path), content="0")
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
