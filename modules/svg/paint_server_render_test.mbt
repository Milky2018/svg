///|
fn render_paint_fixture(svg : String, width : Int, height : Int) -> Image {
  render_svg_to_image(svg, width, height).unwrap_or(Image::new(width, height))
}

///|
fn count_visible_paint_pixels(image : Image) -> Int {
  let mut count = 0
  for y in 0..<image.height() {
    for x in 0..<image.width() {
      if image.get_pixel(x, y).a > 0 {
        count = count + 1
      }
    }
  }
  count
}

///|
test "gradient units and transforms are shape-independent" {
  let defs = "<defs><linearGradient id=\"g\" gradientUnits=\"userSpaceOnUse\" x1=\"0\" y1=\"0\" x2=\"40\" y2=\"0\" gradientTransform=\"translate(5 0)\"><stop offset=\"0\" stop-color=\"red\"/><stop offset=\"1\" stop-color=\"blue\"/></linearGradient></defs>"
  let rect = render_paint_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"48\" height=\"24\">" +
    defs +
    "<rect x=\"4\" y=\"4\" width=\"40\" height=\"16\" fill=\"url(#g)\"/></svg>",
    48,
    24,
  )
  let path = render_paint_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"48\" height=\"24\">" +
    defs +
    "<path d=\"M4 4 H44 V20 H4 Z\" fill=\"url(#g)\"/></svg>",
    48,
    24,
  )
  inspect(image_difference_count(rect, path), content="0")
}

///|
test "gradient paints follow circle and rounded-rect fill geometry" {
  let circle = render_paint_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"32\" height=\"24\"><defs><linearGradient id=\"g\"><stop offset=\"0\" stop-color=\"red\"/><stop offset=\"1\" stop-color=\"blue\"/></linearGradient></defs><circle cx=\"12\" cy=\"12\" r=\"8\" fill=\"url(#g)\"/></svg>",
    32, 24,
  )
  let rounded = render_paint_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"32\" height=\"24\"><defs><linearGradient id=\"g\"><stop offset=\"0\" stop-color=\"red\"/><stop offset=\"1\" stop-color=\"blue\"/></linearGradient></defs><rect x=\"4\" y=\"4\" width=\"20\" height=\"16\" rx=\"6\" fill=\"url(#g)\"/></svg>",
    32, 24,
  )
  inspect(count_visible_paint_pixels(circle) > 0, content="true")
  inspect(rounded.get_pixel(4, 4).a, content="0")
  inspect(rounded.get_pixel(14, 12).a > 0, content="true")
}

///|
test "radial gradients use their focal point" {
  let image = render_paint_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"40\" height=\"20\"><defs><radialGradient id=\"g\" cx=\"0.5\" cy=\"0.5\" fx=\"0.25\" fy=\"0.5\" r=\"0.5\"><stop offset=\"0\" stop-color=\"white\"/><stop offset=\"1\" stop-color=\"black\"/></radialGradient></defs><rect width=\"40\" height=\"20\" fill=\"url(#g)\"/></svg>",
    40, 20,
  )
  inspect(image.get_pixel(10, 10).r > image.get_pixel(20, 10).r, content="true")
}

///|
test "patterns render transformed groups through path masks" {
  let defs = "<defs><linearGradient id=\"tileGradient\"><stop offset=\"0\" stop-color=\"green\"/><stop offset=\"1\" stop-color=\"blue\"/></linearGradient><pattern id=\"p\" width=\"8\" height=\"8\" patternUnits=\"userSpaceOnUse\"><g transform=\"translate(2 0)\" opacity=\"0.5\"><rect width=\"4\" height=\"8\" fill=\"url(#tileGradient)\" stroke=\"red\" stroke-width=\"1\"/></g></pattern></defs>"
  let rect = render_paint_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"24\" height=\"16\">" +
    defs +
    "<rect width=\"24\" height=\"16\" fill=\"url(#p)\"/></svg>",
    24,
    16,
  )
  let path = render_paint_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"24\" height=\"16\">" +
    defs +
    "<path d=\"M0 0 H24 V16 H0 Z\" fill=\"url(#p)\"/></svg>",
    24,
    16,
  )
  inspect(count_visible_paint_pixels(rect) > 0, content="true")
  inspect(image_difference_count(rect, path), content="0")
}

