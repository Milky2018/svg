///|
/// Public rendering helpers

///|
test "render_svg_node_to_image_basic" {
  let node = rect("r", 0.0, 0.0, 10.0, 10.0)
  node.fill = SolidColor(Color::black())
  let image = render_svg_node_to_image(node, 20, 20)
  let pixel = image.get_pixel(5, 5)
  inspect(pixel.is_transparent(), content="false")
}

///|
test "render_svg_document_to_image_basic" {
  let node = rect("r", 2.0, 2.0, 6.0, 6.0)
  node.fill = SolidColor(Color::black())
  let doc = SVGDocument::new(node)
  let image = render_svg_document_to_image(doc, 16, 16)
  let pixel = image.get_pixel(4, 4)
  inspect(pixel.is_transparent(), content="false")
}

///|
test "render_svg_viewbox_root" {
  let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 10 10\">" +
    "<rect width=\"10\" height=\"10\" fill=\"black\"/>" +
    "</svg>"
  let image = match render_svg_to_image(svg, 20, 20) {
    Some(img) => img
    None => Image::new(1, 1)
  }
  let pixel = image.get_pixel(15, 15)
  inspect(pixel.is_transparent(), content="false")
}

///|
test "opacity uses browser-compatible alpha quantization" {
  let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"8\" height=\"8\">" +
    "<rect width=\"8\" height=\"8\" fill=\"red\" opacity=\"0.5\"/>" +
    "</svg>"
  let image = match render_svg_to_image(svg, 8, 8) {
    Some(image) => image
    None => Image::new(8, 8)
  }
  inspect(image.get_pixel(4, 4).a, content="128")
}

///|
test "group opacity composites children through an isolated layer" {
  let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"12\" height=\"8\">" +
    "<g opacity=\"0.5\">" +
    "<rect x=\"0\" y=\"0\" width=\"8\" height=\"8\" fill=\"red\"/>" +
    "<rect x=\"4\" y=\"0\" width=\"8\" height=\"8\" fill=\"red\"/>" +
    "</g></svg>"
  let image = match render_svg_to_image(svg, 12, 8) {
    Some(image) => image
    None => Image::new(12, 8)
  }
  inspect(image.get_pixel(2, 4).a, content="128")
  inspect(image.get_pixel(6, 4).a, content="128")
}

///|
test "explicitly inherited opacity composes at child and container boundaries" {
  let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"8\" height=\"8\">" +
    "<g opacity=\"0.5\">" +
    "<rect width=\"8\" height=\"8\" fill=\"red\" opacity=\"inherit\"/>" +
    "</g></svg>"
  let image = match render_svg_to_image(svg, 8, 8) {
    Some(image) => image
    None => Image::new(8, 8)
  }
  inspect(image.get_pixel(4, 4).a, content="64")
}

///|
test "overlapping translucent elements use source-over compositing" {
  let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"8\" height=\"8\">" +
    "<rect width=\"8\" height=\"8\" fill=\"red\"/>" +
    "<rect width=\"8\" height=\"8\" fill=\"blue\" opacity=\"0.5\"/>" +
    "</svg>"
  let image = match render_svg_to_image(svg, 8, 8) {
    Some(image) => image
    None => Image::new(8, 8)
  }
  let pixel = image.get_pixel(4, 4)
  inspect(pixel.r, content="127")
  inspect(pixel.g, content="0")
  inspect(pixel.b, content="128")
  inspect(pixel.a, content="255")
}

///|
test "container mask is applied after isolated group rendering" {
  let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"12\" height=\"8\">" +
    "<defs><mask id=\"half\" mask-type=\"alpha\">" +
    "<rect x=\"0\" y=\"0\" width=\"12\" height=\"8\" fill=\"white\" opacity=\"0.5\"/>" +
    "</mask></defs>" +
    "<g mask=\"url(#half)\">" +
    "<rect x=\"0\" y=\"0\" width=\"8\" height=\"8\" fill=\"red\"/>" +
    "<rect x=\"4\" y=\"0\" width=\"8\" height=\"8\" fill=\"blue\"/>" +
    "</g></svg>"
  let image = match render_svg_to_image(svg, 12, 8) {
    Some(image) => image
    None => Image::new(12, 8)
  }
  inspect(image.get_pixel(2, 4).a, content="128")
  inspect(image.get_pixel(6, 4).a, content="128")
  inspect(image.get_pixel(10, 4).a, content="128")
}

///|
test "group opacity is applied after its container mask" {
  let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"8\" height=\"8\">" +
    "<defs><mask id=\"half\" mask-type=\"alpha\">" +
    "<rect width=\"8\" height=\"8\" fill=\"white\" opacity=\"0.5\"/>" +
    "</mask></defs>" +
    "<g opacity=\"0.5\" mask=\"url(#half)\">" +
    "<rect width=\"8\" height=\"8\" fill=\"red\"/>" +
    "</g></svg>"
  let image = match render_svg_to_image(svg, 8, 8) {
    Some(image) => image
    None => Image::new(8, 8)
  }
  inspect(image.get_pixel(4, 4).a, content="64")
}

