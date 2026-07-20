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