///|
test "patterns honor origin transform and viewBox" {
  let image = render_paint_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"16\" height=\"8\"><defs><pattern id=\"p\" x=\"2\" y=\"0\" width=\"4\" height=\"4\" patternUnits=\"userSpaceOnUse\" patternTransform=\"translate(1 0)\" viewBox=\"0 0 4 4\" preserveAspectRatio=\"none\"><rect width=\"2\" height=\"4\" fill=\"red\"/></pattern></defs><rect width=\"16\" height=\"8\" fill=\"url(#p)\"/></svg>",
    16, 8,
  )
  inspect(image.get_pixel(2, 1).a, content="0")
  inspect(image.get_pixel(3, 1).r, content="255")
  inspect(image.get_pixel(5, 1).a, content="0")
  inspect(image.get_pixel(7, 1).r, content="255")
}

///|
test "patterns honor object-bounding-box content units" {
  let image = render_paint_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"24\" height=\"12\"><defs><pattern id=\"p\" width=\"0.5\" height=\"1\" patternContentUnits=\"objectBoundingBox\"><rect width=\"0.25\" height=\"1\" fill=\"red\"/></pattern></defs><rect x=\"0\" y=\"0\" width=\"20\" height=\"10\" fill=\"url(#p)\"/></svg>",
    24, 12,
  )
  inspect(image.get_pixel(2, 5).r, content="255")
  inspect(image.get_pixel(7, 5).a, content="0")
  inspect(image.get_pixel(12, 5).r, content="255")
  inspect(image.get_pixel(17, 5).a, content="0")
}

///|
test "gradients and patterns paint transformed strokes" {
  let defs = "<defs><linearGradient id=\"g\"><stop offset=\"0\" stop-color=\"red\"/><stop offset=\"1\" stop-color=\"blue\"/></linearGradient><pattern id=\"p\" width=\"4\" height=\"4\" patternUnits=\"userSpaceOnUse\"><rect width=\"2\" height=\"4\" fill=\"green\"/></pattern></defs>"
  let gradient_rect = render_paint_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"40\" height=\"24\">" +
    defs +
    "<rect x=\"6\" y=\"5\" width=\"24\" height=\"14\" fill=\"none\" stroke=\"url(#g)\" stroke-width=\"3\" transform=\"skewX(10)\"/></svg>",
    40,
    24,
  )
  let gradient_path = render_paint_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"40\" height=\"24\">" +
    defs +
    "<path d=\"M6 5 H30 V19 H6 Z\" fill=\"none\" stroke=\"url(#g)\" stroke-width=\"3\" transform=\"skewX(10)\"/></svg>",
    40,
    24,
  )
  let pattern_stroke = render_paint_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"40\" height=\"24\">" +
    defs +
    "<circle cx=\"20\" cy=\"12\" r=\"8\" fill=\"none\" stroke=\"url(#p)\" stroke-width=\"4\"/></svg>",
    40,
    24,
  )
  inspect(image_difference_count(gradient_rect, gradient_path), content="0")
  inspect(count_visible_paint_pixels(pattern_stroke) > 0, content="true")
}

///|
test "gradients and patterns paint text glyph masks" {
  let gradient_text = render_paint_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"40\" height=\"20\"><defs><linearGradient id=\"g\"><stop offset=\"0\" stop-color=\"red\"/><stop offset=\"1\" stop-color=\"blue\"/></linearGradient></defs><text x=\"2\" y=\"16\" font-size=\"12\" fill=\"url(#g)\">A</text></svg>",
    40, 20,
  )
  let pattern_text = render_paint_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"40\" height=\"20\"><defs><pattern id=\"p\" width=\"4\" height=\"4\" patternUnits=\"userSpaceOnUse\"><rect width=\"2\" height=\"4\" fill=\"green\"/></pattern></defs><text x=\"2\" y=\"16\" font-size=\"12\" fill=\"url(#p)\">A</text></svg>",
    40, 20,
  )
  inspect(count_visible_paint_pixels(gradient_text) > 0, content="true")
  inspect(count_visible_paint_pixels(pattern_text) > 0, content="true")
}