///|
test "container filters process the isolated group result" {
  let child = rect("child", 0.0, 0.0, 8.0, 8.0)
  child.fill = SolidColor(Color::rgb(255, 0, 0))
  let root = group("filtered", [child])
  root.add_filter(Invert(1.0))
  let pixel = render_svg_node_to_image(root, 8, 8).get_pixel(4, 4)
  inspect(pixel.r, content="0")
  inspect(pixel.g, content="255")
  inspect(pixel.b, content="255")
  inspect(pixel.a, content="255")
}

///|
test "mix-blend-mode composites against the current backdrop" {
  let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"8\" height=\"8\">" +
    "<style>.mixed { mix-blend-mode: multiply; }</style>" +
    "<rect width=\"8\" height=\"8\" fill=\"red\"/>" +
    "<rect class=\"mixed\" width=\"8\" height=\"8\" fill=\"blue\"/>" +
    "</svg>"
  let image = match render_svg_to_image(svg, 8, 8) {
    Some(image) => image
    None => Image::new(8, 8)
  }
  let pixel = image.get_pixel(4, 4)
  inspect(pixel.r, content="0")
  inspect(pixel.g, content="0")
  inspect(pixel.b, content="0")
  inspect(pixel.a, content="255")
}

///|
test "isolation prevents descendants from blending with outside backdrop" {
  let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"8\" height=\"8\">" +
    "<rect width=\"8\" height=\"8\" fill=\"red\"/>" +
    "<g style=\"isolation: isolate\">" +
    "<rect width=\"8\" height=\"8\" fill=\"blue\" style=\"mix-blend-mode: multiply\"/>" +
    "</g></svg>"
  let image = match render_svg_to_image(svg, 8, 8) {
    Some(image) => image
    None => Image::new(8, 8)
  }
  let pixel = image.get_pixel(4, 4)
  inspect(pixel.r, content="0")
  inspect(pixel.g, content="0")
  inspect(pixel.b, content="255")
  inspect(pixel.a, content="255")
}

///|
test "SVG filter graph evaluates a color matrix on SourceGraphic" {
  let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"8\" height=\"8\">" +
    "<style>.filtered { filter: url(#invert); }</style>" +
    "<defs><filter id=\"invert\">" +
    "<feColorMatrix type=\"matrix\" values=\"-1 0 0 0 1  0 -1 0 0 1  0 0 -1 0 1  0 0 0 1 0\"/>" +
    "</filter></defs>" +
    "<rect class=\"filtered\" width=\"8\" height=\"8\" fill=\"red\"/>" +
    "</svg>"
  let image = match render_svg_to_image(svg, 8, 8) {
    Some(image) => image
    None => Image::new(8, 8)
  }
  let pixel = image.get_pixel(4, 4)
  inspect(pixel.r, content="0")
  inspect(pixel.g, content="255")
  inspect(pixel.b, content="255")
  inspect(pixel.a, content="255")
}

///|
test "SVG filter graph resolves named results for multi-input blend" {
  let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"8\" height=\"8\">" +
    "<defs><filter id=\"named\">" +
    "<feColorMatrix in=\"SourceGraphic\" result=\"blue\" type=\"matrix\" values=\"0 0 0 0 0  0 0 0 0 0  1 0 0 0 0  0 0 0 1 0\"/>" +
    "<feBlend in=\"SourceGraphic\" in2=\"blue\" mode=\"multiply\"/>" +
    "</filter></defs>" +
    "<rect width=\"8\" height=\"8\" fill=\"red\" filter=\"url(#named)\"/>" +
    "</svg>"
  let image = match render_svg_to_image(svg, 8, 8) {
    Some(image) => image
    None => Image::new(8, 8)
  }
  let pixel = image.get_pixel(4, 4)
  inspect(pixel.r, content="0")
  inspect(pixel.g, content="0")
  inspect(pixel.b, content="0")
  inspect(pixel.a, content="255")
}

///|
test "SVG filter region clips graph output" {
  let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"8\" height=\"8\">" +
    "<defs><filter id=\"half\" x=\"0\" y=\"0\" width=\"50%\" height=\"100%\">" +
    "<feColorMatrix type=\"matrix\" values=\"1 0 0 0 0  0 1 0 0 0  0 0 1 0 0  0 0 0 1 0\"/>" +
    "</filter></defs>" +
    "<rect width=\"8\" height=\"8\" fill=\"red\" filter=\"url(#half)\"/>" +
    "</svg>"
  let image = match render_svg_to_image(svg, 8, 8) {
    Some(image) => image
    None => Image::new(8, 8)
  }
  inspect(image.get_pixel(2, 4).a, content="255")
  inspect(image.get_pixel(6, 4).a, content="0")
}

