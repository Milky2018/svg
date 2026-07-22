///|
fn resolver_test_image() -> Image {
  let image = Image::new(2, 1)
  image.set_pixel(0, 0, Color::rgba(255, 0, 0, 128))
  image.set_pixel(1, 0, Color::rgb(0, 255, 0))
  image
}

///|
test "image pixel construction validates dimensions" {
  let pixels = [Color::rgb(255, 0, 0), Color::rgb(0, 255, 0)]
  match Image::from_pixels(2, 1, pixels) {
    Some(image) => {
      inspect(image.width(), content="2")
      inspect(image.height(), content="1")
      inspect(image.get_pixel(1, 0).g, content="255")
    }
    None => fail("expected matching pixels to construct an image")
  }
  inspect(Image::from_pixels(1, 1, pixels) is None, content="true")
  inspect(Image::from_pixels(-1, 1, []) is None, content="true")
}

///|
fn render_with_test_resolver(svg : String, resolved : Array[String]) -> Image {
  render_svg(
    svg,
    8,
    8,
    RenderOptions::with_image_resolver(fn(href) {
      resolved.push(href)
      if href == "asset.png" {
        Some(resolver_test_image())
      } else {
        None
      }
    }),
  ).image
}

///|
test "image resolver receives the preserved href" {
  let resolved : Array[String] = []
  let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"8\" height=\"8\">" +
    "<image href=\"asset.png\" width=\"8\" height=\"8\" preserveAspectRatio=\"none\"/>" +
    "</svg>"
  let image = render_with_test_resolver(svg, resolved)
  inspect(resolved.length(), content="1")
  inspect(resolved[0], content="asset.png")
  inspect(image.get_pixel(1, 1).a, content="128")
  inspect(image.get_pixel(6, 1).g, content="255")
}

///|
test "unresolved image references render nothing" {
  let resolved : Array[String] = []
  let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"8\" height=\"8\">" +
    "<image href=\"missing.jpg\" width=\"8\" height=\"8\"/>" +
    "</svg>"
  let image = render_with_test_resolver(svg, resolved)
  inspect(resolved.length(), content="1")
  inspect(resolved[0], content="missing.jpg")
  inspect(image.get_pixel(4, 4).is_transparent(), content="true")
}

///|
test "resolved image alpha uses source-over compositing" {
  let resolved : Array[String] = []
  let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"8\" height=\"8\">" +
    "<rect width=\"8\" height=\"8\" fill=\"blue\"/>" +
    "<image href=\"asset.png\" width=\"8\" height=\"8\" preserveAspectRatio=\"none\"/>" +
    "</svg>"
  let pixel = render_with_test_resolver(svg, resolved).get_pixel(1, 1)
  inspect(pixel.r, content="128")
  inspect(pixel.g, content="0")
  inspect(pixel.b, content="127")
  inspect(pixel.a, content="255")
}

///|
test "resolved image applies element opacity" {
  let resolved : Array[String] = []
  let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"8\" height=\"8\">" +
    "<image href=\"asset.png\" width=\"8\" height=\"8\" preserveAspectRatio=\"none\" opacity=\"0.5\"/>" +
    "</svg>"
  let pixel = render_with_test_resolver(svg, resolved).get_pixel(6, 1)
  inspect(pixel.g, content="255")
  inspect(pixel.a, content="128")
}

///|
test "resolved image defaults to meet alignment" {
  let resolved : Array[String] = []
  let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"8\" height=\"8\">" +
    "<image href=\"asset.png\" width=\"4\" height=\"4\"/>" +
    "</svg>"
  let image = render_with_test_resolver(svg, resolved)
  inspect(image.get_pixel(0, 0).is_transparent(), content="true")
  inspect(image.get_pixel(0, 1).a, content="128")
  inspect(image.get_pixel(3, 2).g, content="255")
  inspect(image.get_pixel(0, 3).is_transparent(), content="true")
}

///|
test "resolved image supports none and slice alignment" {
  let resolved_none : Array[String] = []
  let svg_none = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"8\" height=\"8\">" +
    "<image href=\"asset.png\" width=\"4\" height=\"4\" preserveAspectRatio=\"none\" image-rendering=\"pixelated\"/>" +
    "</svg>"
  let none_image = render_with_test_resolver(svg_none, resolved_none)
  inspect(none_image.get_pixel(0, 0).a, content="128")
  inspect(none_image.get_pixel(3, 3).g, content="255")
  let resolved_slice : Array[String] = []
  let svg_slice = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"8\" height=\"8\">" +
    "<image href=\"asset.png\" width=\"2\" height=\"2\" preserveAspectRatio=\"xMidYMid slice\" image-rendering=\"pixelated\"/>" +
    "</svg>"
  let slice_image = render_with_test_resolver(svg_slice, resolved_slice)
  inspect(slice_image.get_pixel(0, 0).a, content="128")
  inspect(slice_image.get_pixel(1, 1).g, content="255")
}

///|
test "resolved image uses full affine inverse sampling" {
  let resolved : Array[String] = []
  let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"8\" height=\"8\">" +
    "<image href=\"asset.png\" width=\"4\" height=\"2\" preserveAspectRatio=\"none\" " +
    "transform=\"matrix(1 1 0 1 1 0)\"/>" +
    "</svg>"
  let image = render_with_test_resolver(svg, resolved)
  inspect(image.get_pixel(1, 4).is_transparent(), content="true")
  inspect(image.get_pixel(3, 3).is_transparent(), content="false")
}

///|
test "embedded svg image bypasses the host resolver" {
  let resolved : Array[String] = []
  let data = "data:image/svg+xml,%3Csvg%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20viewBox%3D%220%200%201%201%22%3E%3Crect%20width%3D%221%22%20height%3D%221%22%20fill%3D%22red%22%2F%3E%3C%2Fsvg%3E"
  let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"8\" height=\"8\">" +
    "<image href=\"" +
    data +
    "\" width=\"4\" height=\"4\"/>" +
    "</svg>"
  let image = render_with_test_resolver(svg, resolved)
  inspect(resolved.length(), content="0")
  inspect(image.get_pixel(2, 2).r, content="255")
  inspect(image.get_pixel(2, 2).a, content="255")
}
