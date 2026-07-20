///|
fn render_resource_fixture(svg : String, width : Int, height : Int) -> Image {
  render_svg_to_image(svg, width, height).unwrap_or(Image::new(width, height))
}

///|
test "use placement is transformed with the instance" {
  let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"40\" height=\"10\">" +
    "<defs><rect id=\"source\" width=\"5\" height=\"5\" fill=\"red\"/></defs>" +
    "<use href=\"#source\" x=\"5\" transform=\"scale(2)\"/>" +
    "</svg>"
  let image = render_resource_fixture(svg, 40, 10)
  inspect(image.get_pixel(6, 2).is_transparent(), content="true")
  inspect(image.get_pixel(16, 2).is_transparent(), content="false")
}

///|
test "use transform preserves the referenced node transform order" {
  let registry = SymbolRegistry::new()
  let content = rect("source", 0.0, 0.0, 1.0, 1.0)
  content.transform = Transform::translate(1.0, 0.0)
  registry.add(Symbol::new("source", content))
  let instance = {
    ..UseElement::new("#source", 5.0, 0.0),
    transform: Transform::scale(2.0, 2.0),
  }
  match instance.instantiate(registry) {
    Some(node) => {
      let (x, _) = node.transform.apply(0.0, 0.0)
      inspect(x, content="12")
    }
    None => fail("expected use instance")
  }
}

///|
test "affine nested viewport clips outside its parallelogram" {
  let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"8\" height=\"8\">" +
    "<svg width=\"4\" height=\"2\" viewBox=\"0 0 4 2\" overflow=\"hidden\" " +
    "transform=\"matrix(1 1 0 1 1 0)\">" +
    "<rect x=\"-10\" y=\"-10\" width=\"30\" height=\"30\" fill=\"red\"/>" +
    "</svg></svg>"
  let image = render_resource_fixture(svg, 8, 8)
  inspect(image.get_pixel(1, 4).is_transparent(), content="true")
  inspect(image.get_pixel(3, 3).is_transparent(), content="false")
}

///|
test "clip path combines multiple children" {
  let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"8\" height=\"2\">" +
    "<defs><clipPath id=\"clip\">" +
    "<rect width=\"2\" height=\"2\"/><rect x=\"6\" width=\"2\" height=\"2\"/>" +
    "</clipPath></defs>" +
    "<rect width=\"8\" height=\"2\" fill=\"red\" clip-path=\"url(#clip)\"/>" +
    "</svg>"
  let image = render_resource_fixture(svg, 8, 2)
  inspect(image.get_pixel(0, 0).is_transparent(), content="false")
  inspect(image.get_pixel(4, 0).is_transparent(), content="true")
  inspect(image.get_pixel(7, 0).is_transparent(), content="false")
}

///|
test "clip path keeps nested group transforms" {
  let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"8\" height=\"2\">" +
    "<defs><clipPath id=\"clip\"><g transform=\"translate(6 0)\">" +
    "<rect width=\"2\" height=\"2\"/></g></clipPath></defs>" +
    "<rect width=\"8\" height=\"2\" fill=\"red\" clip-path=\"url(#clip)\"/>" +
    "</svg>"
  let image = render_resource_fixture(svg, 8, 2)
  inspect(image.get_pixel(1, 0).is_transparent(), content="true")
  inspect(image.get_pixel(7, 0).is_transparent(), content="false")
}

///|
test "path clip honors evenodd subpaths" {
  let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"6\" height=\"6\">" +
    "<defs><clipPath id=\"clip\" clip-rule=\"evenodd\"><path " +
    "d=\"M0 0H6V6H0Z M2 2H4V4H2Z\"/></clipPath></defs>" +
    "<rect width=\"6\" height=\"6\" fill=\"red\" clip-path=\"url(#clip)\"/>" +
    "</svg>"
  let image = render_resource_fixture(svg, 6, 6)
  inspect(image.get_pixel(1, 1).is_transparent(), content="false")
  inspect(image.get_pixel(3, 3).is_transparent(), content="true")
}

///|
test "affine mask region clips outside its parallelogram" {
  let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"8\" height=\"8\">" +
    "<defs><mask id=\"mask\" mask-type=\"alpha\" maskUnits=\"userSpaceOnUse\" " +
    "maskContentUnits=\"userSpaceOnUse\" x=\"0\" y=\"0\" width=\"4\" height=\"2\">" +
    "<rect x=\"-10\" y=\"-10\" width=\"30\" height=\"30\" fill=\"white\"/>" +
    "</mask></defs>" +
    "<rect x=\"-10\" y=\"-10\" width=\"30\" height=\"30\" fill=\"red\" " +
    "transform=\"matrix(1 1 0 1 1 0)\" mask=\"url(#mask)\"/>" +
    "</svg>"
  let image = render_resource_fixture(svg, 8, 8)
  inspect(image.get_pixel(1, 4).is_transparent(), content="true")
  inspect(image.get_pixel(3, 3).is_transparent(), content="false")
}

///|
test "mask renders nested transformed path content" {
  let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"8\" height=\"2\">" +
    "<defs><mask id=\"mask\" mask-type=\"alpha\" maskUnits=\"userSpaceOnUse\" " +
    "maskContentUnits=\"userSpaceOnUse\" x=\"0\" y=\"0\" width=\"8\" height=\"2\">" +
    "<g transform=\"translate(6 0)\"><path d=\"M0 0H2V2H0Z\" fill=\"white\"/></g>" +
    "</mask></defs>" +
    "<rect width=\"8\" height=\"2\" fill=\"red\" mask=\"url(#mask)\"/>" +
    "</svg>"
  let image = render_resource_fixture(svg, 8, 2)
  inspect(image.get_pixel(1, 0).is_transparent(), content="true")
  inspect(image.get_pixel(7, 0).is_transparent(), content="false")
}