///|
test "SVG filter graph evaluates named feComposite inputs" {
  let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"8\" height=\"8\">" +
    "<defs><filter id=\"composite\">" +
    "<feColorMatrix in=\"SourceAlpha\" result=\"half\" type=\"matrix\" values=\"0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 0.5 0\"/>" +
    "<feComposite in=\"SourceGraphic\" in2=\"half\" operator=\"in\"/>" +
    "</filter></defs>" +
    "<rect width=\"8\" height=\"8\" fill=\"red\" filter=\"url(#composite)\"/>" +
    "</svg>"
  let image = match render_svg_to_image(svg, 8, 8) {
    Some(image) => image
    None => Image::new(8, 8)
  }
  let pixel = image.get_pixel(4, 4)
  inspect(pixel.r, content="255")
  inspect(pixel.g, content="0")
  inspect(pixel.b, content="0")
  inspect(pixel.a, content="128")
}

///|
test "container pipeline applies filter then mask then opacity" {
  let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"8\" height=\"8\">" +
    "<defs>" +
    "<filter id=\"invert\"><feColorMatrix type=\"matrix\" values=\"-1 0 0 0 1  0 -1 0 0 1  0 0 -1 0 1  0 0 0 1 0\"/></filter>" +
    "<mask id=\"half\" mask-type=\"alpha\"><rect width=\"8\" height=\"8\" fill=\"white\" opacity=\"0.5\"/></mask>" +
    "</defs>" +
    "<g filter=\"url(#invert)\" mask=\"url(#half)\" opacity=\"0.5\">" +
    "<rect width=\"8\" height=\"8\" fill=\"red\"/>" +
    "</g></svg>"
  let image = match render_svg_to_image(svg, 8, 8) {
    Some(image) => image
    None => Image::new(8, 8)
  }
  let pixel = image.get_pixel(4, 4)
  inspect(pixel.r, content="0")
  inspect(pixel.g, content="255")
  inspect(pixel.b, content="255")
  inspect(pixel.a, content="64")
}

///|
test "filter graph offset samples outside the image as transparent" {
  let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"8\" height=\"8\">" +
    "<defs><filter id=\"outside\" x=\"-100%\" y=\"-100%\" width=\"300%\" height=\"300%\">" +
    "<feOffset in=\"SourceGraphic\" dx=\"20\" dy=\"0\"/>" +
    "</filter></defs>" +
    "<rect width=\"8\" height=\"8\" fill=\"red\" filter=\"url(#outside)\"/>" +
    "</svg>"
  let image = match render_svg_to_image(svg, 8, 8) {
    Some(image) => image
    None => Image::new(8, 8)
  }
  inspect(image.get_pixel(4, 4).a, content="0")
}

///|
fn image_difference_count(a : Image, b : Image) -> Int {
  let mut count = 0
  for y in 0..<a.height {
    for x in 0..<a.width {
      let left = a.get_pixel(x, y)
      let right = b.get_pixel(x, y)
      if left.r != right.r ||
        left.g != right.g ||
        left.b != right.b ||
        left.a != right.a {
        count += 1
      }
    }
  }
  count
}

///|
fn render_rect_at(x : Double) -> Image {
  let node = rect("probe", x, 1.0, 8.0, 8.0)
  node.fill = SolidColor(Color::black())
  render_svg_node_to_image(node, 16, 16)
}

///|
test "tiny rect translations are quantized symmetrically" {
  let baseline = render_rect_at(1.0)
  let lower = render_rect_at(0.99999)
  let upper = render_rect_at(1.00001)
  inspect(image_difference_count(baseline, lower), content="0")
  inspect(image_difference_count(baseline, upper), content="0")
}

///|
fn render_path_at(x : Double) -> Image {
  render_path_commands_to_image(
    [
      MoveTo(0.0, 0.0),
      LineTo(8.0, 0.0),
      LineTo(8.0, 8.0),
      LineTo(0.0, 8.0),
      ClosePath,
    ],
    16,
    16,
    Color::black(),
    transform=[1.0, 0.0, 0.0, 1.0, x, 1.0],
  )
}

///|
test "tiny path translations are quantized symmetrically" {
  let baseline = render_path_at(1.0)
  let lower = render_path_at(0.99999)
  let upper = render_path_at(1.00001)
  inspect(image_difference_count(baseline, lower), content="0")
  inspect(image_difference_count(baseline, upper), content="0")
}

///|
test "path facade preserves fractional coverage" {
  let image = render_path_commands_to_image(
    [
      MoveTo(0.5, 0.0),
      LineTo(1.5, 0.0),
      LineTo(1.5, 1.0),
      LineTo(0.5, 1.0),
      ClosePath,
    ],
    3,
    1,
    Color::black(),
  )
  inspect(image.get_pixel(0, 0).a, content="128")
  inspect(image.get_pixel(1, 0).a, content="128")
  inspect(image.get_pixel(2, 0).a, content="0")
}

///|
fn render_scene_path_at(x : Double) -> Image {
  let node = path("probe", "M 0 0 L 8 0 L 8 8 L 0 8 Z")
  node.fill = SolidColor(Color::black())
  node.transform = Transform::translate(x, 1.0)
  render_svg_node_to_image(node, 16, 16)
}

///|
test "tiny scene path translations are quantized symmetrically" {
  let baseline = render_scene_path_at(1.0)
  let lower = render_scene_path_at(0.99999)
  let upper = render_scene_path_at(1.00001)
  inspect(image_difference_count(baseline, lower), content="0")
  inspect(image_difference_count(baseline, upper), content="0")
}