///|
test "paint-server href inherits content and rejects cycles" {
  let image = render_paint_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"32\" height=\"16\"><defs><linearGradient id=\"derived\" href=\"#base\" x2=\"0\" y2=\"1\"/><linearGradient id=\"base\"><stop offset=\"0\" stop-color=\"red\"/><stop offset=\"1\" stop-color=\"blue\"/></linearGradient><pattern id=\"derivedPattern\" href=\"#basePattern\" width=\"4\"/><pattern id=\"basePattern\" width=\"8\" height=\"8\" patternUnits=\"userSpaceOnUse\"><rect width=\"4\" height=\"8\" fill=\"green\"/></pattern><linearGradient id=\"cycleA\" href=\"#cycleB\"/><linearGradient id=\"cycleB\" href=\"#cycleA\"/></defs><rect width=\"16\" height=\"8\" fill=\"url(#derived)\"/><rect x=\"16\" width=\"16\" height=\"8\" fill=\"url(#derivedPattern)\"/><rect y=\"8\" width=\"16\" height=\"8\" fill=\"url(#cycleA)\"/></svg>",
    32, 16,
  )
  inspect(image.get_pixel(8, 4).a > 0, content="true")
  inspect(image.get_pixel(18, 4).g > 0, content="true")
  inspect(image.get_pixel(8, 12).a, content="0")
}

///|
test "gradient stops interpolate premultiplied alpha and preserve hard stops" {
  let transparent_to_blue = render_paint_fixture(
    "<svg width=\"1\" height=\"1\"><defs><linearGradient id=\"g\"><stop offset=\"0\" stop-color=\"red\" stop-opacity=\"0\"/><stop offset=\"1\" stop-color=\"blue\"/></linearGradient></defs><rect width=\"1\" height=\"1\" fill=\"url(#g)\"/></svg>",
    1, 1,
  ).get_pixel(0, 0)
  inspect(transparent_to_blue.r, content="0")
  inspect(transparent_to_blue.b, content="255")
  inspect(transparent_to_blue.a, content="128")
  let hard_stop = render_paint_fixture(
    "<svg width=\"1\" height=\"1\"><defs><linearGradient id=\"g\"><stop offset=\"0\" stop-color=\"black\"/><stop offset=\"0.5\" stop-color=\"red\"/><stop offset=\"0.5\" stop-color=\"blue\"/><stop offset=\"1\" stop-color=\"white\"/></linearGradient></defs><rect width=\"1\" height=\"1\" fill=\"url(#g)\"/></svg>",
    1, 1,
  ).get_pixel(0, 0)
  inspect(hard_stop.r, content="0")
  inspect(hard_stop.b, content="255")
}

///|
test "recursive pattern content is rejected" {
  let image = render_paint_fixture(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"12\" height=\"12\"><defs><pattern id=\"recursive\" width=\"4\" height=\"4\" patternUnits=\"userSpaceOnUse\"><rect width=\"4\" height=\"4\" fill=\"url(#recursive)\"/></pattern></defs><rect width=\"12\" height=\"12\" fill=\"url(#recursive)\"/></svg>",
    12, 12,
  )
  inspect(count_visible_paint_pixels(image), content="0")
}

///|
test "pattern tiles are cached within one render" {
  let resolved : Array[String] = []
  let svg = "<svg width=\"8\" height=\"8\"><defs><pattern id=\"p\" width=\"4\" height=\"4\" patternUnits=\"userSpaceOnUse\"><image href=\"tile.png\" width=\"4\" height=\"4\" preserveAspectRatio=\"none\"/></pattern></defs><rect width=\"8\" height=\"8\" fill=\"url(#p)\"/><rect width=\"8\" height=\"8\" fill=\"url(#p)\"/></svg>"
  let _ = render_svg(
    svg,
    8,
    8,
    RenderOptions::with_image_resolver(fn(href) {
      resolved.push(href)
      let image = Image::new(1, 1)
      image.set_pixel(0, 0, Color::rgb(255, 0, 0))
      Some(image)
    }),
  )
  inspect(resolved.length(), content="1")
}
